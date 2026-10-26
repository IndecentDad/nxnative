# Tutorial: build IPA dari NSP di Windows

Panduan ini membawamu dari PC Windows biasa sampai ke IPA yang siap disideload ke iPhone atau iPad.

## 0. Syarat perangkat

- **PC:** Windows 10/11 64-bit, disk kosong sekitar 2× ukuran NSP + 10 GB.
- **iPhone/iPad:** iOS / iPadOS 26 atau lebih baru, dengan chip **A17 Pro atau lebih baru** (iPhone 15 Pro ke atas) atau iPad **M1 ke atas**.
- **Milikmu sendiri:** dump game (NSP/XCI, plus update dan DLC kalau ada) dan `prod.keys`.

## 1. Pasang alat (sekali saja)

Buka **PowerShell** (tombol Start, ketik `PowerShell`, Enter), lalu jalankan:

```
winget install --id LLVM.LLVM -e
winget install --id Microsoft.DotNet.SDK.10 -e
winget install --id KhronosGroup.VulkanSDK -e
winget install --id Meta.Zstandard -e
python -m pip install lz4 capstone fonttools pillow
```

Python harus sudah terpasang (python.org, versi 3.10 atau lebih baru). Dua alat dari Apple perlu login Apple ID gratis di developer.apple.com/download:

1. **Metal Developer Tools for Windows.** Install, lalu catat foldernya (misalnya `E:\ProjectIOS\Metal Developer Tools`).
2. **Xcode 26 atau 27** (file `.xip`). Ekstrak SDK iPhone darinya, cukup sekali (sekitar 1–2 menit):
   ```
   cd E:\ProjectIOS\nxnative-win
   python win\sdk\extract_xip.py E:\ProjectIOS\Xcode_27.1.xip
   ```

Setelah itu salin `win\toolchain.example.json` menjadi `win\toolchain.json`, lalu sesuaikan path-nya. Di PC ini file tersebut sudah terisi.

## 2. Cek semua alat

Selalu jalankan dari folder repo:

```
cd E:\ProjectIOS\nxnative-win
python win\doctor.py
```

Semua baris harus `[ok ]`, dan di akhir harus muncul `everything a build needs is there`. Kalau ada yang `MISSING`, baris `get it:` di bawahnya menjelaskan cara memasangnya.

## 3. Siapkan folder game

Pakai **satu folder untuk satu game**. Isinya:

- NSP base game (wajib)
- NSP update dan DLC (opsional; yang dipakai adalah versi terbaru di folder itu)
- `prod.keys` (boleh juga di folder lain)

Contoh:

```
E:\ProjectIOS\Games\
  Balatro [0100CD801CE5E000][v0].nsp
  Balatro [0100CD801CE5E800][v851968].nsp     ← update 1.1.3, versi yang diuji upstream (disarankan)
  prod.keys
```

## 4. Build IPA

### Cara mudah: GUI

Klik dua kali **`Build-IPA-GUI.bat`** di folder `E:\ProjectIOS\nxnative-win`. Jendelanya berbahasa Inggris dengan tema hitam-pink. Lalu:

1. **Game files**: klik kotak bergaris untuk memilih NSP/XCI (base, update, DLC dari satu game), atau pakai *Choose folder*.
2. **prod.keys**: klik *Browse*.
3. Klik **Build IPA**. Tombolnya berubah jadi progress bar. Setelah selesai, kartu hijau menampilkan lokasi IPA dan tombol *Show in folder*.

GUI selalu memakai nilai default:

- nama app = nama game
- bundle ID = `org.nxnativewindows.<title ID>`
- bahasa = bawaan game
- IPA disimpan di samping file game (bisa diganti lewat *Change*)

Log tampil di bagian *Details*.

Kalau satu folder berisi beberapa game, GUI memisahkan file yang dipilih ke folder `<TitleID>_nxw` lewat hard link. Cara ini tidak memakan ruang disk tambahan.

### Lewat terminal

