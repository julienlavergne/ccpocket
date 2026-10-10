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
