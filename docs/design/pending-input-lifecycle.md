# Pending input lifetime and idle reclamation

Pending questions and permissions are presented in arrival order. The mobile
client maintains an actionable queue separately from the visible transcript:
resolving one request must never revive an expired historical approval. History
restoration and live events share this queue. Explicitly non-blocking questions
survive turn completion and idle status; blocking actions require a current
approval wait when restoring history. Live requests may arrive before that status.
Malformed questions retain the existing decline-only approval behavior.

There is no new protocol message. Existing request IDs, provider-specific answer
keys, and optional `isBlocking` metadata remain compatible with older peers.

Bridge checks idle sessions once per minute. `BRIDGE_IDLE_SESSION_TTL_MINUTES`
sets their retention period (default 15 minutes, minimum 1). The existing limit
of 30 idle sessions also applies. Both policies exempt sessions with queued
Codex input, pending questions or permissions, or automatic recovery waiting.
Protected sessions can therefore exceed the limit. Once protection ends, expiry
uses the last recorded activity time; it does not start a new grace period.
Active sessions are never reclaimed by this mechanism. Reclamation removes the
live process, not persisted provider conversation history. The interval is
unreferenced and is cleared when the manager is destroyed.
