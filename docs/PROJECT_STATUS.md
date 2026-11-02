# NXNative Project Status

## Stable branch consolidation

- Desired stable branches: `main` is the primary IndecentDad fork based on `seedds/nxnative/main`; `windows/main` inherits applicable `main` changes and retains Windows build, shader, GUI, SMB staging, cache, split-build and IPA packaging support. Temporary `feature/*` and `fix/*` branches target one of those stable branches.
- Upstream baseline: `4a2a81a64f029d0a75ade9523c8ffc6c89465375`. Local `main` fast-forwarded to merge `a5ae0470`, current upstream plus the retained custom integration work, then received this handoff update. `origin/main` (`40e6baed`) is an ancestor, so future promotion can be a normal fast-forward; no remote refs have been changed.
- Main retains Eden-compatible Save Folder Sync alongside upstream iCloud Cloud Saves, the Intel Tahoe AnyCPU translator settings, and related docs/tests. Echoes profile/history and other prior integration changes are already upstream. Save Folder Sync remains backed by user-confirmed iPhone builds from `a51aad6e0ae2fef570a94c05e5291fc0f3b5105e` and immutable checkpoint `validated/save-folder-sync-v1`.
- Existing integration merge is committed as `a5ae0470`; backup ref `backup/integration-before-upstream-2026-11-02` preserves its pre-merge tip. Do not retire integration until Windows reconciliation is validated.
- Backups: `backup/main-before-consolidation-2026-11-02`, `backup/origin-main-before-consolidation-2026-11-02`, and `backup/windows-main-before-consolidation-2026-11-02`.

## Windows reconciliation

- Fetched `origin/windows/main` tip: `4637781741c571c8942f57d71e04246f62c42cca`; it is 33 upstream commits behind and has 89 branch-only commits, including Windows tools/GUI, Windows-to-Mac Metal, staging, cache, split-build, packaging and Bananza-related work.
- Local candidate `feature/windows-main-reconcile` starts at that tip and merges local `main`. The source merge has conflicts in nine files: `AGENTS.md`, `README.md`, `dm/games/README.md`, `dm/tools/patch_nso.py`, `dm/tools/tests/test_pso_offline.py`, `docs/PROJECT_STATUS.md`, `docs/agents/symptoms.md`, `docs/reference/shaders.md`, and `scripts/build_ipa_from_nsp.py`. It is uncommitted and does not move `windows/main`.
- The physical Windows PC at `D:\NXNativeWindows` is not accessible from this host. Its dirty state and local artifacts are unknown. Audit it there before resolving/promoting the Windows candidate; validate the build pipeline on Windows before advancing `windows/main`.

## Validation and preservation

- Focused Save Folder Sync and documentation source tests: 30 passed. No macOS/iOS or Windows build, shader recompilation, or Mario Kart World compilation was run.
- Other worktrees remain untouched: `/tmp/nxnative-metroid-shaderdiag` has a `dmsh_build.py` edit; `nxnative-sidestore` has modified status docs and untracked SideStore tools/tests/docs.
- Do not push, force-push, delete remote branches or remove worktrees during this consolidation. Propose remote deletions and any history rewrite separately after stable branch validation.
