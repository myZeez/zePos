; Installer ZePOS untuk Windows.
;
; Bangun dengan: installer\build_installer.ps1
; atau langsung:  ISCC.exe installer\zepos.iss
;
; Data toko TIDAK disimpan di folder pemasangan. Sejak versi ini seluruh
; basis data dan backup berada di %APPDATA%\ZePOS, sehingga memasang ulang,
; memindahkan, atau memutakhirkan aplikasi tidak menyentuh catatan penjualan.

#define AppName "ZePOS"
#define AppVersion "1.0.0"
#define AppPublisher "Zeez3.o by 13ud1.aat"
#define AppExeName "zepos.exe"
#define SourceDir "..\build\windows\x64\runner\Release"

[Setup]
; AppId menandai aplikasi ini secara tetap. Jangan diubah: nilai inilah yang
; membuat pemasangan berikutnya menggantikan versi lama, bukan menumpuk
; sebagai entri kedua di Apps & features.
AppId={{7C4E2F16-9B3A-4D58-8E71-2A5F6C0D9B34}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppCopyright=Copyright (C) 2026 zeez3.o by Budi Aulyansyah Ahmad Trisna
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
LicenseFile=
OutputDir=..\dist
OutputBaseFilename=ZePOS-Setup-{#AppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Dipasang untuk pengguna yang sedang masuk, tanpa meminta hak administrator.
;
; Data toko memang sudah per pengguna di %APPDATA%\ZePOS, jadi pemasangan per
; pengguna membuat keduanya konsisten: kasir dapat memasang, memutakhirkan,
; maupun menghapus ZePOS sendiri tanpa perlu akun administrator.
; Tambahkan /ALLUSERS pada baris perintah bila ingin memasang untuk semua akun.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=commandline
; Menutup ZePOS yang sedang berjalan agar berkasnya dapat diganti, lalu
; membukanya kembali setelah selesai.
CloseApplications=yes
RestartApplications=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

; Inno Setup tidak membawa berkas bahasa Indonesia, jadi kalimat yang benar
; benar dibaca pemilik toko selama pemasangan ditimpa di sini. Sisanya, yang
; hanya muncul pada keadaan tak lazim, tetap memakai bawaan.
[Messages]
SetupAppTitle=Pemasang
SetupWindowTitle=Pemasangan %1
WelcomeLabel1=Selamat datang di pemasangan [name]
WelcomeLabel2=Program ini akan memasang [name/ver] pada komputer Anda.%n%nTutup aplikasi lain sebelum melanjutkan.
ClickNext=Klik Lanjut untuk meneruskan, atau Batal untuk keluar.
WizardSelectDir=Pilih Lokasi Pemasangan
SelectDirDesc=Di mana [name] akan dipasang?
SelectDirLabel3=Pemasang akan menaruh [name] pada folder berikut.
SelectDirBrowseLabel=Klik Lanjut untuk meneruskan. Untuk memilih folder lain, klik Telusuri.
DiskSpaceGBLabel=Diperlukan ruang kosong minimal [gb] GB.
DiskSpaceMBLabel=Diperlukan ruang kosong minimal [mb] MB.
WizardSelectTasks=Pilih Tugas Tambahan
SelectTasksDesc=Tugas tambahan apa yang perlu dijalankan?
SelectTasksLabel2=Pilih tugas tambahan yang diinginkan, lalu klik Lanjut.
WizardReady=Siap Memasang
ReadyLabel1=Pemasang siap memasang [name] pada komputer Anda.
ReadyLabel2a=Klik Pasang untuk memulai, atau klik Kembali untuk memeriksa kembali pengaturannya.
ReadyLabel2b=Klik Pasang untuk memulai pemasangan.
ReadyMemoDir=Lokasi pemasangan:
ReadyMemoTasks=Tugas tambahan:
WizardInstalling=Sedang Memasang
InstallingLabel=Mohon tunggu, [name] sedang dipasang.
FinishedHeadingLabel=Pemasangan [name] selesai
FinishedLabel=[name] sudah terpasang di komputer Anda dan dapat dijalankan melalui pintasan yang tersedia.
FinishedLabelNoIcons=[name] sudah terpasang di komputer Anda.
ClickFinish=Klik Selesai untuk menutup pemasang.
ButtonNext=&Lanjut
ButtonBack=&Kembali
ButtonInstall=&Pasang
ButtonCancel=Batal
ButtonFinish=&Selesai
ButtonBrowse=&Telusuri...
ButtonYes=&Ya
ButtonNo=&Tidak
ExitSetupTitle=Keluar dari Pemasangan
ExitSetupMessage=Pemasangan belum selesai. Bila keluar sekarang, [name] tidak akan terpasang.%n%nKeluar dari pemasangan?
ConfirmUninstall=Hapus %1 beserta seluruh komponennya dari komputer ini?
UninstallStatusLabel=Mohon tunggu, %1 sedang dihapus.
UninstalledAll=%1 berhasil dihapus dari komputer ini.
UninstalledMost=%1 sudah dihapus, tetapi sebagian berkas tidak dapat dihapus dan dapat dibuang sendiri.
StatusExtractFiles=Menyalin berkas...
StatusCreateIcons=Membuat pintasan...
StatusUninstalling=Menghapus %1...

[Tasks]
Name: "desktopicon"; Description: "Buat pintasan di Desktop"; GroupDescription: "Pintasan:"

[Files]
Source: "{#SourceDir}\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "BACA-DULU.txt"; DestDir: "{app}"; Flags: ignoreversion isreadme

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Jalankan {#AppName} sekarang"; Flags: nowait postinstall skipifsilent

[Code]
function StoreDataDir: String;
begin
  Result := ExpandConstant('{userappdata}\ZePOS');
end;

function HasCmdLineParam(const Value: String): Boolean;
var
  Index: Integer;
begin
  Result := False;
  for Index := 1 to ParamCount do
  begin
    if CompareText(ParamStr(Index), Value) = 0 then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

// Menentukan apakah catatan toko ikut dihapus.
//
// Pada uninstall senyap tidak ada seorang pun yang dapat menjawab kotak
// dialog. Menampilkannya di sana membuat proses menggantung selamanya, dan
// membiarkannya menghapus data secara diam-diam jauh lebih buruk lagi. Karena
// itu mode senyap selalu menyimpan data, kecuali penghapusan diminta secara
// tertulis melalui /DELETEDATA.
function ShouldRemoveStoreData: Boolean;
begin
  if UninstallSilent then
  begin
    Result := HasCmdLineParam('/DELETEDATA');
    Exit;
  end;

  Result := MsgBox(
    'Hapus juga seluruh data toko?' + #13#10 + #13#10 +
    'Termasuk produk, transaksi, laporan, dan seluruh backup pada:' + #13#10 +
    StoreDataDir + #13#10 + #13#10 +
    'Tindakan ini tidak dapat dibatalkan.' + #13#10 +
    'Pilih No bila ZePOS akan dipasang kembali nanti.',
    mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES;
end;

// Menghapus aplikasi tidak dengan sendirinya menghapus catatan toko: basis
// data memuat seluruh produk, transaksi, laporan, dan backup, dan sebuah toko
// tidak boleh kehilangan pembukuannya hanya karena memasang ulang aplikasi.
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
  begin
    if DirExists(StoreDataDir) and ShouldRemoveStoreData then
    begin
      DelTree(StoreDataDir, True, True, True);
    end;
  end;
end;
