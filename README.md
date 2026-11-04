# CopyPaste

Riwayat clipboard untuk macOS, mirip Win+V di Windows. App ini berjalan di menu bar. Ikonnya ada di kanan atas layar, dan app tidak muncul di Dock.

## Fitur

- Riwayat teks, tautan, kode, warna hex, gambar, dan file
- Pencarian dan filter: Semua, Teks, Tautan, Gambar, File
- Sematkan item supaya tidak ikut terhapus
- Pratinjau isi item
- Hapus item dengan undo
- Pintasan buka panel bisa diubah, default ⌃⌘V
- Jeda pencatatan, dan item dari password manager dilewati
- Batas jumlah item dan hapus otomatis setelah beberapa hari
- Buka saat login

## Persyaratan

- macOS 14 atau lebih baru
- Swift 5.10 atau lebih baru (diuji dengan Swift 6.2)
- Command Line Tools cukup, Xcode tidak perlu. Kalau belum punya, jalankan `xcode-select --install`.

## Menjalankan

Bangun app:

```bash
./scripts/make-app.sh
```

Buka app:

```bash
open build/CopyPaste.app
```

Saat pertama kali dibuka, jendela **Izin** muncul. Setelah itu, tekan ⌃⌘V atau klik ikon clipboard di menu bar.

## Izin

| Izin | Dipakai untuk | Kalau tidak diberikan |
|---|---|---|
| Akses clipboard dari aplikasi lain (macOS 15.4 ke atas) | Membaca apa yang disalin | Riwayat tidak terekam. Saat macOS bertanya, pilih **Izinkan**. |
| Aksesibilitas | Tempel otomatis dan posisi panel dekat kursor teks | Item tetap disalin, lalu tekan ⌘V sendiri. Panel muncul dekat kursor mouse. |

Pintasan ⌃⌘V tidak memerlukan izin tambahan.

## Pintasan di panel

| Tombol | Fungsi |
|---|---|
| ↑ ↓ | Pilih item |
| ↵ | Tempel |
| ⇧↵ | Tempel sebagai teks polos |
| → | Buka pratinjau (saat kursor ada di ujung teks pencarian) |
| ← | Tutup pratinjau |
| ⌘1 … ⌘9 | Tempel item ke-1 sampai ke-9 |
| ⌘P | Sematkan atau lepas sematan |
| ⌘⌫ | Hapus item |
| ⌘Z | Urungkan hapus terakhir |
| Tab / ⇧Tab | Ganti filter |
| Esc | Tutup pratinjau, lalu panel |

Pengaturan dibuka dari menu bar lewat **Pengaturan…**, atau dari tombol roda gigi di bawah panel.

## Data dan privasi

- Riwayat disimpan di `~/Library/Application Support/CopyPaste/` (`history.json` dan folder `blobs/`). Data ini **tidak dienkripsi**.
- Item yang ditandai rahasia oleh password manager dilewati. Ini bisa diatur di Pengaturan.
- Proyek ini tidak memakai jaringan.

## Struktur proyek

- `Sources/CopyPasteKit`: model, pencatat clipboard, penyimpanan, dan tempel. Tanpa UI.
- `Sources/CopyPasteUI`: panel, pratinjau, pengaturan, dan layar izin (SwiftUI).
- `Sources/CopyPaste`: app menu bar, pintasan global, dan kontrol panel.
- `Sources/CopyPasteSnapshot`: membuat gambar panel dari data contoh.
- `Tests/CopyPasteKitTests`: unit test.
- `scripts/`: skrip untuk test dan membuat `.app`.

## Pengembangan

Jalankan test:

```bash
./scripts/test.sh
```

Di Command Line Tools tanpa Xcode, Swift Testing perlu flag tambahan. `scripts/test.sh` sudah mengaturnya.

Buat gambar panel dengan data contoh (tidak membaca clipboard asli):

```bash
swift run CopyPasteSnapshot build/snapshots
```

## Batasan

- Build dari `make-app.sh` hanya ditandatangani ad-hoc. Cukup untuk dijalankan di Mac yang membangunnya, tapi belum dinotarisasi untuk dibagikan.
- Undo hanya berlaku untuk penghapusan terakhir.
- Riwayat belum dienkripsi.
- Perilaku pintasan yang juga dipakai aplikasi lain bergantung pada macOS.

## Lisensi

MIT. Lihat [LICENSE](LICENSE).
