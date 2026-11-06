# Repository and branch workflow

## Canonical structure

- Canonical repository: https://github.com/IndecentDad/nxnative.
- `main` is the complete customized, Windows-compatible implementation and the only permanent development branch. It contains the Windows builder, GUI, shader and Metal toolchain adapters, game profiles, SMB staging, split-data packaging, and accumulated project customizations.
- `upstream/main` (remote `upstream`, seedds/nxnative) is an external source of improvements. Fetch it and integrate selected changes into customized `main`; never replace `main` with an upstream mirror.
- GitHub's default branch is `main`. Do not recreate permanent `windows/main`, `integration`, or `nx2` branches.
- Ordinary development and integration work target `main`. Use a temporary feature or fix branch only when it isolates substantial or risky work; merge validated work to `main` and remove the temporary branch after checking for unique commits and local data.

## Windows checkouts and workspace

- The primary Windows PC is reached through `ssh nxwindows`. Its existing repository/worktree is `D:\NXNativeWindows`; preserve its dirty `codex/overcooked-ayce-1.0.12` work until reviewed and merged.
- The clean canonical `main` worktree is `D:\NXNativeBuilds\main-upstream-sync`. Other worktrees under `D:\NXNativeBuilds` are isolated game work and must be checked before cleanup.
- `D:\Downloads` remains a source location for original game archives. Use `F:\Temp` (SSD) for temporary extraction, build caches, and staging. The GUI selects a per-title work folder under `F:\Temp\NXNative\SMB`; CLI builds should pass `--work-dir F:\Temp\<title-id>`. Keep final IPA output at its established destination with `-o` when setting a work folder.
- Use `win/doctor.py` to inspect the Windows toolchain before a build. See [Windows build worker](windows-build-worker.md) for the entry point and workspace behavior.

## Upstream synchronization and validation

1. Inspect `git status`, remotes, current refs, and all linked worktrees. Preserve dirty files, keys, game inputs, generated artifacts, and reusable caches.
2. Fetch `origin` and `upstream`. Review the upstream commits and conflicts against the customized `main`; retain both upstream improvements and existing Windows behavior.
3. Integrate applicable commits into `main` with normal merge history. Do not force-push or rewrite published history.
4. Run focused tests for changed areas and the Windows builder checks. Validate any Windows-specific changes on the physical Windows PC. A successful compile is not game-play validation.
5. Commit to and push `origin/main` after validation. Do not push to upstream.

## Identity and artifacts

- NXNative commits use `IndecentDad <338341614+IndecentDad@users.noreply.github.com>`. Verify repository-local identity before committing and the GitHub identity before remote writes.
- Keep immutable tags and the documented working IPA for every device-validated game. Record source SHAs, profile/version, toolchain fingerprints, outputs, and device-test status. Never overwrite original ROMs, save data, or signing credentials.
