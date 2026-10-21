# NX Native Project Handoff

Repository: `IndecentDad/nxnative`  
Current branch: `main`
Current commit: `3c9c8f5`

## Completed

- Intel x86_64 macOS support is merged and translator-tested.
- Game-specific app-icon selection is merged and selector-tested. It is not yet validated in a complete IPA.
- The Python f-string syntax error in `scripts/build_ipa_from_nsp.py` is fixed.

## Development checkouts

- Permanent development checkout: `/volume1/docker/nxnative`.
- Preserve the existing Tahoe checkout at `/Users/kylepyne/nxnative`; do not overwrite, clean, or copy unrelated local changes.
- Do not push to `seedds/nxnative`.

## Metroid Dread

Metroid Dread reaches gameplay but experiences severe memory growth, approaching the 8.2 GB iOS limit before termination. No memory fix has been implemented.

## Next priority

Investigate NVN-to-Metal memory management and existing upstream fixes, using runtime evidence before implementing changes.
