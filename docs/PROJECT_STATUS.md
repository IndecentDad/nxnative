# NXNative Project Status

- Fork `main` remains untouched. `game/echoes-of-wisdom` preserves the 1.0.0 recovery reference and the registered 1.1.0 profile.
- EoW 1.1.0 extraction completed (10,971 files, 7.5 GB); main, subsdk0, subsdk1 and sdk rewrote successfully; shader split produced 9,858 shader inputs. These local outputs are preserved.
- Diagnosed the translator startup failure: the checked-in `dmsh_xlate.dll` was ARM64 ReadyToRun, incompatible with Tahoe's x86_64 .NET 10. The universal launcher, runtime and XCI access were not the cause.
- `dmsh_xlate.csproj` now disables ReadyToRun and apphost generation. The rebuilt managed package is AnyCPU; `--source-sha` and translator lock checks pass. Chain is `60ce84a81e3c`; pinned SPIRV-Cross/Metal versions remain unchanged.
- The standard Mac+iOS shader build resumed from the saved split using `own_compilers.py`. Metal 32023.883 and SPIRV-Cross 42ee93372e51d0ee are reported as local compiler versions; the translator remains strictly locked. Current outputs are under the local EoW build workspace, chain `b-60ce84a81e3c`.
- Next: finish shader statistics, then continue the 1.1.0 host/Xcode/IPA steps from the existing build workspace. Do not rerun extraction or shader splitting.
