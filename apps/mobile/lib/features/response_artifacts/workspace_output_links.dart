import 'package:markdown/markdown.dart' as md;

import '../../models/messages.dart';
import '../file_peek/file_path_syntax.dart';
import '../file_peek/markdown_link_handler.dart';

class WorkspaceOutputLink {
  final String path;
  final String label;

  const WorkspaceOutputLink({required this.path, required this.label});
}

final _messageLinks = Expando<List<WorkspaceOutputLink>>(
  'workspace output links',
);

/// Returns file destinations from rendered markdown, excluding code examples.
List<WorkspaceOutputLink> workspaceOutputLinks(String text) {
  if (!text.contains('[') && !text.contains('`')) return const [];
  final links = <String, WorkspaceOutputLink>{};
  final document = md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
    inlineSyntaxes: [FilePathSyntax()],
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
        final target = classifyMarkdownLink(href);
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

List<WorkspaceOutputLink> workspaceOutputLinksForMessage(
  ServerMessage message,
) {
  return _messageLinks[message] ??= workspaceOutputLinks(switch (message) {
    AssistantServerMessage(:final message) =>
      message.content
          .whereType<TextContent>()
          .map((content) => content.text)
          .join('\n\n'),
    ToolResultMessage(:final content) => content,
    ResultMessage(:final result) => result ?? '',
    _ => '',
  });
}
