#define MyAppName "TahoePaste"
#define MyAppPublisher "TahoePaste"
#define MyAppExeName "TahoePaste.exe"

#ifndef AppVersion
#define AppVersion "1.0.0"
#endif

; VersionInfoProductVersion only accepts dotted numerics, so dev builds
; ("0.3.1-7-gabc1234") pass the plain numeric part separately.
#ifndef AppNumericVersion
#define AppNumericVersion AppVersion
#endif

#ifndef SourceDir
#define SourceDir "..\src\TahoePaste.Windows\bin\Release\net10.0-windows10.0.26100.0\win-x64\publish"
#endif

#ifndef OutputDir
#define OutputDir "..\dist"
#endif

[Setup]
AppId={{6F6E8B51-6818-4A3B-9B2A-48B71FC36303}
AppName={#MyAppName}
AppVersion={#AppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf64}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename=TahoePaste-Windows-x64-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
SetupIconFile=..\src\TahoePaste.Windows\Assets\tahoepaste.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription=Local-only clipboard manager for Windows 11
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#AppNumericVersion}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent
