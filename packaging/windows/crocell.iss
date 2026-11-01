; Crocell installer for Windows x64. Built by scripts/build-windows.sh:
;   iscc /DAppVersion=0.4.0 /DSourceDir=..\..\dist\windows packaging\windows\crocell.iss
; Installs the app and crocelld into Program Files, then registers crocelld
; as a service. An update runs the same installer over the old one.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\dist\windows"
#endif

[Setup]
AppId={{6F3D2A8E-9B41-4C7E-8A55-2F1C0D7E4B93}
AppName=Crocell
AppVersion={#AppVersion}
AppVerName=Crocell {#AppVersion}
AppPublisher=Wiseless
AppPublisherURL=https://github.com/WiselessGroup/Crocell
AppSupportURL=https://github.com/WiselessGroup/Crocell/issues
AppUpdatesURL=https://github.com/WiselessGroup/Crocell/releases/latest
DefaultDirName={autopf}\Crocell
DisableProgramGroupPage=yes
DisableDirPage=auto
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
OutputDir=..\..\dist
OutputBaseFilename=Crocell-x86_64-Setup
SetupIconFile=crocell.ico
UninstallDisplayIcon={app}\crocell.exe
UninstallDisplayName=Crocell
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; The app holds files open; the installer closes it and the service is
; stopped in PrepareToInstall below.
CloseApplications=force
RestartApplications=no
LicenseFile=..\..\LICENSE

[Languages]
Name: "ru"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "en"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
ru.InstallingService=Устанавливаю службу Crocell…
en.InstallingService=Installing the Crocell service…

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{autoprograms}\Crocell"; Filename: "{app}\crocell.exe"; AppUserModelID: "net.wiseless.crocell"
Name: "{autodesktop}\Crocell"; Filename: "{app}\crocell.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\crocelld.exe"; Parameters: "install"; StatusMsg: "{cm:InstallingService}"; Flags: runhidden waituntilterminated
Filename: "{app}\crocell.exe"; Description: "{cm:LaunchProgram,Crocell}"; Flags: nowait postinstall skipifsilent runasoriginaluser

[UninstallRun]
Filename: "{app}\crocelld.exe"; Parameters: "uninstall"; Flags: runhidden waituntilterminated; RunOnceId: "crocelld"

[Code]
// An update replaces crocelld.exe, which the running service holds open:
// stop and unregister the old one first. [Run] registers the new one.
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  Old: String;
  Code: Integer;
begin
  Result := '';
  Old := ExpandConstant('{app}\crocelld.exe');
  if FileExists(Old) then
    Exec(Old, 'uninstall', '', SW_HIDE, ewWaitUntilTerminated, Code);
end;
