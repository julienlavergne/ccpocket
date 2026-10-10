import '../models/messages.dart';

/// Keeps explicitly non-blocking user inputs visible after a turn changes state.
bool shouldClearPendingInputForStatus({
  required String status,
  required PermissionRequestMessage? pendingInput,
}) {
  if (pendingInput == null || status == 'waiting_approval') return false;
  return pendingInput.input['isBlocking'] != false;
}

/// A matching tool result confirms that the pending input has been answered.
bool toolResultResolvesPendingInput({
  required PermissionRequestMessage? pendingInput,
  required String toolUseId,
}) => pendingInput?.toolUseId == toolUseId;

/// Keep the oldest unresolved user prompt visible while later prompts wait in
/// the Bridge's pending-request maps.
bool shouldReplacePendingInput({
  required PermissionRequestMessage? currentInput,
  required PermissionRequestMessage incomingInput,
}) {
  if (currentInput == null ||
      currentInput.toolUseId == incomingInput.toolUseId) {
    return true;
  }
  return false;
}

/// Tracks actionable requests separately from the visible transcript. Historical
/// requests that expired must not become actionable again after another answer.
class PendingUserInputQueue {
  final _requests = <String, PermissionRequestMessage>{};

  PermissionRequestMessage? get first => _requests.values.firstOrNull;

  void resolve(String toolUseId) => _requests.remove(toolUseId);

  void _retainOptionalQuestions() {
    _requests.removeWhere(
      (_, request) =>
          !request.usesAskUserUi || request.input['isBlocking'] != false,
    );
  }

  void apply(ServerMessage message, {Set<String> ignoredIds = const {}}) {
    switch (message) {
      case PermissionRequestMessage():
        if (!ignoredIds.contains(message.toolUseId)) {
          _requests[message.toolUseId] = message;
        }
      case AssistantServerMessage():
        for (final content in message.message.content) {
          if (content is ToolUseContent &&
              content.name == 'AskUserQuestion' &&
              !ignoredIds.contains(content.id)) {
            final request = PermissionRequestMessage(
              toolUseId: content.id,
              toolName: content.name,
              input: content.input,
            );
            _requests.putIfAbsent(content.id, () => request);
          }
        }
      case PermissionResolvedMessage(:final toolUseId):
        resolve(toolUseId);
      case ToolResultMessage(:final toolUseId):
        resolve(toolUseId);
      case ResultMessage():
        _retainOptionalQuestions();
      case StatusMessage(:final status):
        if (status == ProcessStatus.idle || status == ProcessStatus.starting) {
          _retainOptionalQuestions();
        }
      default:
        break;
    }
  }

  void restore(
    List<ServerMessage> messages, {
    Set<String> ignoredIds = const {},
  }) {
    _requests.clear();
    ProcessStatus? lastStatus;
    for (final message in messages) {
      if (message is StatusMessage) lastStatus = message.status;
      apply(message, ignoredIds: ignoredIds);
    }
    // Restoration needs evidence that a blocking request remains actionable.
    // Live requests can arrive before their waiting_approval status event.
    if (lastStatus != ProcessStatus.waitingApproval) {
      _retainOptionalQuestions();
    }
  }
}
