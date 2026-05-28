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

#ifndef AssetsDir
#define AssetsDir "assets"
#endif

#ifndef AppVersionInfoVersion
#define AppVersionInfoVersion "1.0.0.0"
#endif

#ifndef WebView2BootstrapperUrl
#define WebView2BootstrapperUrl "https://go.microsoft.com/fwlink/p/?LinkId=2124703"
#endif

#ifndef WebView2BootstrapperFile
#define WebView2BootstrapperFile "MicrosoftEdgeWebview2Setup.exe"
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
SetupIconFile={#AssetsDir}\icon.ico
WizardImageFile={#AssetsDir}\wizard-large.bmp
WizardSmallImageFile={#AssetsDir}\wizard-small.bmp
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupLogging=yes
LicenseFile=..\LICENSE
UninstallDisplayIcon={app}\Praxis.exe
VersionInfoVersion={#AppVersionInfoVersion}
VersionInfoCompany=Iago Santana Lima
VersionInfoDescription=Praxis - Automação Hospitalar
VersionInfoProductName=Praxis
VersionInfoProductVersion={#AppVersionInfoVersion}
VersionInfoCopyright=Copyright (C) Iago Santana Lima. Todos os direitos reservados.

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "Criar atalho na Área de Trabalho"; GroupDescription: "Atalhos:"; Flags: unchecked

[Files]
Source: "{#SourceDir}\Praxis.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\ui\*"; DestDir: "{app}\ui"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#SourceDir}\images\*"; DestDir: "{app}\images"; Flags: ignoreversion recursesubdirs createallsubdirs
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
const
  WebView2ClientGuid = '{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}';

function IsNonEmptyVersion(Value: String): Boolean;
begin
  Result := (Trim(Value) <> '') and (CompareText(Trim(Value), '0.0.0.0') <> 0);
end;

function HasWebView2RuntimeInRegistry(RootKey: Integer; SubKey: String): Boolean;
var
  Version: String;
begin
  Result := RegQueryStringValue(RootKey, SubKey, 'pv', Version) and IsNonEmptyVersion(Version);
end;

function IsWebView2RuntimeInstalled(): Boolean;
var
  ClientSubKey: String;
begin
  ClientSubKey := 'Software\Microsoft\EdgeUpdate\Clients\' + WebView2ClientGuid;

  Result :=
    HasWebView2RuntimeInRegistry(HKCU, ClientSubKey) or
    HasWebView2RuntimeInRegistry(HKLM, ClientSubKey) or
    HasWebView2RuntimeInRegistry(HKLM, 'Software\WOW6432Node\Microsoft\EdgeUpdate\Clients\' + WebView2ClientGuid);

  if Result then
    Log('Microsoft Edge WebView2 Runtime detectado.')
  else
    Log('Microsoft Edge WebView2 Runtime ausente; o bootstrapper Evergreen será baixado e instalado.');
end;

function WebView2DownloadProgress(const Url, FileName: String; const Progress, ProgressMax: Int64): Boolean;
begin
  if ProgressMax > 0 then
    WizardForm.StatusLabel.Caption := Format('Baixando Microsoft Edge WebView2 Runtime... %d%%', [Progress * 100 div ProgressMax])
  else
    WizardForm.StatusLabel.Caption := 'Baixando Microsoft Edge WebView2 Runtime...';

  Result := True;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  BootstrapperPath: String;
  ResultCode: Integer;
begin
  Result := '';

  if IsWebView2RuntimeInstalled() then
    Exit;

  BootstrapperPath := ExpandConstant('{tmp}\{#WebView2BootstrapperFile}');

  try
    WizardForm.StatusLabel.Caption := 'Baixando Microsoft Edge WebView2 Runtime...';
    DownloadTemporaryFile('{#WebView2BootstrapperUrl}', '{#WebView2BootstrapperFile}', '', @WebView2DownloadProgress);
  except
    Result := 'Não foi possível baixar o Microsoft Edge WebView2 Runtime. Verifique a conexão com a internet e execute o instalador novamente.';
    Exit;
  end;

  WizardForm.StatusLabel.Caption := 'Instalando Microsoft Edge WebView2 Runtime...';
  if not Exec(BootstrapperPath, '/silent /install', '', SW_SHOW, ewWaitUntilTerminated, ResultCode) then begin
    Result := 'Não foi possível executar o instalador do Microsoft Edge WebView2 Runtime.';
    Exit;
  end;

  if ResultCode <> 0 then begin
    Result := Format('A instalação do Microsoft Edge WebView2 Runtime falhou. Código de saída: %d.', [ResultCode]);
    Exit;
  end;

  if not IsWebView2RuntimeInstalled() then
    Result := 'O Microsoft Edge WebView2 Runtime não foi detectado após a instalação. Reinicie o Windows ou instale o WebView2 Runtime manualmente e execute o instalador novamente.';
end;

function InitializeSetup(): Boolean;
begin
  Result := True;
end;
