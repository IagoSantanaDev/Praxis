; Instalador do Praxis
; Gerado para builds produzidos por tools/build-praxis.ps1
;
; Observação: este instalador distribui o executável compilado e recursos necessários,
; não o código-fonte AutoHotkey. Isso reduz exposição, mas não impede engenharia reversa.

#ifndef AppVersion
#define AppVersion "1.0.0"
#endif

#ifndef SourceDir
#define SourceDir "..\dist\Praxis-1.0.0\stage"
#endif

#ifndef OutputDir
#define OutputDir "..\dist\Praxis-1.0.0\installer"
#endif

[Setup]
AppId={{A64C7246-AD51-4B65-9F0B-747D4970273F}
AppName=Praxis
AppVersion={#AppVersion}
AppPublisher=Iago Santana Lima
AppPublisherURL=
AppSupportURL=
AppUpdatesURL=
DefaultDirName={localappdata}\Programs\Praxis
DefaultGroupName=Praxis
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename=Praxis-Setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupLogging=yes
LicenseFile=..\LICENSE
UninstallDisplayIcon={app}\Praxis.exe
VersionInfoVersion={#AppVersion}
VersionInfoCompany=Iago Santana Lima
VersionInfoDescription=Praxis - Automação Hospitalar
VersionInfoProductName=Praxis
VersionInfoProductVersion={#AppVersion}

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "Criar atalho na Área de Trabalho"; GroupDescription: "Atalhos:"; Flags: unchecked

[Files]
Source: "{#SourceDir}\Praxis.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\ui\*"; DestDir: "{app}\ui"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#SourceDir}\lib\64bit\WebView2Loader.dll"; DestDir: "{app}\lib\64bit"; Flags: ignoreversion
Source: "{#SourceDir}\Praxis-build-manifest.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
#ifexist SourceDir + "\COPYRIGHT"
Source: "{#SourceDir}\COPYRIGHT"; DestDir: "{app}"; Flags: ignoreversion
#endif
#ifexist SourceDir + "\NOTICE.md"
Source: "{#SourceDir}\NOTICE.md"; DestDir: "{app}"; Flags: ignoreversion
#endif
#ifexist SourceDir + "\EULA.md"
Source: "{#SourceDir}\EULA.md"; DestDir: "{app}"; Flags: ignoreversion
#endif
#ifexist SourceDir + "\NDA.md"
Source: "{#SourceDir}\NDA.md"; DestDir: "{app}"; Flags: ignoreversion
#endif
#ifexist SourceDir + "\PRIVACY_LGPD.md"
Source: "{#SourceDir}\PRIVACY_LGPD.md"; DestDir: "{app}"; Flags: ignoreversion
#endif
#ifexist SourceDir + "\THIRD_PARTY_NOTICES.md"
Source: "{#SourceDir}\THIRD_PARTY_NOTICES.md"; DestDir: "{app}"; Flags: ignoreversion
#endif
#ifexist SourceDir + "\README.md"
Source: "{#SourceDir}\README.md"; DestDir: "{app}"; Flags: ignoreversion
#endif

[Dirs]
Name: "{userdocs}\Praxis"

[INI]
Filename: "{app}\config.ini"; Section: "Paths"; Key: "WorkDir"; String: "{userdocs}\Praxis"

[Icons]
Name: "{group}\Praxis"; Filename: "{app}\Praxis.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\Praxis"; Filename: "{app}\Praxis.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\Praxis.exe"; Description: "Abrir Praxis"; Flags: nowait postinstall skipifsilent

[Code]
function InitializeSetup(): Boolean;
begin
  Result := True;
end;