```
cd E:\ProjectIOS\nxnative-win
python win\build_ipa_windows.py "E:\ProjectIOS\Games" -k "E:\ProjectIOS\Games\prod.keys"
```

Tahap-tahapnya:

1. build `nx_extract`
2. ekstrak NSP
3. rewrite modul game
4. shader
5. build app (clang + ld64.lld)
6. pack IPA

Hasilnya ada di folder game, misalnya `E:\ProjectIOS\Games\Balatro.ipa`. Folder kerja `<TitleID>_build\` disimpan supaya build berikutnya lebih cepat. Log tiap tahap ada di `<TitleID>_build\logs\`.

Opsi yang berguna (`-h` menampilkan semuanya):

| Opsi | Fungsi |
|---|---|
| `-o D:\out\Game.ipa` | Lokasi file IPA hasil build |
| `--app-name "Nama"` | Nama app di home screen |
| `-l ja` | Bahasa game |
| `--no-show-fps` | Mematikan penghitung FPS |

## 5. Pasang ke iPhone

1. Pasang **Sideloadly** (sideloadly.io) di Windows. Kalau diminta, pasang juga iTunes dan iCloud versi dari situs Apple, bukan dari Microsoft Store.
2. Colok iPhone, buka Sideloadly, lalu tarik file `.ipa` ke jendelanya. Masukkan Apple ID kamu, lalu klik **Start**.
3. Kalau di **Advanced options** ada pilihan *Increased Memory Limit*, aktifkan. Game besar butuh ini.
4. Di iPhone, buka *Settings → Privacy & Security → Developer Mode*, nyalakan, lalu restart. Setelah itu buka *Settings → General → VPN & Device Management* dan percayai Apple ID kamu.
5. Buka app-nya. Layar pengaturan (launcher) muncul. Tekan **Play**.

Dengan Apple ID gratis, app harus di-sign ulang setiap 7 hari.

## 6. Kalau ada masalah

- **Build gagal:** pesan `[RED] ...` dan 40 baris terakhir log ditampilkan. Log lengkap ada di `<TitleID>_build\logs\`.
- **App menutup sendiri di iPhone:** buka app *Files*, masuk ke *On My iPhone → Balatro*, lalu ambil `log.txt`.
- **"this IPA uses vX, which game profile ... was not brought up on":** versi game itu belum diuji upstream. Pakai update yang tercantum di README upstream (untuk Balatro: 1.1.3).
- **Game yang butuh Mac:** build berhenti dengan pesan yang menyebut Mac host. Ini terjadi pada game yang shader-nya dibuat saat runtime lewat GLSLC, Vulkan, atau Unreal/Oodle. Game LÖVE seperti Balatro *tidak* termasuk: shader-nya dirakit ulang di Windows oleh `win\love_shaders.py`.

## 6b. Game yang shader-nya dibuat saat runtime (Portal, Fire Emblem: Three Houses, Super Mario Galaxy)

Game seperti ini mengompilasi sebagian shader saat dimainkan. Upstream menangkapnya di Mac; di sini penangkapan dilakukan di perangkatmu:

1. Build pertama berhenti dengan pesan dan membuat file `<NamaGame>-capture.ipa` di folder game.
2. Pasang IPA itu, mainkan sampai layar judul, lalu tunggu sekitar satu menit. Layar boleh hitam atau kosong, karena shader-nya memang belum ada.
3. Buka app **Files** → *On My iPhone/iPad* → `<NamaGame> (capture)`. Salin folder `glslc_capture` (atau `vk_capture`) ke folder game di PC, di samping file NSP.
4. Build lagi. Build menemukan folder itu, mencocokkannya dengan tabel profil, lalu membuat IPA yang sebenarnya.

Game Oodle/Unreal (Octopath Traveler, Bayonetta 3, Pokémon Z-A, DQ XI S, dan lainnya) tidak perlu langkah ini: decoder-nya dijalankan di emulator ARM64 di PC.

## 7. Memperbarui repo

```
cd E:\ProjectIOS\nxnative-win
git fetch upstream
git merge upstream/main
```
