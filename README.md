# MarchJson

MarchJson adalah wrapper JSON-aware ringan untuk PowerShell 7 dan Bash/SSH. Command tetap diketik seperti biasa, tetapi output JSON dari command terpilih otomatis di-pretty print dan diberi ANSI color melalui jq.

MarchJson bersifat selektif agar command interaktif, watcher, server, Git, SSH, dan proses streaming tetap aman dan realtime.

## Fitur

- Pretty JSON otomatis untuk command terpilih.
- ANSI syntax coloring melalui jq -C.
- Wrapper curl.
- Wrapper npm run <script> berbasis whitelist.
- Wrapper node -e / node --eval.
- Whitelist npm di file terpisah.
- Manager MarchJson pada PowerShell dan marchjson pada Bash.
- Alias singkat: h, s, l, a, r, e, rl.
- Semantic versioning dengan satu sumber versi di file VERSION.
- Command version pada PowerShell dan Bash.
- CHANGELOG.md untuk riwayat rilis.
- Bypass ke executable native.
- Resolver PowerShell kompatibel dengan FNM dan beberapa fnm_multishells.

## Requirement

### PowerShell

- PowerShell 7.
- jq direkomendasikan.

~~~powershell
winget install --id jqlang.jq -e
~~~

### Bash / Solar-PuTTY / SSH

- Bash.
- jq.

Untuk cPanel tanpa root:

~~~bash
mkdir -p "$HOME/.local/bin"
curl -fL "https://github.com/jqlang/jq/releases/latest/download/jq-linux-amd64" -o "$HOME/.local/bin/jq"
chmod +x "$HOME/.local/bin/jq"
export PATH="$HOME/.local/bin:$PATH"
~~~

## Instalasi PowerShell

~~~powershell
$marchJsonHome = "$HOME\.local\share\MarchJson"
git clone https://github.com/MarchTechnology/MarchJson.git $marchJsonHome
~~~

Tambahkan ke $PROFILE setelah inisialisasi FNM:

~~~powershell
. "$HOME\.local\share\MarchJson\powershell\MarchJson.ps1"
~~~

Reload dan cek:

~~~powershell
. $PROFILE
MarchJson status
~~~

Default whitelist PowerShell:

~~~text
C:\Users\<user>\.config\powershell\json-npm-whitelist.txt
~~~

Override opsional:

~~~powershell
$env:MARCHJSON_NPM_WHITELIST = "$HOME\.config\marchjson\npm-whitelist.txt"
~~~

## Instalasi Bash / Solar-PuTTY

Clone repository ke direktori khusus MarchJson:

~~~bash
mkdir -p "$HOME/.local/share"
git clone https://github.com/MarchTechnology/MarchJson.git "$HOME/.local/share/marchjson"
~~~

Jalankan installer SSH:

~~~bash
bash "$HOME/.local/share/marchjson/scripts/install-ssh.sh"
~~~

Installer menambahkan blok source MarchJson secara idempotent ke ~/.bashrc, membuat backup ~/.bashrc terlebih dahulu, lalu memvalidasi syntax Bash sebelum perubahan diterapkan.

Reload dan cek:

~~~bash
source ~/.bashrc
marchjson status
~~~

### Coexistence dengan march-env

MarchJson dan march-env menggunakan path yang berbeda:

~~~text
MarchJson:
  ~/.local/share/marchjson/

march-env:
  ~/.local/bin/march-env
~~~

Installer SSH MarchJson **tidak menginstal, mengganti, memindahkan, chmod, atau menghapus file apa pun di ~/.local/bin**. Secara khusus, ~/.local/bin/march-env dianggap sebagai protected sibling tool.

Jika march-env sudah ada, installer mengambil fingerprint sebelum dan sesudah instalasi. Jika fingerprint berubah selama proses, instalasi dianggap gagal dan backup ~/.bashrc dikembalikan.

Installer hanya mengelola blok berikut di ~/.bashrc:

~~~text
# >>> MarchJson >>>
source <path>/bash/marchjson.sh
# <<< MarchJson <<<
~~~

Konfigurasi lain di ~/.bashrc, termasuk konfigurasi march-env, harus tetap dipertahankan.

Instalasi jq untuk shared hosting juga hanya menulis file ~/.local/bin/jq. Perintah mkdir -p ~/.local/bin aman untuk direktori yang sudah ada dan tidak menghapus march-env.

Untuk memverifikasi coexistence setelah instalasi:

~~~bash
command -v march-env
command -v jq
marchjson status
~~~

Default whitelist Bash:

~~~text
~/.config/march/json-npm-whitelist.txt
~~~

Override opsional:

~~~bash
export MARCHJSON_NPM_WHITELIST="$HOME/.config/marchjson/npm-whitelist.txt"
~~~

## Command manager

PowerShell:

