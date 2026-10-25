# Retired branches and source recovery

Celeste's control IPA was confirmed fully functional on iPhone on 2026-10-25,
unlocking branch cleanup and focused Save Folder Sync migration.

## Active branch model

- `main`: exact fetched upstream mirror (`787523f`); no custom commits.
- `integration`: validated upstream `6a068772` plus Intel launcher and documentation.
- `feature/eden-save-folder-sync`: temporary validation candidate, not merged.
- Validated tags remain immutable, including `validated/celeste-ios-c6f19d5`.

## Recovery references

The NAS repository retains all retired local/origin tips under
`refs/backup/post-celeste-20261025/`, plus the earlier
`refs/backup/consolidation-20261025T030211Z/`. Detached worktree heads also have
`refs/archive/post-celeste-20261025/worktrees/<name>` references.

A verified full-history bundle, original ref inventory, per-worktree binary
patches and untracked SideStore sources are in:
`/volume1/docker/nxnative-history-archive-20261025/`.

Tahoe's independent repositories have verified bundles, original ref inventories
and source patches under:
`/Users/kylepyne/nxnative-games/RepositoryArchive-post-celeste-20261025/`.
A verified Synology copy of all seven Tahoe bundles is also under
`/volume1/docker/nxnative-history-archive-20261025/tahoe/`.
Each original repository retains `refs/archive/post-celeste-20261025/`.
Historical checkout folders, tool environments, inputs, saves and IPAs remain
in place. They are detached archival sources, not build baselines.

Published immutable legacy tags preserve useful unfinished work:

| Reference | Retained content |
|---|---|
| `legacy/save-folder-sync-ec440a2` | Completed Eden-compatible bridge before this port. |
| `legacy/mario-rabbids-1960820` | Unique Mario Rabbids profile and Snowdrop porting work. |
| `legacy/celeste-unfinished-17ad75d` | Unfinished older Celeste shader/script work. |

Old archive, iCloud/Save Sync, diagnostic, game-specific and stable branch names
were retired after exact tips matched backup refs and bundles verified. The
user explicitly approved retiring the previously protected stable branch.
No force-push occurred; no upstream repository was modified.

Three clean NAS worktrees with no ignored/untracked files were removed:
`nxnative-celeste`, `nxnative-metroid-audren-lock-1f0`, and
`nxnative-metroid-thr-pc`. Their history remains in the verified bundle.
The old `nxnative` checkout, unique Mario Rabbids work, SideStore source edits,
and shader experiment in `/tmp` remain detached and recoverable in place.

Inspect a retired commit with its legacy tag or `git show <backup-ref>`. To
recover independently, clone the verified bundle into a new directory and apply
only the desired archived source patch. Never restore a historical runtime
wholesale into integration or treat old generated outputs as current artifacts.
