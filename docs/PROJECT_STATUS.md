# NXNative Project Status

## Stable branches

- `main` is the primary IndecentDad fork. Local `main` is `cc72bcf1`, based on upstream `4a2a81a6` with the reviewed Save Folder Sync and Intel Tahoe changes. Remote `origin/main` remains `40e6baed`, an ancestor; no remote branch has been changed.
- `windows/main` remains at `4637781741c571c8942f57d71e04246f62c42cca`. It carries 89 branch-only commits and is 33 upstream commits behind. Its unique work includes the Windows build/GUI, Windows-to-Mac Metal shader pipeline, staging, caches, split builds, IPA packaging, Bananza support and custom Unity shader selection.
- The local `integration` branch is preserved at `a5ae0470` and backed up at `backup/integration-before-upstream-2026-11-02`. Do not retire it before Windows reconciliation and validation.
- Stable tips have local backups: `backup/main-before-consolidation-2026-11-02`, `backup/origin-main-before-consolidation-2026-11-02`, and `backup/windows-main-before-consolidation-2026-11-02`.

## Windows reconciliation candidate

- `feature/windows-main-reconcile` is committed as `b1efbec19d7b29dd3b90ab82eba345d384e6b199`. It has parents `4637781741c571c8942f57d71e04246f62c42cca` (`windows/main`) and `a5ae0470f8f94c6a2310f5947640affe021e5f34` (consolidated `main` history, including `cc72bcf1`).
- The merge keeps current upstream shared behavior, Windows compiler/toolchain and shader pipeline, GUI, SMB staging, cache handling, split builds, packaging, Bananza support, Unity filters and `patch_nso_parallel` fallback. It also retains the Windows-only Overcooked profile already on the stable Windows branch; no dirty checkout changes or key material are included.
- Local candidate checks: 63 passed, 1 skipped. Full collection is not available on Synology: missing `lz4` and `capstone`, unset game-specific `DM_GAME`, and macOS-only `/usr/lib/libproc.dylib` prevent 17 test modules from collecting.
- Windows isolated worktree `D:\NXNativeBuilds\validation-windows-main-reconcile` is clean at the candidate SHA. Python compileall passes and `win/tests/test_win.py` passes 10 tests with 1 optional texture decoder test skipped. `win/compile_check.py` stops because no iPhoneOS SDK is configured on Windows; GUI startup and representative build validation remain pending.
- The physical Windows worktree `D:\NXNativeWindows` is on `codex/overcooked-ayce-1.0.12` with uncommitted Overcooked source/profile/test/build work. Preserve it exactly. A separate worktree, `D:\NXNativeBuilds\OCAYCE-merge-0100F28011892000`, has clean `windows/main` at `46377817`.
- The Windows clone's local `main` is the historical `269d61ff` ancestor of `windows/main`; it is not the new primary fork branch. Do not move any Windows branch ref until the physical checkout and its unique work are reviewed.
- `windows/main` and local `main` have not been promoted or pushed. Remote refs were checked and remain at `origin/main=40e6baed`, `origin/windows/main=4637781741`, and `origin/integration=d0098143`. Because the Windows compile check could not execute and the GUI/build have not been validated, do not advance or push stable branches yet.

## Validation and preserved work

- Local primary-branch Save Folder Sync and documentation tests passed 30/30. No macOS/iOS or Windows build, shader recompilation, or Mario Kart World compilation was run.
- Other dirty worktrees remain untouched: `/tmp/nxnative-metroid-shaderdiag` changes `dmsh_build.py`; `nxnative-sidestore` has SideStore status/source/test/doc changes. The Windows Overcooked worktree and its key material were not read or modified.
- Preserve `backup/integration-before-upstream-2026-11-02`; its target is `a5ae0470`. Keep the integration branch and worktree until both stable branches are validated and confirmed remotely. Proposed remote deletion after that point: `origin/integration` at its then-current SHA `d009814376160f657c57c67040a912696d2f3ccf`; do not delete it without a separate explicit request.
- Mario Kart World work starts from a temporary `feature/*` branch after the stable branches are reconciled.