~~~powershell
MarchJson -h
MarchJson h
MarchJson help
MarchJson ?
MarchJson s
MarchJson status
MarchJson l
MarchJson list
MarchJson a tiktok:recon
MarchJson add tiktok:recon
MarchJson r tiktok:recon
MarchJson remove tiktok:recon
MarchJson e
MarchJson edit
MarchJson rl
MarchJson reload
MarchJson -v
MarchJson --version
MarchJson v
MarchJson version
~~~

Bash:

~~~bash
marchjson -h
marchjson h
marchjson help
marchjson '?'
marchjson s
marchjson status
marchjson l
marchjson list
marchjson a tiktok:recon
marchjson add tiktok:recon
marchjson r tiktok:recon
marchjson remove tiktok:recon
marchjson e
marchjson edit
marchjson rl
marchjson reload
marchjson -v
marchjson --version
marchjson v
marchjson version
~~~

## Versioning

MarchJson mengikuti Semantic Versioning (SemVer):

~~~text
MAJOR.MINOR.PATCH
~~~

Aturan:

- MAJOR untuk perubahan yang tidak backward-compatible.
- MINOR untuk fitur baru yang backward-compatible.
- PATCH untuk bug fix yang backward-compatible.

Sumber versi tunggal repository adalah:

~~~text
VERSION
~~~

PowerShell dan Bash membaca file VERSION secara dinamis. Jika file hilang atau nilainya bukan SemVer valid, runtime menggunakan fallback:

~~~text
0.0.0-dev
~~~

Versi aktif:

~~~powershell
MarchJson --version
MarchJson v
MarchJson status
~~~

~~~bash
marchjson --version
marchjson v
marchjson status
~~~

Untuk menaikkan versi dari Bash:

~~~bash
bash scripts/set-version.sh 0.2.1
~~~

Untuk menaikkan versi dari PowerShell:

~~~powershell
pwsh scripts/set-version.ps1 0.2.1
~~~

Setelah mengubah versi:

1. perbarui CHANGELOG.md;
2. jalankan acceptance versioning;
3. commit perubahan;
4. buat Git tag dengan format vMAJOR.MINOR.PATCH saat merilis.

Acceptance:

~~~bash
bash scripts/acceptance/versioning.sh
~~~

Riwayat perubahan tersedia di [CHANGELOG.md](CHANGELOG.md).

## Contoh whitelist

~~~text
# MarchDownloader
tiktok:live
tiktok:recon
tiktok:variants

# MarchPayments
staging:verify
production:verify
deploy:production:prepare
~~~

Baris kosong dan komentar yang diawali # diabaikan.

## Wrapper

### curl

~~~powershell
curl https://example.com/api
~~~

JSON valid otomatis pretty + color. Operasi file seperti -o, -O, -T, --output, --remote-name, dan --upload-file dilewatkan ke curl native.

### npm

Hanya script whitelist yang dibuffer:

~~~powershell
npm run tiktok:recon -- "https://..."
~~~

Command lain tetap native dan realtime:

~~~text
npm install
npm test
npm start
npm run dev
npm run watch
~~~

Jangan whitelist server, watcher, atau proses long-running.

### node

Hanya eval mode yang JSON-aware:

~~~powershell
node -e "console.log(JSON.stringify({ok:true,count:12}))"
~~~

node server.js tetap native.

## Bypass

PowerShell:

~~~powershell
curl.exe ...
npm.cmd ...
node.exe ...
~~~

Bash:

~~~bash
command curl ...
command npm ...
command node ...
~~~

## Warna jq

MarchJson memakai jq -C. Palette dapat diubah dengan JQ_COLORS.

PowerShell:

~~~powershell
$env:JQ_COLORS = "1;90:1;31:1;32:1;35:0;33:1;37:1;37:1;36"
~~~

Bash:

~~~bash
export JQ_COLORS='1;90:1;31:1;32:1;35:0;33:1;37:1;37:1;36'
~~~

## Batasan

Deteksi saat ini mendukung:
1. seluruh output sebagai satu dokumen JSON;
2. mixed output dengan JSON compact per baris.

JSON multiline yang tertanam di tengah mixed log belum direkonstruksi lintas baris. Wrapper selektif membuffer command yang dipilih sampai proses selesai.

## Layout

~~~text
MarchJson/
├── bash/
│   └── marchjson.sh
├── powershell/
│   └── MarchJson.ps1
├── scripts/
│   ├── acceptance/
│   │   ├── install-ssh-coexistence.sh
│   │   └── versioning.sh
│   ├── install-ssh.sh
│   ├── set-version.ps1
│   └── set-version.sh
├── CHANGELOG.md
├── MILESTONE.md
├── README.md
└── VERSION
~~~

## Status

Versi saat ini: **0.2.0**. Nilai canonical tetap dibaca dari VERSION. Lihat CHANGELOG.md untuk riwayat rilis dan MILESTONE.md untuk status pengembangan.
