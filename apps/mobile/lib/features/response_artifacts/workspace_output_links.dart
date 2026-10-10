import 'dart:math' as math;

import 'package:markdown/markdown.dart' as md;

import '../../models/messages.dart';
import '../file_peek/file_path_syntax.dart';
import '../file_peek/markdown_link_handler.dart';

const _maxWorkspaceOutputLinks = 32;
// Keep Markdown parsing and line allocation bounded for large command output.
const _maxWorkspaceOutputScanLength = 256 * 1024;
const _maxWorkspaceOutputLineLength = 4 * 1024;
const _maxWorkspaceOutputPathLength = 256;
const _maxWorkspaceOutputLabelLength = 256;

class WorkspaceOutputLink {
  final String path;
  final String label;

  const WorkspaceOutputLink({required this.path, required this.label});
}

typedef _CachedWorkspaceLinks = ({
  Set<String> suffixes,
  List<WorkspaceOutputLink> links,
});
final _messageLinks = Expando<_CachedWorkspaceLinks>('workspace output links');

/// Returns file destinations from rendered markdown, excluding code examples.
List<WorkspaceOutputLink> workspaceOutputLinks(
  String text, {
  Set<String> knownPathSuffixes = const {},
}) {
  final boundedText = _boundedWorkspaceOutputText(text);
  if (knownPathSuffixes.isEmpty &&
      !boundedText.contains('[') &&
      !boundedText.contains('`') &&
      !boundedText.contains('/') &&
      !boundedText.contains('\\')) {
    return const [];
  }
  final links = <String, WorkspaceOutputLink>{};
  void visit(md.Node node) {
    if (links.length >= _maxWorkspaceOutputLinks) return;
    if (node is! md.Element) return;
    if (node.tag == 'a' || node.tag == 'img' || node.tag == 'filePath') {
      final href =
          node.attributes[switch (node.tag) {
            'img' => 'src',
            'filePath' => 'path',
            _ => 'href',
          }];
      if (href != null && href.length <= _maxWorkspaceOutputPathLength) {
        final target = classifyMarkdownLink(
          href,
          knownPathSuffixes: knownPathSuffixes,
        );
        if (target.kind == MarkdownLinkTargetKind.file &&
            !target.value.endsWith('/')) {
          final rawLabel = node.tag == 'img'
              ? node.attributes['alt'] ?? ''
              : node.textContent;
          final label = rawLabel.length <= _maxWorkspaceOutputLabelLength
              ? rawLabel
              : rawLabel.substring(0, _maxWorkspaceOutputLabelLength);
          links.putIfAbsent(
            target.value,
            () => WorkspaceOutputLink(path: target.value, label: label),
          );
        }
      }
    }
    if (node.tag == 'code' || node.tag == 'pre') return;
    for (final child in node.children ?? const <md.Node>[]) {
      visit(child);
    }
  }

  void parseLinks({required bool includeBarePaths}) {
    final document = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      inlineSyntaxes: [
        FilePathSyntax(knownPathSuffixes: knownPathSuffixes),
        if (includeBarePaths) ...[
          _AbsoluteOutputPathSyntax(),
          BareFilePathSyntax(knownPathSuffixes: knownPathSuffixes),
        ],
      ],
      encodeHtml: false,
    );
    for (final node in document.parseLines(boundedText.split('\n'))) {
      if (links.length >= _maxWorkspaceOutputLinks) break;
      visit(node);
    }
  }

  // Markdown links and inline code paths are deliberate destinations. Reserve
  // their slots before incidental paths from command output are considered.
  parseLinks(includeBarePaths: false);
  if (links.length < _maxWorkspaceOutputLinks) {
    parseLinks(includeBarePaths: true);
  }
  return List.unmodifiable(links.values);
}

String _boundedWorkspaceOutputText(String text) {
  final output = StringBuffer();
  var position = 0;
  var scanned = 0;
  while (position < text.length && scanned < _maxWorkspaceOutputScanLength) {
    final lineBudget = math.min(
      _maxWorkspaceOutputLineLength,
      _maxWorkspaceOutputScanLength - scanned,
    );
    var lineEnd = position;
    while (lineEnd < text.length &&
        lineEnd - position < lineBudget &&
        text.codeUnitAt(lineEnd) != 0x0a) {
      lineEnd++;
    }
    output.write(text.substring(position, lineEnd));
    scanned += lineEnd - position;
    if (lineEnd >= text.length || text.codeUnitAt(lineEnd) != 0x0a) break;
    if (scanned >= _maxWorkspaceOutputScanLength) break;
    output.write('\n');
    scanned++;
    position = lineEnd + 1;
  }
  return output.toString();
}

class _AbsoluteOutputPathSyntax extends md.InlineSyntax {
  static final _tokenBoundary = RegExp(r'[\s<>()\[\]{}]');

