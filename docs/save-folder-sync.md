# Save Folder Sync

`DmSaveFolderSync` is an optional Files-provider bridge. The game continues to
run against its transactional `Documents/save` tree; the bridge reads that
host payload root directly and exports it after a successful host commit. The
guest save mount is already mapped by the host, so guest-relative paths must
not be appended to `Documents/save`.

The selected folder is held by a security-scoped bookmark. Sync uses
`<selected folder>/<title ID>/` and copies the committed `Documents/save`
contents directly beneath that title-ID directory. No emulator-specific
layout or intermediate save directory is added.

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

## Validation before merging

The port is staged on `feature/eden-save-folder-sync`, based on the clean,
device-confirmed Metroid/Celeste runtime. It copies only the legacy save bridge,
its UI and the successful-save callback; audio, scheduler, rewriter and graphics
code remain those of the validated upstream baseline.

For each game, confirm normal launcher-to-gameplay behavior without a selected
folder. Then select a local Files folder and verify direct save-file export
under its title ID, restarting after an import as the status requests. Check
the same layout with Eden and, if desired, a selected cloud-provider folder.
Confirm conflicts require an explicit choice and clearing the folder preserves
the native save. Keep original saves/control IPAs. Host checks and packaging
cannot establish provider or device behavior.

Only after both games pass the user's device checks may this feature merge into
`integration`, receive a validated checkpoint tag and have its temporary branch
retired. The legacy tag and source archives stay available.
