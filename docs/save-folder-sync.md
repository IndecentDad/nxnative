# Save Folder Sync

`DmSaveFolderSync` is an optional Files-provider bridge. The game continues to
run against the transactional `Documents/save` tree; the bridge only reads a
complete committed snapshot and exports it after a successful host commit.

The selected folder is held by a security-scoped bookmark. NXNative mode uses
`<selected folder>/<title ID>/`. Eden mode treats the selected folder as
`Eden/user/save/0000000000000000/<Profile Folder>/` and uses the same title-ID
child without adding metadata files. Missing title-ID directories require an
explicit export choice in Resolve Conflicts.

The bridge fingerprints file contents and relative paths rather than relying on
timestamps. Reads and staged replacements use `NSFileCoordinator` where the
provider supports it. Provider implementations may not make a directory swap
atomic, so staging and recovery copies protect the local save but cannot make a
remote Files provider transactional.

Eden synchronization is implemented for the confirmed working MeloNX profile
directory, but the Metroid Dread round trip still requires device validation.
Automatic import/export retains the fingerprint, staging, recovery, and
conflict checks; divergent saves remain manual-resolution cases.

The public GameController API does not expose a portable Home/Guide button to
apps. Settings therefore use a one-second touch long-press and the documented
L+R+Plus two-second controller fallback; iOS 27 Home Button Overrides still
requires device validation and is not intercepted here.
