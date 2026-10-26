# NXNative Project Status

- Fork main remains untouched as the upstream mirror. Integration now merges the validated Echoes of Wisdom 1.1.0 branch with Eden-compatible Save Folder Sync and upstream launcher settings.
- Merge resolution keeps grouped launcher settings, reset-to-tested-defaults, and NavigationStack, while retaining the Save Sync entry, status and detail sheet. The app entry imports both the host front-end and Save Sync bridge.
- Echoes base XCI + update v196608, extraction, rewrites, shader packages and the previously successful device-tested IPA are retained under /Users/kylepyne/nxnative-games/Echoes of Wisdom/v1.1.0. The replacement is to be built from this integration commit.
- Intel translator fix af582053 builds AnyCPU and avoids x86_64 ReadyToRun incompatibility; translator fingerprint and lock checks must remain enabled. Local Metal and SPIRV-Cross fingerprints are recorded in the Echoes build handoff.
- Save Folder Sync must keep local Documents/save and shared <Selected Folder>/<TitleID>/, with folder selection, automatic and manual sync, conflict handling, status and last-success display. Device verification remains pending for the rebuilt IPA.
- Next: run source, translator and Save Sync tests; rebuild Echoes and Celeste from this integration commit using valid existing artifacts; validate both IPAs; clean only superseded build products and update this handoff with exact hashes and remaining device checks.
