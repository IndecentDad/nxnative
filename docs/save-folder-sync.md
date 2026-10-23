# Save Folder Sync

`DmSaveFolderSync` is an optional Files-provider bridge. The game continues to
run against its transactional `Documents/save` tree; the bridge receives the
game's current payload directory from its profile, reads a complete committed
snapshot, and exports it after a successful host commit. Celeste's payload is
`Documents/save/nts/save`, so the external folder contains `0.celeste` directly.

The selected folder is held by a security-scoped bookmark. Sync uses
`<selected folder>/<title ID>/` and copies the committed payload contents
directly beneath that title-ID directory. No emulator-specific layout or
intermediate save directory is added.

The bridge fingerprints file contents and relative paths rather than relying on
timestamps. Reads and staged replacements use `NSFileCoordinator` where the
provider supports it. Provider implementations may not make a directory swap
atomic, so staging and recovery copies protect the local save but cannot make a
remote Files provider transactional.

Automatic import/export retains the fingerprint, staging, recovery, and
conflict checks; divergent saves remain manual-resolution cases.

The public GameController API does not expose a portable Home/Guide button to
apps. Settings therefore use a one-second touch long-press and the documented
L+R+Plus two-second controller fallback; iOS 27 Home Button Overrides still
requires device validation and is not intercepted here.
