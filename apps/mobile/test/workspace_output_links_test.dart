import 'package:ccpocket/features/response_artifacts/workspace_output_links.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('workspace output links', () {
    test('uses the same destinations as file links, including positions and spaces', () {
      final links = workspaceOutputLinks('''
[Report](</workspace/reports/Release review.pdf>)
[Source](lib/main.dart#L42)
![Chart](./reports/chart.png)
[Windows](C:/workspace/report.docx)
[Report again](</workspace/reports/Release review.pdf>)
[Website](https://example.org/reports/report.pdf)
[Section](#summary)
''');
      expect(links.map((link) => link.path), [
        '/workspace/reports/Release review.pdf',
        'lib/main.dart:42',
        'reports/chart.png',
        'C:/workspace/report.docx',
      ]);
      expect(links.first.label, 'Report');
    });

    test(
      'does not turn code examples, directories, or web images into files',
      () {
        final links = workspaceOutputLinks('''
`[Example](./sample.pdf)`
```markdown
[Example](./sample.pdf)
```
[Folder](./reports/)
![Web image](https://example.org/chart.png)
''');
        expect(links, isEmpty);
      },
    );

    test('includes explicit inline file paths that the chat already makes tappable', () {
      final links = workspaceOutputLinks(
        'The report is at `/workspace/reports/review.pdf`.',
      );
      expect(links.single.path, '/workspace/reports/review.pdf');
    });

    test(
      'extracts assistant text and tool output without reading tool arguments',
      () {
        final assistant = AssistantServerMessage(
          message: AssistantMessage(
            id: 'report',
            role: 'assistant',
            model: 'claude-sonnet-4-20250514',
            content: const [
              TextContent(text: '[Report](./reports/summary.pdf)'),
              ToolUseContent(
                id: 'read',
                name: 'Read',
                input: {'file_path': 'private.txt'},
              ),
            ],
          ),
        );
        final links = workspaceOutputLinksForMessage(assistant);
        expect(links.single.path, 'reports/summary.pdf');
        expect(workspaceOutputLinksForMessage(assistant), same(links));
        expect(
          workspaceOutputLinksForMessage(
            const ToolResultMessage(
              toolUseId: 'report',
              content: '[Report](./reports/summary.pdf)',
            ),
          ).single.path,
          'reports/summary.pdf',
        );
      },
    );
  });
}