  _AbsoluteOutputPathSyntax()
    : super(
        r'(?:/(?:[\w.-]+/)*[\w.-]*\w|[A-Za-z]:[\\/][\w.\\/-]*\w)(?::\d+(?::\d+)?)?',
      );

  @override
  bool tryMatch(md.InlineParser parser, [int? startMatchPos]) {
    startMatchPos ??= parser.pos;
    final match = pattern.matchAsPrefix(parser.source, startMatchPos);
    if (match == null) return false;

    final source = parser.source;
    if (startMatchPos > 0 &&
        RegExp(r'[\w./\\-]').hasMatch(source[startMatchPos - 1])) {
      return false;
    }
    if (_isInsideUrlToken(source, startMatchPos)) return false;

    final path = match[0]!;
    final pathEnd = startMatchPos + path.length;
    if (pathEnd < source.length && source[pathEnd] == '/') return false;
    if (!FilePathSyntax().isFilePath(path)) return false;
    parser.writeText();
    parser.addNode(
      md.Element.text('filePath', path)..attributes['path'] = path,
    );
    parser.consume(path.length);
    return true;
  }

  @override
  bool onMatch(md.InlineParser parser, Match match) => false;

  bool _isInsideUrlToken(String source, int matchStart) {
    var index = matchStart;
    var inspected = 0;
    while (index > 0 && inspected < 2048) {
      if (_tokenBoundary.hasMatch(source[index - 1])) return false;
      if (index >= 3 &&
          source[index - 3] == ':' &&
          source[index - 2] == '/' &&
          source[index - 1] == '/') {
        return true;
      }
      index--;
      inspected++;
    }
    return index > 0;
  }
}

List<WorkspaceOutputLink> workspaceOutputLinksForMessage(
  ServerMessage message, {
  Set<String> knownPathSuffixes = const {},
}) {
  final cached = _messageLinks[message];
  if (cached != null && identical(cached.suffixes, knownPathSuffixes)) {
    return cached.links;
  }
  final text = switch (message) {
    AssistantServerMessage(:final message) => _boundedAssistantText(
      message.content,
    ),
    ToolResultMessage(:final content) => content,
    ResultMessage(:final result) => result ?? '',
    _ => '',
  };
  final byPath = <String, WorkspaceOutputLink>{};
  if (message is ToolResultMessage) {
    final inlineSyntax = FilePathSyntax(knownPathSuffixes: knownPathSuffixes);
    for (final candidate in message.outputLinkCandidates) {
      final matches = switch (candidate.syntax) {
        'markdown' => true,
        'inline' => inlineSyntax.isFilePath(candidate.href),
        'bare' =>
          knownPathSuffixes.contains(candidate.href) ||
              ((candidate.href.startsWith('/') ||
                      RegExp(r'^[A-Za-z]:[\\/]|^\\\\')
                          .hasMatch(candidate.href)) &&
                  inlineSyntax.isFilePath(candidate.href)),
        _ => false,
      };
      if (!matches) continue;
      final target = classifyMarkdownLink(
        candidate.href,
        knownPathSuffixes: knownPathSuffixes,
      );
      if (target.kind != MarkdownLinkTargetKind.file ||
          target.value.endsWith('/')) {
        continue;
      }
      if (byPath.length >= _maxWorkspaceOutputLinks) break;
      byPath.putIfAbsent(
        target.value,
        () => WorkspaceOutputLink(path: target.value, label: ''),
      );
    }
  }
  if (byPath.length < _maxWorkspaceOutputLinks) {
    for (final link in workspaceOutputLinks(
      text,
      knownPathSuffixes: knownPathSuffixes,
    )) {
      final existing = byPath[link.path];
      if (existing != null) {
        if (existing.label.isEmpty && link.label.isNotEmpty) {
          byPath[link.path] = link;
        }
        continue;
      }
      if (byPath.length >= _maxWorkspaceOutputLinks) break;
      byPath[link.path] = link;
    }
  }
  final result = List<WorkspaceOutputLink>.unmodifiable(byPath.values);
  _messageLinks[message] = (suffixes: knownPathSuffixes, links: result);
  return result;
}

String _boundedAssistantText(List<AssistantContent> content) {
  final text = StringBuffer();
  var remaining = _maxWorkspaceOutputScanLength;
  for (final block in content.whereType<TextContent>()) {
    if (remaining <= 0) break;
    if (text.length > 0) {
      text.write('\n\n');
      remaining -= 2;
      if (remaining <= 0) break;
    }
    final value = block.text;
    if (value.length <= remaining) {
      text.write(value);
      remaining -= value.length;
    } else {
      text.write(value.substring(0, remaining));
      break;
    }
  }
  return text.toString();
}
