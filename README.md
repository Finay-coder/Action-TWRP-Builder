# X688B Android 11 Recovery Builder

GitHub Actions template untuk **audit donor recovery Android 11** dan membangun **TWRP 11 khusus Infinix Hot 11 Play X688B**.

> Ini bukan konverter ajaib yang bisa menjadikan image recovery dari HP apa pun langsung cocok untuk X688B. Kernel, DTB, fstab, partisi, input, dan konfigurasi hardware harus berasal dari target X688B. Repo donor dipakai sebagai referensi/audit; konfigurasi perangkat donor tidak disalin otomatis.

## Target bawaan

- Device: Infinix Hot 11 Play — `X688B`
- Firmware target yang dimaksud: `V788 / XOS 7.6.0 / Android 11`
- SoC: MediaTek `MT6765`
- TWRP manifest: `twrp-11`
- Device tree: [`NeonzDump/twrp_infinix_X688B`, branch `11`](https://github.com/NeonzDump/twrp_infinix_X688B/tree/11)
- Recovery partition limit dari BoardConfig tree: `40,894,464` bytes

Tree upstream menyetel boot image header v2 dan memakai kernel/DTB prebuilt. Workflow ini mengganti kernel dan DTB dengan yang diekstrak dari **stock boot.img target** sebelum kompilasi.

## Cara pasang di GitHub

1. Download ZIP project ini, ekstrak.
2. Buat repository GitHub baru, misalnya `x688b-recovery-builder`.
3. Upload seluruh isi folder ini ke root repository. Pastikan folder `.github/workflows` ikut ter-upload.
4. Buka tab **Actions** dan aktifkan GitHub Actions bila diminta.
5. Pilih workflow **X688B Android 11 Recovery Builder** → **Run workflow**.

## Input saat Run workflow

| Input | Isi |
|---|---|
| `mode` | `audit` untuk cek donor saja; `build` untuk kompilasi recovery |
| `donor_github_url` | URL repo GitHub donor recovery/device tree Android 11. Boleh kosong |
| `donor_branch` | Branch repo donor, misalnya `android-11`, `twrp-11`, atau `main` |
| `donor_device_tree_path` | Opsional: path folder donor yang berisi `BoardConfig.mk`, misalnya `device/brand/codename` |
| `target_build` | Label build target, isi `V788-XOS7.6.0-Android11` |
| `stock_boot_url` | URL HTTPS langsung ke **stock boot.img V788**. Kosongkan bila file tersedia di `stock/boot.img` |
| `stock_dtbo_url` | Opsional: URL HTTPS langsung ke `dtbo.img` stock V788 untuk mengganti DTBO bawaan tree |

URL image harus URL unduhan langsung (contoh raw file/release asset), bukan halaman HTML GitHub. Repo donor harus publik dan URL berbentuk `https://github.com/OWNER/REPO`.

### Stock boot image wajib untuk build V788

Taruh **boot.img stock/original yang belum dipatch Magisk** pada `stock/boot.img`, atau isi `stock_boot_url` ketika menjalankan workflow.

Opsional: jika DTB tidak ikut terbungkus pada boot image, taruh DTB firmware V788 di `stock/dtb.img`. Bila tersedia `dtbo.img` V788, taruh di `stock/dtbo.img` atau isi `stock_dtbo_url`.

Jangan gunakan `magisk_patched-*.img` sebagai sumber utama. Jangan mengunggah `userdata`, dump data pribadi, atau file yang berisi informasi akun.

## Output

Setiap run mengunggah artifact bernama `X688B-TWRP11-output`, berisi:

- `recovery.img` — hanya jika build berhasil dan ukuran lolos batas partisi
- `build-report.md` — ringkasan target, commit, ukuran, hash, dan status
- `donor-audit.md` — perbandingan parameter donor dan target (bila donor diisi)
- `build.log` — log build untuk diagnosis

Mode `audit` tidak mengompilasi Android; ini dipakai untuk menilai konfigurasi donor sebelum mencoba build.

## Yang tidak dilakukan otomatis

- Tidak memindahkan seluruh ramdisk donor ke X688B.
- Tidak menyalin kernel, DTB, fstab, partition map, SELinux policy, atau vendor blobs dari HP donor.
- Tidak mematikan AVB, mengubah vbmeta, mem-format data, atau mem-flash partisi.
- Tidak menjamin recovery bisa boot hanya karena proses kompilasi sukses.

Perbedaan layar/touch, storage encryption, MTP, ADB, fastbootd, recovery fstab, dan dynamic partition tetap perlu diuji pada perangkat target. Build V788 belum dapat disebut terverifikasi sampai boot dan fungsi recovery diuji dengan aman.

## Peringatan kompatibilitas

Device tree upstream adalah titik awal komunitas, bukan sertifikasi bahwa semua revisi firmware X688B identik. Build komunitas lain yang ditemukan menyebut pengujian pada firmware V865, bukan V788. Karena itu workflow meminta stock `boot.img` target untuk menyelaraskan kernel dan DTB; tetap periksa log dan cadangkan partisi penting sebelum eksperimen.

**Jangan flash artifact hanya karena file bernama `recovery.img`.** Pastikan model, firmware, ukuran, header, dan partisi cocok. Jangan flash ke `boot` atau `recovery` berdasarkan tebakan. Build ini tidak menyediakan perintah flash otomatis.

## Upstream / referensi teknis

- X688B TWRP device tree: https://github.com/NeonzDump/twrp_infinix_X688B/tree/11
- TWRP 11 manifest: https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp/tree/twrp-11
- Android boot image header documentation: https://source.android.com/docs/core/architecture/bootloader/boot-image-header
