import 'package:markdown/markdown.dart' as md;

import '../../models/messages.dart';
import '../file_peek/file_path_syntax.dart';
import '../file_peek/markdown_link_handler.dart';

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
  if (knownPathSuffixes.isEmpty &&
      !text.contains('[') &&
      !text.contains('`') &&
      !text.contains('/') &&
      !text.contains('\\')) {
    return const [];
  }
  final links = <String, WorkspaceOutputLink>{};
  final document = md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
    inlineSyntaxes: [
      FilePathSyntax(knownPathSuffixes: knownPathSuffixes),
      _AbsoluteOutputPathSyntax(),
      BareFilePathSyntax(knownPathSuffixes: knownPathSuffixes),
    ],
    encodeHtml: false,
  );
  void visit(md.Node node) {
    if (node is! md.Element) return;
    if (node.tag == 'a' || node.tag == 'img' || node.tag == 'filePath') {
      final href =
          node.attributes[switch (node.tag) {
            'img' => 'src',
            'filePath' => 'path',
            _ => 'href',
          }];
      if (href != null) {
        final target = classifyMarkdownLink(
          href,
          knownPathSuffixes: knownPathSuffixes,
        );
        if (target.kind == MarkdownLinkTargetKind.file &&
            !target.value.endsWith('/')) {
          final label = node.tag == 'img'
              ? node.attributes['alt'] ?? ''
              : node.textContent;
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

  for (final node in document.parseLines(text.split('\n'))) {
    visit(node);
  }
  return List.unmodifiable(links.values);
}

class _AbsoluteOutputPathSyntax extends md.InlineSyntax {
  _AbsoluteOutputPathSyntax()
    : super(r'(?:/|[A-Za-z]:[\\/])[\w.\\/-]*[\w/](?::\d+(?::\d+)?)?');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    if (match.start > 0 &&
        (parser.source[match.start - 1] == ':' ||
            parser.source[match.start - 1] == '/')) {
      return false;
    }
    final prefix = parser.source.substring(0, match.start);
    if (RegExp(r'[A-Za-z][A-Za-z0-9+.-]*:\S*$').hasMatch(prefix)) return false;
    final path = match[0]!;
    if (!FilePathSyntax().isFilePath(path)) return false;
    parser.addNode(
      md.Element.text('filePath', path)..attributes['path'] = path,
    );
    return true;
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
  final links = workspaceOutputLinks(switch (message) {
    AssistantServerMessage(:final message) =>
      message.content
          .whereType<TextContent>()
          .map((content) => content.text)
          .join('\n\n'),
    ToolResultMessage(:final content) => content,
    ResultMessage(:final result) => result ?? '',
    _ => '',
  }, knownPathSuffixes: knownPathSuffixes);
  final byPath = {for (final link in links) link.path: link};
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
      byPath.putIfAbsent(
        target.value,
        () => WorkspaceOutputLink(path: target.value, label: ''),
      );
    }
  }
  final result = List<WorkspaceOutputLink>.unmodifiable(byPath.values);
  _messageLinks[message] = (suffixes: knownPathSuffixes, links: result);
  return result;
}
