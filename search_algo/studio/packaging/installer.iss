; Inno Setup script for Search Algorithm Studio (Windows x64).
; Compile with:  ISCC.exe packaging\installer.iss
; (run packaging\package.ps1 to build + deploy + compile in one step).
; Paths are relative to this .iss file (packaging\).
;
; The settings key (main.cpp's setApplicationName "search_algo") and the AppId are
; kept stable on purpose: the former preserves an existing user's saved config, the
; latter makes a new installer upgrade a prior install in place.

#define AppName "Search Algorithm Studio"
; Filesystem-safe name for the Start-menu folder / shortcut files.
#define ShortcutName "Search Algorithm Studio"
; Version (Major.Minor.Patch.Build) is passed in by package.ps1 from the same
; CMake/git source as the app's title-bar version: AppVersion is the display /
; filename form (zero-padded build); AppVerInfo is the numeric form Inno needs for
; the binary VersionInfo resource. The defaults let ISCC compile the script standalone.
#ifndef AppVersion
  #define AppVersion "1.0.0.0"
#endif
#ifndef AppVerInfo
  #define AppVerInfo "1.0.0.0"
#endif
#define AppExe "search_algorithm_studio.exe"
#define AppPublisher "search_algo"
#define DistDir "..\build-release\dist"

[Setup]
; A stable unique id so upgrades replace the previous install.
AppId={{B8E3F5A2-1C4D-4A7E-9B6F-3E8D2C5A9F14}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
; Numeric x.x.x.x stamped into setup.exe's file-version resource.
VersionInfoVersion={#AppVerInfo}
AppPublisher={#AppPublisher}
; Per-user install: no admin/UAC. With lowest privileges the "auto" constants resolve
; to per-user locations ({autopf} -> {localappdata}\Programs, {group} and
; {autodesktop} -> the current user's menu/desktop).
PrivilegesRequired=lowest
DefaultDirName={autopf}\search_algorithm_studio
DefaultGroupName={#ShortcutName}
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
OutputDir=..\build-release
OutputBaseFilename=search_algorithm_studio-{#AppVersion}-setup
; setup.exe icon (also embedded in the app exe via appicon.rc). Path is relative to
; this .iss (packaging\), so it points at studio\search_logo.ico.
SetupIconFile=..\search_logo.ico
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
Source: "THIRD-PARTY-NOTICES.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#ShortcutName}"; Filename: "{app}\{#AppExe}"
Name: "{group}\Uninstall {#ShortcutName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#ShortcutName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "Launch {#AppName}"; Flags: nowait postinstall skipifsilent
