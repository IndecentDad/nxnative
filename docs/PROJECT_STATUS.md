# Celeste iOS build

- Branch: `game/celeste-ios` from upstream `abcdbbd`; main unchanged. No commits or pushes.
- Local checkout: `/volume1/docker/nxnative-celeste`.
- Tahoe checkout: `/Users/kylepyne/nxnative-celeste`.
- Release build succeeded using base game plus update `v589824` (1.4.1.1), title `01002B30028F6000`.
- Final unsigned ZIP64 IPA: `/volume1/Media/Roms/iOS/Celeste/Celeste.ipa` (924,749,593 bytes). ZIP64 directory, bundle ID, executable, RomFS marker, shader paths, and absence of signing files verified. No device runtime test.
- Reused existing Python/toolchain; added only `backports.zstd` under Tahoe's Celeste-specific `python-deps`.
- Essential branch changes: Python 3.9 f-string fixes in build script and shader splitter; fork's Intel translator launcher; regenerated tool lock, Celeste chain header, c1 table and constant-buffer extents. Chain `15682d5fade6`; 26 shader inputs produced 38 libraries including variants.
- Build cache: `/Users/kylepyne/nxnative-games/Celeste/01002B30028F6000_build`; extraction, rewritten modules and shaders retained.
- Tahoe's `Celeste.ipa` is the original packer output; NAS IPA has explicit ZIP64 end records added without recompression.
- Next: sign and install the NAS IPA with PlumeImpactor, then test on device. No separate entitlement file needed.
