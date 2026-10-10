import '../models/messages.dart';

/// Keeps explicitly non-blocking user inputs visible after a turn changes state.
bool shouldClearSessionPermissionForStatus({
  required String status,
  required PermissionRequestMessage? pendingPermission,
}) {
  if (pendingPermission == null || status == 'waiting_approval') return false;
  return pendingPermission.input['isBlocking'] != false;
}

/// A matching tool result confirms that the pending input has been answered.
bool toolResultResolvesSessionPermission({
  required PermissionRequestMessage? pendingPermission,
  required String toolUseId,
}) => pendingPermission?.toolUseId == toolUseId;

/// Keep the oldest unanswered non-blocking question visible while later
/// questions wait in the bridge's pending-request map.
bool shouldReplaceSessionPermission({
  required PermissionRequestMessage? currentPermission,
  required PermissionRequestMessage incomingPermission,
}) {
  if (currentPermission == null ||
      currentPermission.toolUseId == incomingPermission.toolUseId) {
    return true;
  }
  return !(currentPermission.usesAskUserUi && incomingPermission.usesAskUserUi);
}
