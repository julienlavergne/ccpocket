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

  group('shouldClearPendingInputForStatus', () {
    test('clears blocking permissions when status leaves approval wait', () {
      expect(
        shouldClearPendingInputForStatus(
          status: 'idle',
          pendingPermission: blockingQuestion,
        ),
        isTrue,
      );
    });

    test('keeps optional questions pending when status changes', () {
      for (final status in ['running', 'idle']) {
        expect(
          shouldClearPendingInputForStatus(
            status: status,
            pendingPermission: optionalQuestion,
          ),
          isFalse,
        );
      }
    });

    test('keeps any pending permission while waiting for approval', () {
      expect(
        shouldClearPendingInputForStatus(
          status: 'waiting_approval',
          pendingPermission: blockingQuestion,
        ),
        isFalse,
      );
    });
  });

  group('toolResultResolvesPendingInput', () {
    test('resolves only the matching pending permission', () {
      expect(
        toolResultResolvesPendingInput(
          pendingPermission: optionalQuestion,
          toolUseId: 'optional-question',
        ),
        isTrue,
      );
      expect(
        toolResultResolvesPendingInput(
          pendingPermission: optionalQuestion,
          toolUseId: 'other-question',
        ),
        isFalse,
      );
    });
  });

  group('shouldReplacePendingInput', () {
    test('keeps the oldest optional question while later ones wait', () {
      expect(
        shouldReplacePendingInput(
          currentPermission: optionalQuestion,
          incomingPermission: nextOptionalQuestion,
        ),
        isFalse,
      );
    });

    test('allows a refreshed version of the active question', () {
      expect(
        shouldReplacePendingInput(
          currentPermission: optionalQuestion,
          incomingPermission: const PermissionRequestMessage(
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
          currentPermission: null,
          incomingPermission: nextOptionalQuestion,
        ),
        isTrue,
      );
    });
  });
}
