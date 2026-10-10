import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/session_pending_input_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const blockingQuestion = PermissionRequestMessage(
    toolUseId: 'blocking-question',
    toolName: 'AskUserQuestion',
    input: {'isBlocking': true},
  );
  const optionalQuestion = PermissionRequestMessage(
    toolUseId: 'optional-question',
    toolName: 'AskUserQuestion',
    input: {
      'isBlocking': false,
      'questions': [
        {'id': 'q1', 'question': 'First?', 'options': []},
      ],
    },
  );
  const nextOptionalQuestion = PermissionRequestMessage(
    toolUseId: 'next-optional-question',
    toolName: 'AskUserQuestion',
    input: {
      'isBlocking': false,
      'questions': [
        {'id': 'q2', 'question': 'Second?', 'options': []},
      ],
    },
  );
  const approvalRequest = PermissionRequestMessage(
    toolUseId: 'approval-request',
    toolName: 'Bash',
    input: {'command': 'git status'},
  );

  group('shouldClearPendingInputForStatus', () {
    test('clears blocking permissions when status leaves approval wait', () {
      expect(
        shouldClearPendingInputForStatus(
          status: 'idle',
          pendingInput: blockingQuestion,
        ),
        isTrue,
      );
    });

    test('keeps optional questions pending when status changes', () {
      for (final status in ['running', 'idle']) {
        expect(
          shouldClearPendingInputForStatus(
            status: status,
            pendingInput: optionalQuestion,
          ),
          isFalse,
        );
      }
    });

    test('keeps any pending permission while waiting for approval', () {
      expect(
        shouldClearPendingInputForStatus(
          status: 'waiting_approval',
          pendingInput: blockingQuestion,
        ),
        isFalse,
      );
    });
  });

  group('toolResultResolvesPendingInput', () {
    test('resolves only the matching pending permission', () {
      expect(
        toolResultResolvesPendingInput(
          pendingInput: optionalQuestion,
          toolUseId: 'optional-question',
        ),
        isTrue,
      );
      expect(
        toolResultResolvesPendingInput(
          pendingInput: optionalQuestion,
          toolUseId: 'other-question',
        ),
        isFalse,
      );
    });
  });

  group('shouldReplacePendingInput', () {
    test('keeps the oldest question ahead of a later approval', () {
      expect(
        shouldReplacePendingInput(
          currentInput: optionalQuestion,
          incomingInput: approvalRequest,
        ),
        isFalse,
      );
    });

    test('keeps the oldest approval ahead of a later question', () {
      expect(
        shouldReplacePendingInput(
          currentInput: approvalRequest,
          incomingInput: optionalQuestion,
        ),
        isFalse,
      );
    });

    test('allows a refreshed version of the active question', () {
      expect(
        shouldReplacePendingInput(
          currentInput: optionalQuestion,
          incomingInput: const PermissionRequestMessage(
            toolUseId: 'optional-question',
            toolName: 'AskUserQuestion',
            input: {'isBlocking': false, 'questions': []},
          ),
        ),
        isTrue,
      );
    });

    test('allows the next question after the current one is cleared', () {
      expect(
        shouldReplacePendingInput(
          currentInput: null,
          incomingInput: nextOptionalQuestion,
        ),
        isTrue,
      );
    });
  });
}
