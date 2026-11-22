; Inno Setup script for Graph Algorithm Studio (Windows x64).
; Compile with:  ISCC.exe packaging\installer.iss
; (run packaging\package.ps1 to build + deploy + compile in one step).
; Paths are relative to this .iss file (packaging\).
;
; Names below carry the "Graph Algorithm Studio" brand. Two things are kept
; stable on purpose and intentionally NOT renamed: the settings key
; (main.cpp's setApplicationName "graph_visualizer"), so an existing user's saved
; config is preserved; and the AppId, so a new installer upgrades a prior install
; in place rather than leaving two copies.

#define AppName "Graph Algorithm Studio"
; Filesystem-safe name for the Start-menu folder / shortcut files.
#define ShortcutName "Graph Algorithm Studio"
; Version (Major.Minor.Patch.Build) is passed in by package.ps1 from the same
; CMake/git source as the app's title-bar version: AppVersion is the display /
; filename form (zero-padded build, e.g. 1.0.1.0089); AppVerInfo is the numeric
; form Inno needs for the binary VersionInfo resource (e.g. 1.0.1.89). The
; defaults let ISCC compile the script standalone.
#ifndef AppVersion
  #define AppVersion "1.0.1.0"
#endif
#ifndef AppVerInfo
  #define AppVerInfo "1.0.1.0"
#endif
#define AppExe "graph_algorithm_studio.exe"
#define AppPublisher "graph_algo"
#define DistDir "..\build-release\dist"

[Setup]
; A stable unique id so upgrades replace the previous install.
AppId={{B2E4D3A6-7C8F-4A1B-9D2E-3F4A5B6C7D8E}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
; Numeric x.x.x.x stamped into setup.exe's file-version resource.
VersionInfoVersion={#AppVerInfo}
AppPublisher={#AppPublisher}
; Per-user install: no admin/UAC. With lowest privileges the "auto" constants
; resolve to per-user locations ({autopf} -> {localappdata}\Programs, {group}
; and {autodesktop} -> the current user's menu/desktop).
PrivilegesRequired=lowest
DefaultDirName={autopf}\graph_algorithm_studio
DefaultGroupName={#ShortcutName}
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
OutputDir=..\build-release
OutputBaseFilename=graph_algorithm_studio-{#AppVersion}-setup
SetupIconFile=..\ga_logo.ico
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; 64-bit app: install under 64-bit Program Files and only on x64 Windows.
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
LicenseFile=THIRD-PARTY-NOTICES.txt
; Code signing (optional): package.ps1 -SignToolCmd "..." passes /DSIGN and a
; "signtool" sign-tool definition, which signs the installer + uninstaller.
#ifdef SIGN
SignTool=signtool
SignedUninstaller=yes
#endif

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"

[Files]
Source: "{#DistDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion
; Bundle the sample graphs (incl. world_airlines.json) so there is data to open.
Source: "..\samples\*"; DestDir: "{app}\samples"; Flags: recursesubdirs createallsubdirs ignoreversion
Source: "THIRD-PARTY-NOTICES.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#ShortcutName}"; Filename: "{app}\{#AppExe}"
Name: "{group}\Uninstall {#ShortcutName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#ShortcutName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "Launch {#AppName}"; Flags: nowait postinstall skipifsilent
