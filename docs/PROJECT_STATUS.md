# NXNative Project Status

## Branch strategy and current source

- `main` is the primary IndecentDad fork based on `seedds/nxnative/main`; it carries only required, tested custom changes. `windows/main` inherits applicable `main` changes and retains Windows build, GUI, shader, SMB staging, cache, split-build and IPA packaging support.
- Use temporary `feature/*` and `fix/*` branches from the stable branch being changed. Retire `integration` only after its required custom changes are incorporated into both stable branches, backed up and validated.
- Current upstream: `4a2a81a64f029d0a75ade9523c8ffc6c89465375`. Local `main` currently equals upstream. The previous fork `origin/main` tip is `40e6baed`; no remote refs have been changed.
- Local `integration` contains the resolved upstream merge and has local backup `backup/integration-before-upstream-2026-11-02`. Its net custom delta is Save Folder Sync alongside upstream Cloud Saves, Intel AnyCPU translator settings, and project/provenance docs. An outdated provider-path source assertion was corrected; focused Save Sync and documentation tests pass (30/30).
- Local backups: `backup/main-before-consolidation-2026-11-02`, `backup/origin-main-before-consolidation-2026-11-02`, `backup/windows-main-before-consolidation-2026-11-02`.
- Remote-tracking `origin/windows/main` is `4637781741c571c8942f57d71e04246f62c42cca`; it contains 89 branch-only commits and is 33 upstream commits behind. It retains the Windows toolchain/GUI, Windows-to-Mac Metal pipeline, staging, cache, split-build, packaging, and Bananza-related changes. The physical Windows worktree is not accessible from this host, so its uncommitted state and Windows validation remain unknown. Do not advance or retire this branch until audited on Windows.

## Retained custom functionality and validated builds

- Save Folder Sync uses native `Documents/save` and Eden-compatible `<Selected Folder>/<TitleID>/` payloads. Metroid Dread and Celeste builds from `a51aad6e0ae2fef570a94c05e5291fc0f3b5105e` are user-confirmed working on iPhone; checkpoint `validated/save-folder-sync-v1` is immutable.
- Intel Tahoe translator support publishes architecture-neutral managed IL (`PublishReadyToRun=false`, `UseAppHost=false`) and keeps the universal ARM64/x86_64 launcher. Existing shader lock and translator fingerprints remain unchanged.
- Echoes of Wisdom profile/history needed by the prior integration is already available upstream and is not an extra custom delta in this update.
- Existing unsigned IPA records remain under `/volume1/Media/Roms/iOS/`; do not replace or rebuild them as part of branch consolidation.

## Local workspace preservation and next steps

- Other worktrees have unrelated uncommitted work: `/tmp/nxnative-metroid-shaderdiag` modifies `dm/gfx/tools/dmsh_build.py`; `nxnative-sidestore` has modified status documentation and untracked SideStore source/tests/docs. Preserve these unchanged.
- Next: complete local `main` consolidation, create a temporary Windows reconciliation branch from the fetched `origin/windows/main`, and review shared-source conflicts. Run the provided read-only PowerShell audit in `D:\NXNativeWindows`, then validate and promote Windows changes on that machine. Only after that, retire `integration`; propose remote branch deletions separately.
- Mario Kart World work starts later from a temporary feature branch after both stable branches are reconciled; no Mario Kart World compilation has been run.
