# Fork branch workflow

## Stable branches

- `main` is the primary IndecentDad fork. Keep it based on `upstream/main`, update it regularly, and retain only necessary, tested custom behavior.
- `windows/main` inherits applicable `main` changes. It also keeps the Windows build tools, shader compilation, GUI, SMB staging, output verification, cache handling, split builds and IPA packaging.
- Shared fixes belong in `main` first. Merge them into `windows/main` through a temporary branch and preserve Windows-only behavior there.
- Retire `integration` only after its required changes are on both stable branches, refs are backed up and source plus platform validation is complete.

## Development and validation

- Create temporary `feature/*` or `fix/*` branches from the stable branch that will receive the change. Merge after focused validation; do not keep permanent per-game or platform experiment branches.
- Keep validated game profiles, immutable device-tested tags, IPA provenance and working artifacts. A compile is not gameplay validation.
- For upstream updates, back up current refs, update `main`, review the custom delta, and run relevant source checks. Then merge `main` into a temporary branch from `windows/main`; validate the Windows pipeline on the physical Windows PC before advancing `windows/main`.
- Preserve all uncommitted work and generated artifacts in each worktree. Inspect `git status`, remotes, branches and worktrees before changing a branch. Never initialize or replace an inaccessible platform checkout.

## Platform and repository identity

- Windows work belongs in `D:\NXNativeWindows` on the physical Windows 11 PC. Tahoe is for macOS/iOS builds through `ssh tahoe`; Synology clones do not substitute for either platform checkout. If Windows access is unavailable, report it and provide read-only PowerShell audit commands.
- NXNative commits use `IndecentDad <338341614+IndecentDad@users.noreply.github.com>`. Verify the repository-local identity before committing and the active GitHub account before remote writes. Never use KylePyne for NXNative or push to upstream.

## Branch cleanup

- Do not force-push, rewrite published history, push, or delete remote branches as part of local consolidation. Report proposed deletions and any non-fast-forward requirement for review first.
- Keep local backup refs for prior stable tips until new stable branches are validated. Retain legacy references and user data; remove a temporary branch only after its useful work is merged or backed up.
