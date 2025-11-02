# linux-audit-safe

Wrapper aman untuk berbagai tool audit/enumerasi Linux. Dirancang untuk penggunaan yang bertanggung jawab dengan fitur keamanan tambahan.

## Fitur Keamanan

- **Tidak auto-update** secara default - tool tidak akan otomatis di-clone/update tanpa flag eksplisit
- **Mode dry-run** - lihat apa yang akan dilakukan tanpa menjalankannya
- **Mode interaktif** - konfirmasi sebelum menjalankan pemeriksaan sensitif
- **Whitelist tool** - hanya tool yang sudah divalidasi yang akan dijalankan otomatis
- **Permisi file ketat** - log dan tool dibuat dengan permisi 700/600
- **Konfirmasi eksplisit** untuk pemeriksaan privileged (root)

## Prasyarat

```bash
# Tool yang diperlukan:
- bash
- git (jika ingin mengunduh tool)
- wget (opsional, untuk linpeas)
- python3 (opsional, untuk beberapa tool)
```

## Instalasi

```bash
# Clone atau download script
chmod +x linux-audit-safe.sh

# Jalankan pertama kali (dry-run untuk melihat apa yang akan dilakukan)
./linux-audit-safe.sh --dry-run --update
```

## Penggunaan Dasar

### 1. Menjalankan Audit Tanpa Root (Paling Aman)

```bash
# Dengan tool yang sudah ada (tidak download tool baru)
./linux-audit-safe.sh --skip-tools

# Atau download tool terlebih dahulu, lalu jalankan audit
./linux-audit-safe.sh --update --tools-only    # download tool saja
./linux-audit-safe.sh --skip-tools              # jalankan audit
```

### 2. Menjalankan Audit dengan Root (Hati-hati!)

```bash
# Anda akan diminta konfirmasi
sudo ./linux-audit-safe.sh --run-as-root --skip-tools

# Mode non-interaktif (otomatis, berbahaya!)
sudo ./linux-audit-safe.sh --run-as-root --no-interactive --skip-tools
```

### 3. Mode Dry-Run (Simulasi)

```bash
# Lihat apa yang akan dilakukan tanpa benar-benar menjalankannya
./linux-audit-safe.sh --dry-run --update
```

## Opsi Command Line

| Opsi | Deskripsi |
|------|-----------|
| `--help` | Tampilkan bantuan |
| `--dry-run` | Simulasi, tidak menjalankan perintah sesungguhnya |
| `--no-interactive` | Tidak ada prompt, gunakan nilai default (hati-hati!) |
| `--no-update` | Jangan update tool (default) |
| `--update` | Izinkan clone/update tool dari upstream (opt-in) |
| `--run-as-root` | Izinkan pemeriksaan privileged (akan ada prompt) |
| `--tools-only` | Hanya download/update tool, jangan jalankan audit |
| `--skip-tools` | Jangan update tool, langsung jalankan audit |

## Workflow yang Direkomendasikan

### Untuk Pengguna Baru

```bash
# 1. Lihat apa yang akan dilakukan (dry-run)
./linux-audit-safe.sh --dry-run --update

# 2. Download tool (jika setuju)
./linux-audit-safe.sh --update --tools-only

# 3. Inspeksi tool yang sudah didownload
ls -la tools/

# 4. Jalankan audit unprivileged
./linux-audit-safe.sh --skip-tools

# 5. Lihat hasil
ls -la logs/
```

### Untuk Audit Cepat

```bash
# Gunakan tool yang sudah ada, langsung audit
./linux-audit-safe.sh --skip-tools
```

### Untuk Audit Lengkap (dengan Root)

```bash
# Hati-hati! Pastikan Anda paham risikonya
sudo ./linux-audit-safe.sh --run-as-root --skip-tools
```

## Struktur Direktori

```
.
├── linux-audit-safe.sh          # Script utama
├── tools/                        # Tool audit (dibuat otomatis)
│   ├── linpeas.sh
│   ├── lynis/
│   ├── LinEnum/
│   ├── linux-exploit-suggester/
│   └── ...
└── logs/                         # Hasil audit (dibuat otomatis)
    └── hostname-timestamp-linux-audit/
        ├── lynis.log
        ├── linpeas.log
        ├── les.log
        └── ...
```

## Tool yang Diaudit

Script ini dapat mengunduh dan menjalankan tool berikut (jika di-whitelist):

- **linpeas** - Linux Privilege Escalation Awesome Script
- **lynis** - Security auditing tool
- **LinEnum** - Linux Enumeration Script
- **linux-exploit-suggester** - Exploit suggester
- **linux-smart-enumeration** - Smart enumeration
- **kernel-hardening-checker** - Kernel security checker
- **checksec** - Binary security checker
- Dan lainnya...

## Keamanan dan Perhatian

⚠️ **PENTING:**

1. **Jangan jalankan di sistem produksi** tanpa izin dan pemahaman yang jelas
2. **Inspeksi tool** sebelum menjalankannya pertama kali
3. **Gunakan --dry-run** terlebih dahulu untuk melihat apa yang akan dilakukan
4. **Hati-hati dengan mode root** - dapat mengumpulkan data sensitif
5. **Review log output** - mungkin berisi informasi sensitif sistem
6. Tool audit dapat memicu alert di sistem monitoring/IDS

## Troubleshooting

### Git tidak ditemukan
```bash
# Install git terlebih dahulu
sudo apt-get install git    # Debian/Ubuntu
sudo yum install git        # RHEL/CentOS
```

### Permisi ditolak
```bash
# Pastikan script executable
chmod +x linux-audit-safe.sh

# Untuk pemeriksaan root
sudo ./linux-audit-safe.sh --run-as-root
```

### Tool tidak dijalankan otomatis
Tool hanya dijalankan jika ada dalam whitelist. Untuk menjalankan tool lain secara manual:

```bash
# Lihat tool yang tersedia
ls -la tools/

# Jalankan manual
bash tools/nama-tool/script.sh
```

## Contoh Output

```
--[ linux-audit-safe v0.1-20251102 ]--

[*]  Running with options: dry-run=false interactive=true update_deps=false...

[*]  Date:    Sun Nov  2 10:30:45 WIB 2025
[*]  Hostname: myserver
[*]  System:  Linux myserver 5.15.0-91-generic
[*]  User:    uid=1000(user) gid=1000(user)
[*]  Log:     /path/to/logs/myserver-20251102103045-linux-audit

[*]  Running unprivileged checks...
[*]  Running: bash ".../linux-exploit-suggester/linux-exploit-suggester.sh"
...
[*]  Complete
```

## Lisensi dan Tanggung Jawab

Script ini disediakan untuk tujuan audit keamanan yang sah dan bertanggung jawab. Pengguna bertanggung jawab penuh atas penggunaan tool ini. Pastikan Anda memiliki izin yang sesuai sebelum menjalankan audit pada sistem apa pun.

## Kontribusi

Jika menemukan bug atau ingin menambahkan fitur keamanan, silakan buat issue atau pull request.

---

**Versi:** 0.1-20251102  
**Status:** Safety-hardened wrapper - gunakan dengan hati-hati dan bertanggung jawab
