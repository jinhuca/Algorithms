; Inno Setup script for the Algorithms umbrella app (Windows x64).
; Compile with:  ISCC.exe packaging\installer.iss
; (run scripts\package-all.ps1 to build + deploy + compile every installer in one step).
; Paths are relative to this .iss file (algorithms_studio\packaging\).
;
; AppId is kept stable so a new installer upgrades a prior install in place.

#define AppName "Algorithms"
#define ShortcutName "Algorithms"
; Version (Major.Minor.Patch) passed in by package-all.ps1. The defaults let ISCC
; compile the script standalone.
#ifndef AppVersion
  #define AppVersion "1.0.0.0"
#endif
#ifndef AppVerInfo
  #define AppVerInfo "1.0.0.0"
#endif
#define AppExe "algorithms_studio.exe"
#define AppPublisher "Algorithms"
#define DistDir "..\build-release\dist"

[Setup]
; A stable unique id so upgrades replace the previous install.
AppId={{B3F1B6A2-2C7E-4D9A-9F10-7A4E2C8D5B01}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
VersionInfoVersion={#AppVerInfo}
AppPublisher={#AppPublisher}
; Per-user install: no admin/UAC.
PrivilegesRequired=lowest
DefaultDirName={autopf}\Algorithms
DefaultGroupName={#ShortcutName}
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
OutputDir=..\build-release
OutputBaseFilename=algorithms-{#AppVersion}-setup
; Installer (setup.exe) icon — generated from Algorithm_Icon.svg (see scripts).
SetupIconFile=..\Algorithm_Icon.ico
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
#ifdef SIGN
SignTool=signtool
SignedUninstaller=yes
#endif

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"

[Files]
Source: "{#DistDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\{#ShortcutName}"; Filename: "{app}\{#AppExe}"
Name: "{group}\Uninstall {#ShortcutName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#ShortcutName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "Launch {#AppName}"; Flags: nowait postinstall skipifsilent
