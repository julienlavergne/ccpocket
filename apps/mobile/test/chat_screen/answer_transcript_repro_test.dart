import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/widgets/bubbles/question_answer_transcript_bubble.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import 'helpers/chat_test_helpers.dart';

const _questionInput = {
  'questions': [
    {
      'id': 'garden_sound',
      'question': 'Which sound should the garden use?',
      'header': 'Garden sound',
      'options': [
        {'label': 'Forest birdsong', 'description': 'Morning birds'},
        {'label': 'Rainfall', 'description': 'Soft rain'},
      ],
      'multiSelect': false,
    },
  ],
};

void main() {
  patrolWidgetTest('Claude chat retains the selected question answer', (
    $,
  ) async {
    final bridge = MockBridgeService();
    addTearDown(bridge.dispose);
    await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
    await pumpN($.tester);

    await emitAndPump($.tester, bridge, [
      makeAssistantMessage(
        'before-question',
        'I need one detail before I continue.',
        toolUses: const [
          ToolUseContent(
            id: 'ask-1',
            name: 'AskUserQuestion',
            input: _questionInput,
          ),
        ],
      ),
      const PermissionRequestMessage(
        toolUseId: 'ask-1',
        toolName: 'AskUserQuestion',
        input: _questionInput,
      ),
      const StatusMessage(status: ProcessStatus.waitingApproval),
    ]);

    expect(find.text('Which sound should the garden use?'), findsOneWidget);
    await $.tester.tap(find.text('Forest birdsong'));
    await pumpN($.tester);
    expect(
      bridge.sentMessages.any((message) {
        final json = decodeClientMessage(message);
        return json['type'] == 'answer' && json['toolUseId'] == 'ask-1';
      }),
      isTrue,
    );
    expect(
      find.text(
        'Question: Which sound should the garden use?\nAnswer: Forest birdsong',
      ),
      findsOneWidget,
    );
    expect(find.byType(QuestionAnswerTranscriptBubble), findsOneWidget);

    await emitAndPump($.tester, bridge, [
      const ToolResultMessage(
        toolUseId: 'ask-1',
        content: 'Forest birdsong',
        permissionOutcome: PermissionOutcome.answered,
      ),
      const AssistantServerMessage(
        message: AssistantMessage(
          id: 'after-answer',
          role: 'assistant',
          model: 'claude-sonnet',
          content: [TextContent(text: 'I will add birdsong to the garden.')],
        ),
      ),
    ]);

    expect(
      find.text(
        'Question: Which sound should the garden use?\nAnswer: Forest birdsong',
      ),
      findsOneWidget,
    );
    expect(find.text('I will add birdsong to the garden.'), findsOneWidget);

    await emitAndPump($.tester, bridge, [
      HistoryMessage(
        messages: [
          makeAssistantMessage(
            'before-question',
            'I need one detail before I continue.',
            toolUses: const [
              ToolUseContent(
                id: 'ask-1',
                name: 'AskUserQuestion',
                input: _questionInput,
              ),
            ],
          ),
          const PermissionRequestMessage(
            toolUseId: 'ask-1',
            toolName: 'AskUserQuestion',
            input: _questionInput,
          ),
          const ToolResultMessage(
            toolUseId: 'ask-1',
            content: 'Forest birdsong',
            permissionOutcome: PermissionOutcome.answered,
          ),
          const AssistantServerMessage(
            message: AssistantMessage(
              id: 'after-answer',
              role: 'assistant',
              model: 'claude-sonnet',
              content: [
                TextContent(text: 'I will add birdsong to the garden.'),
              ],
            ),
          ),
          const StatusMessage(status: ProcessStatus.idle),
        ],
      ),
    ]);
    expect(
      find.text(
        'Question: Which sound should the garden use?\nAnswer: Forest birdsong',
      ),
      findsOneWidget,
    );
  });

  patrolWidgetTest('Codex chat retains the selected question answer', (
    $,
  ) async {
    final bridge = MockBridgeService();
    addTearDown(bridge.dispose);
    await $.pumpWidget(await buildTestCodexSessionScreen(bridge: bridge));
    await pumpN($.tester);

    await emitAndPump($.tester, bridge, [
      makeAssistantMessage('before-question', 'I need one detail first.'),
      const PermissionRequestMessage(
        toolUseId: 'ask-1',
        toolName: 'AskUserQuestion',
        input: _questionInput,
      ),
      const StatusMessage(status: ProcessStatus.waitingApproval),
    ]);
    await $.tester.tap(find.text('Forest birdsong'));
    await pumpN($.tester);
    expect(
      find.text(
        'Question: Which sound should the garden use?\nAnswer: Forest birdsong',
      ),
      findsOneWidget,
    );
    expect(find.byType(QuestionAnswerTranscriptBubble), findsOneWidget);
    await emitAndPump($.tester, bridge, [
      const ToolResultMessage(
        toolUseId: 'ask-1',
        content: 'Forest birdsong',
        permissionOutcome: PermissionOutcome.answered,
      ),
      const AssistantServerMessage(
        message: AssistantMessage(
          id: 'after-answer',
          role: 'assistant',
          model: 'codex',
          content: [TextContent(text: 'I will add birdsong to the garden.')],
        ),
      ),
    ]);

    expect(
      find.text(
        'Question: Which sound should the garden use?\nAnswer: Forest birdsong',
      ),
      findsOneWidget,
    );
    expect(find.byType(QuestionAnswerTranscriptBubble), findsOneWidget);
    expect(find.text('I will add birdsong to the garden.'), findsOneWidget);
  });

  patrolWidgetTest('restores question answers from Codex history', ($) async {
    final bridge = MockBridgeService();
    addTearDown(bridge.dispose);
    await $.pumpWidget(await buildTestCodexSessionScreen(bridge: bridge));
    await pumpN($.tester);

    await emitAndPump($.tester, bridge, [
      HistoryMessage(
        messages: [
          makeAssistantMessage('before-question', 'I need one detail first.'),
          const PermissionRequestMessage(
            toolUseId: 'ask-1',
            toolName: 'AskUserQuestion',
            input: _questionInput,
          ),
          const ToolResultMessage(
            toolUseId: 'ask-1',
            content: 'Forest birdsong',
            permissionOutcome: PermissionOutcome.answered,
          ),
          const AssistantServerMessage(
            message: AssistantMessage(
              id: 'after-answer',
              role: 'assistant',
              model: 'codex',
              content: [
                TextContent(text: 'I will add birdsong to the garden.'),
              ],
            ),
          ),
          const StatusMessage(status: ProcessStatus.idle),
        ],
      ),
    ]);

    expect(
      find.text(
        'Question: Which sound should the garden use?\nAnswer: Forest birdsong',
      ),
      findsOneWidget,
    );
    expect(find.text('I will add birdsong to the garden.'), findsOneWidget);
  });
}
