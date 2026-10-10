import 'package:ccpocket/features/response_artifacts/workspace_output_links.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('workspace output links', () {
    test('bare absolute destinations retain their complete path in standard output', () {
      expect(
        workspaceOutputLinks('Output: /workspace/reports/review.pdf.')
            .single
            .path,
        '/workspace/reports/review.pdf',
      );
      expect(
        workspaceOutputLinks(r'Output: C:\workspace\reports\review.pdf')
            .single
            .path,
        r'C:\workspace\reports\review.pdf',
      );
      expect(
        workspaceOutputLinks('Preview: https://example.org/reports/review.pdf'),
        isEmpty,
      );
      expect(workspaceOutputLinks('Preview: reports/unknown.pdf'), isEmpty);
      expect(workspaceOutputLinks('Preview: foo/bar'), isEmpty);
    });
    test('caps output cards for large file listings', () {
      final links = workspaceOutputLinks(
        [
          for (var index = 0; index < 40; index++)
            '[Report $index](./reports/report-$index.pdf)',
        ].join('\n'),
      );
      expect(links, hasLength(32));
    });
    test('prioritizes an explicit report link over bare file listings', () {
      final links = workspaceOutputLinks(
        [
          for (var index = 0; index < 40; index++)
            '/workspace/build/output-$index.json',
          '[Final report](./reports/final-review.pdf)',
        ].join('\n'),
      );

      expect(links, hasLength(32));
      expect(links.first.path, 'reports/final-review.pdf');
      expect(links.first.label, 'Final report');
    });
    test('limits file-link parsing for unusually large tool output', () {
      final text = [
        '[Report](./reports/report.pdf)',
        'x' * (256 * 1024),
        '[Later report](./reports/later-report.pdf)',
      ].join('\n');

      expect(workspaceOutputLinks(text).map((link) => link.path), [
        'reports/report.pdf',
      ]);
    });
    test('bounds retained path and Markdown label metadata', () {
      final path = './reports/${'x' * 300}.pdf';
      expect(workspaceOutputLinks('[Long]($path)'), isEmpty);
      final links = workspaceOutputLinks(
        '[${'x' * 300}](./reports/review.pdf)',
      );
      expect(links.single.label, hasLength(256));
    });
    test(
      'relative paths use the same known-file suffixes as the chat renderer',
      () {
        const suffixes = {'reports/summary.md', 'summary.md', 'README.md'};
        expect(
          workspaceOutputLinks(
            'Read `reports/summary.md` and README.md.',
            knownPathSuffixes: suffixes,
          ).map((link) => link.path),
          ['reports/summary.md', 'README.md'],
        );
        expect(
          workspaceOutputLinks(
            'Read `reports/unknown.md` and unrelated.md.',
            knownPathSuffixes: suffixes,
          ),
          isEmpty,
        );
      },
    );

    test(
      'projected paths retain their destination and reject unknown bare text',
      () {
        final message = ServerMessage.fromJson({
          'type': 'tool_result',
          'toolUseId': 'report',
          'content': '',
          'outputLinkCandidates': [
            {
              'href': 'reports/summary.md',
              'label': 'reports/summary.md',
              'syntax': 'inline',
            },
            {'href': 'README.md', 'label': 'README.md', 'syntax': 'bare'},
            {
              'href': '/workspace/reports/summary.md',
              'label': 'Report',
              'syntax': 'markdown',
            },
            {'href': 'unknown.md', 'label': 'unknown.md', 'syntax': 'bare'},
            {
              'href': 'https://example.org/report.pdf',
              'label': 'External',
              'syntax': 'markdown',
            },
            {
              'href': '[Example](./sample.pdf)',
              'label': 'Example',
              'syntax': 'inline',
            },
            {
              'href': '/other-workspace/reports/summary.md',
              'label': 'summary.md',
              'syntax': 'bare',
            },
          ],
        });
        expect(
          workspaceOutputLinksForMessage(
            message,
            knownPathSuffixes: const {'reports/summary.md', 'README.md'},
          ).map((link) => link.path),
          [
            'reports/summary.md',
            'README.md',
            '/workspace/reports/summary.md',
            '/other-workspace/reports/summary.md',
          ],
        );
      },
    );
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
  test('continues extracting links after a very long output line', () {
    final text = [
      'x' * (8 * 1024),
      '[Final report](./reports/final-review.pdf)',
    ].join('\n');

    expect(workspaceOutputLinks(text).map((link) => link.path), [
      'reports/final-review.pdf',
    ]);
  });
}
