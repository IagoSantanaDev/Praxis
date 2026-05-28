<#
.SYNOPSIS
Build de release do Praxis: compila AutoHotkey para EXE, prepara staging sem fonte e gera instalador.

.DESCRIPTION
Este script reduz a exposição do código-fonte ao distribuir somente o executável compilado,
recursos necessários, documentos legais e manifesto de hashes. Isso NÃO é criptografia forte
nem impede engenharia reversa por atacante determinado; é uma camada técnica dentro de uma
estratégia maior com registro, contrato, assinatura, hashes e controle de distribuição.

Pré-requisitos para build completo:
- AutoHotkey v2 instalado.
- Ahk2Exe instalado ou use -InstallAhk2Exe para acionar o instalador oficial do AutoHotkey.
- Inno Setup 6 instalado para gerar o instalador, salvo se usar -SkipInstaller.

Exemplos:
  powershell -ExecutionPolicy Bypass -File .\tools\build-praxis.ps1 -Version 1.0.0
  powershell -ExecutionPolicy Bypass -File .\tools\build-praxis.ps1 -Version 1.0.0 -InstallAhk2Exe
  powershell -ExecutionPolicy Bypass -File .\tools\build-praxis.ps1 -Version 1.0.0 -SkipInstaller
  powershell -ExecutionPolicy Bypass -File .\tools\build-praxis.ps1 -Version 1.0.0 -CertificateThumbprint <THUMBPRINT> -RequireCodeSigning
  powershell -ExecutionPolicy Bypass -File .\tools\build-praxis.ps1 -Version 1.0.0 -CertificateThumbprint <THUMBPRINT> -Release
#>

[CmdletBinding()]
param(
    [ValidatePattern('^\d+\.\d+\.\d+([-.+][A-Za-z0-9.-]+)?$')]
    [string]$Version = '1.0.0',

    [string]$Ahk2ExePath,
    [string]$AutoHotkeyBasePath,
    [string]$InnoSetupPath,

    [switch]$InstallAhk2Exe,
    [switch]$SkipInstaller,
    [switch]$Compress,
    [switch]$Release,
    [switch]$AllowDirty,

    [string]$SignToolPath,
    [string]$CertificateThumbprint,
    [ValidateSet('CurrentUser','LocalMachine')]
    [string]$CertificateStoreLocation = 'CurrentUser',
    [string]$CertificateStoreName = 'My',
    [switch]$RequireCodeSigning,
    [string]$TimestampUrl = 'http://timestamp.digicert.com'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$MainScript = Join-Path $ProjectRoot 'main.ahk'
$InstallerScript = Join-Path $ProjectRoot 'installer\Praxis.iss'
$ImagesDir = Join-Path $ProjectRoot 'images'
$InstallerAssetsDir = Join-Path $ProjectRoot 'installer\assets'
$AppIconPath = Join-Path $InstallerAssetsDir 'icon.ico'
$WizardBannerPath = Join-Path $InstallerAssetsDir 'wizard-large.bmp'
$WizardSmallPath = Join-Path $InstallerAssetsDir 'wizard-small.bmp'
$DistRoot = Join-Path $ProjectRoot 'dist'
$ReleaseRoot = Join-Path $DistRoot "Praxis-$Version"
$StageDir = Join-Path $ReleaseRoot 'stage'
$InstallerOutDir = Join-Path $ReleaseRoot 'installer'
$ManifestPath = Join-Path $ReleaseRoot 'Praxis-build-manifest.json'
$IntegrityManifestSourcePath = Join-Path $ProjectRoot 'build\generated\Praxis_IntegrityManifest.ahk'
$ExePath = Join-Path $StageDir 'Praxis.exe'
$VersionInfoVersion = $null
$ResolvedSignToolPath = $null
$NormalizedCertificateThumbprint = $null
$CodeSigningEnabled = $false
$ReleaseMode = [bool]$Release
$EffectiveCompress = [bool]$Compress
$EffectiveRequireCodeSigning = [bool]$RequireCodeSigning
$SourceCommit = $null
$SourceDirty = $null

function Write-Step {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Resolve-FirstExistingPath {
    param([string[]]$Candidates)

    foreach ($candidate in $Candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
        $expanded = [Environment]::ExpandEnvironmentVariables($candidate)
        if (Test-Path -LiteralPath $expanded) {
            return (Resolve-Path -LiteralPath $expanded).Path
        }
    }

    return $null
}

function Resolve-CommandPath {
    param([string]$CommandName)

    $cmd = Get-Command $CommandName -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { return $cmd.Source }
    return $null
}

function Find-AutoHotkey64 {
    param([string]$ExplicitPath)

    $pathFromCommand = Resolve-CommandPath 'AutoHotkey64.exe'
    return Resolve-FirstExistingPath @(
        $ExplicitPath,
        $pathFromCommand,
        "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe",
        "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe",
        "${env:ProgramFiles(x86)}\AutoHotkey\v2\AutoHotkey64.exe"
    )
}

function Find-Ahk2Exe {
    param([string]$ExplicitPath)

    $pathFromCommand = Resolve-CommandPath 'Ahk2Exe.exe'
    return Resolve-FirstExistingPath @(
        $ExplicitPath,
        "$env:AHK2EXE",
        $pathFromCommand,
        "$env:LOCALAPPDATA\Programs\AutoHotkey\Compiler\Ahk2Exe.exe",
        "$env:ProgramFiles\AutoHotkey\Compiler\Ahk2Exe.exe",
        "${env:ProgramFiles(x86)}\AutoHotkey\Compiler\Ahk2Exe.exe"
    )
}

function Find-InnoSetupCompiler {
    param([string]$ExplicitPath)

    $pathFromCommand = Resolve-CommandPath 'ISCC.exe'
    return Resolve-FirstExistingPath @(
        $ExplicitPath,
        "$env:ISCC",
        $pathFromCommand,
        "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
    )
}

function Find-SignTool {
    param([string]$ExplicitPath)

    $pathFromCommand = Resolve-CommandPath 'signtool.exe'
    $directMatch = Resolve-FirstExistingPath @(
        $ExplicitPath,
        "$env:SIGNTOOL",
        $pathFromCommand
    )
    if ($directMatch) { return $directMatch }

    $kitRoots = @(
        "$env:ProgramFiles\Windows Kits\10\bin",
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin",
        "$env:ProgramFiles\Windows Kits\11\bin",
        "${env:ProgramFiles(x86)}\Windows Kits\11\bin"
    )

    foreach ($root in $kitRoots) {
        if ([string]::IsNullOrWhiteSpace($root) -or !(Test-Path -LiteralPath $root)) { continue }
        $candidate = Get-ChildItem -LiteralPath $root -Filter 'signtool.exe' -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match '\\x64\\signtool\.exe$' } |
            Sort-Object FullName -Descending |
            Select-Object -First 1
        if ($candidate) { return $candidate.FullName }
    }

    return $null
}

function Normalize-CertificateThumbprint {
    param([string]$Thumbprint)

    if ([string]::IsNullOrWhiteSpace($Thumbprint)) { return $null }
    return ($Thumbprint -replace '[^0-9a-fA-F]', '').ToUpperInvariant()
}

function Get-CodeSigningCertificate {
    param(
        [string]$Thumbprint,
        [string]$StoreLocation,
        [string]$StoreName
    )

    $normalized = Normalize-CertificateThumbprint -Thumbprint $Thumbprint
    if ([string]::IsNullOrWhiteSpace($normalized)) { return $null }

    $certPath = "Cert:\$StoreLocation\$StoreName\$normalized"
    if (!(Test-Path -LiteralPath $certPath)) {
        throw "Certificado de assinatura não encontrado em ${StoreLocation}\\${StoreName}: $normalized"
    }

    $cert = Get-Item -LiteralPath $certPath
    if (!$cert.HasPrivateKey) {
        throw "O certificado $normalized existe, mas não tem chave privada disponível para assinatura."
    }
    if ($cert.NotAfter -lt (Get-Date)) {
        throw "O certificado $normalized expirou em $($cert.NotAfter.ToString('yyyy-MM-dd'))."
    }

    $codeSigningEku = $cert.EnhancedKeyUsageList | Where-Object { $_.ObjectId -eq '1.3.6.1.5.5.7.3.3' }
    if (!$codeSigningEku) {
        Write-Warning "O certificado $normalized não declara EKU Code Signing (1.3.6.1.5.5.7.3.3). O SignTool pode rejeitar a assinatura."
    }

    return $cert
}

function Get-NativeExitCode {
    if (Test-Path -LiteralPath 'variable:global:LASTEXITCODE') { return $global:LASTEXITCODE }
    return 0
}

function Assert-NativeCommandSucceeded {
    param([string]$FailureMessage)

    $exitCode = Get-NativeExitCode
    if ($exitCode -ne 0) { throw "$FailureMessage Exit code: $exitCode" }
}

function Convert-ToWindowsVersionInfoVersion {
    param([string]$SemanticVersion)

    if ([string]::IsNullOrWhiteSpace($SemanticVersion)) {
        return '1.0.0.0'
    }

    $coreVersion = ($SemanticVersion -split '[-+]')[0]
    $parts = @($coreVersion -split '\.')
    while ($parts.Count -lt 4) { $parts += '0' }
    if ($parts.Count -gt 4) { $parts = $parts[0..3] }

    $normalizedParts = foreach ($part in $parts) {
        if ($part -notmatch '^\d+$') { '0' } else { [int]$part }
    }

    return ($normalizedParts -join '.')
}

function Get-GitBuildState {
    param([string]$RepositoryRoot)

    $state = [ordered]@{
        Commit = $null
        Dirty = $null
        StatusLines = @()
    }

    try {
        $commit = (& git -C $RepositoryRoot rev-parse --short HEAD 2>$null)
        if ((Get-NativeExitCode) -eq 0) {
            $state.Commit = [string]$commit
        }

        $status = @(& git -C $RepositoryRoot status --porcelain 2>$null)
        if ((Get-NativeExitCode) -eq 0) {
            $state.StatusLines = $status
            $state.Dirty = $status.Count -gt 0
        }
    } catch {
        $state.Dirty = $null
    }

    return $state
}

function Wait-ForFile {
    param(
        [string]$Path,
        [int]$TimeoutSeconds = 15
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-Path -LiteralPath $Path) { return }
        Start-Sleep -Milliseconds 250
    }

    throw "Arquivo não foi gerado dentro de ${TimeoutSeconds}s: $Path"
}

function Invoke-SignFile {
    param([string]$Path)

    if (!$CodeSigningEnabled) {
        return
    }

    Write-Step "Assinando $([IO.Path]::GetFileName($Path))"

    if (![string]::IsNullOrWhiteSpace($ResolvedSignToolPath) -and (Test-Path -LiteralPath $ResolvedSignToolPath)) {
        $signArgs = @(
            'sign',
            '/fd', 'SHA256',
            '/tr', $TimestampUrl,
            '/td', 'SHA256',
            '/sha1', $NormalizedCertificateThumbprint,
            '/s', $CertificateStoreName
        )
        if ($CertificateStoreLocation -eq 'LocalMachine') {
            $signArgs += '/sm'
        }
        $signArgs += $Path

        & $ResolvedSignToolPath @signArgs
        Assert-NativeCommandSucceeded "Falha ao assinar: $Path"
    } else {
        $cert = Get-CodeSigningCertificate -Thumbprint $NormalizedCertificateThumbprint -StoreLocation $CertificateStoreLocation -StoreName $CertificateStoreName
        $signatureResult = Set-AuthenticodeSignature -FilePath $Path -Certificate $cert -HashAlgorithm SHA256 -TimestampServer $TimestampUrl
        if ($signatureResult.Status -ne 'Valid') {
            throw "Falha ao assinar com Set-AuthenticodeSignature: $($signatureResult.Status) - $($signatureResult.StatusMessage)"
        }
    }

    $signature = Get-AuthenticodeSignature -LiteralPath $Path
    if ($signature.Status -ne 'Valid') {
        throw "Assinatura aplicada, mas a validação Authenticode retornou $($signature.Status): $($signature.StatusMessage)"
    }
}

function Get-PortableRelativePath {
    param(
        [string]$BasePath,
        [string]$TargetPath
    )

    $baseFull = [IO.Path]::GetFullPath($BasePath)
    if (!$baseFull.EndsWith([IO.Path]::DirectorySeparatorChar)) {
        $baseFull += [IO.Path]::DirectorySeparatorChar
    }

    $targetFull = [IO.Path]::GetFullPath($TargetPath)
    $baseUri = [Uri]$baseFull
    $targetUri = [Uri]$targetFull
    return [Uri]::UnescapeDataString($baseUri.MakeRelativeUri($targetUri).ToString()).Replace('/', [IO.Path]::DirectorySeparatorChar)
}

function New-HashManifest {
    param([string]$RootPath, [string]$OutputPath, [hashtable]$Metadata)

    $files = Get-ChildItem -LiteralPath $RootPath -File -Recurse |
        Sort-Object FullName |
        ForEach-Object {
            $relative = (Get-PortableRelativePath -BasePath $RootPath -TargetPath $_.FullName).Replace('\', '/')
            $hash = Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256
            [ordered]@{
                path = $relative
                sha256 = $hash.Hash.ToLowerInvariant()
                bytes = $_.Length
            }
        }

    $manifest = [ordered]@{
        product = 'Praxis'
        version = $Metadata.Version
        builtAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        sourceCommit = $Metadata.SourceCommit
        sourceDirty = $Metadata.SourceDirty
        releaseMode = $Metadata.ReleaseMode
        allowDirty = $Metadata.AllowDirty
        compress = $Metadata.Compress
        codeSigning = $Metadata.CodeSigning
        protectionNotice = 'Build compilado e empacotado sem arquivos .ahk. Assinatura, compressão, DPAPI e manifesto elevam o custo de adulteração/inspeção casual, mas não são criptografia forte contra engenharia reversa profissional.'
        files = @($files)
    }

    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
}

function New-AhkIntegrityManifest {
    param(
        [string]$RepositoryRoot,
        [string]$OutputPath,
        [string]$UiDir,
        [string]$ImagesDir,
        [string]$WebView2LoaderPath
    )

    $protectedFiles = @()
    if (Test-Path -LiteralPath $UiDir) {
        $protectedFiles += Get-ChildItem -LiteralPath $UiDir -File -Recurse
    }
    if (Test-Path -LiteralPath $ImagesDir) {
        $protectedFiles += Get-ChildItem -LiteralPath $ImagesDir -File -Recurse
    }
    if (Test-Path -LiteralPath $WebView2LoaderPath) {
        $protectedFiles += Get-Item -LiteralPath $WebView2LoaderPath
    }

    $entries = $protectedFiles |
        Sort-Object FullName |
        ForEach-Object {
            $relative = (Get-PortableRelativePath -BasePath $RepositoryRoot -TargetPath $_.FullName).Replace('\', '/')
            $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            [ordered]@{
                path = $relative
                sha256 = $hash
            }
        }

    if (!$entries -or $entries.Count -eq 0) {
        throw 'Nenhum recurso externo foi encontrado para gerar o manifesto de integridade embutido.'
    }

    $lines = @(
        '; Gerado automaticamente por tools/build-praxis.ps1.',
        '; Não edite manualmente. Este arquivo é embutido no Praxis.exe pelo Ahk2Exe.',
        'gIntegrityExpectedFiles := Map('
    )

    for ($i = 0; $i -lt $entries.Count; $i++) {
        $entry = $entries[$i]
        $suffix = if ($i -lt ($entries.Count - 1)) { ',' } else { '' }
        $lines += "    `"$($entry.path)`", `"$($entry.sha256)`"$suffix"
    }
    $lines += ')'

    $outputDir = Split-Path -Parent $OutputPath
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    Set-Content -LiteralPath $OutputPath -Value ($lines -join [Environment]::NewLine) -Encoding UTF8
}

Write-Step 'Validando arquivos do projeto'
$VersionInfoVersion = Convert-ToWindowsVersionInfoVersion -SemanticVersion $Version
foreach ($required in @(
    $MainScript,
    (Join-Path $ProjectRoot 'ui\index.html'),
    $ImagesDir,
    (Join-Path $ProjectRoot 'lib\64bit\WebView2Loader.dll'),
    (Join-Path $ProjectRoot 'LICENSE'),
    $AppIconPath
)) {
    if (!(Test-Path -LiteralPath $required)) { throw "Arquivo obrigatório não encontrado: $required" }
}

if (!$SkipInstaller) {
    foreach ($installerAsset in @($AppIconPath, $WizardBannerPath, $WizardSmallPath)) {
        if (!(Test-Path -LiteralPath $installerAsset)) { throw "Asset visual obrigatório do instalador não encontrado: $installerAsset" }
    }
}

if ($ReleaseMode) {
    if ($SkipInstaller) {
        throw 'Release endurecido não permite -SkipInstaller. Gere e valide o instalador.'
    }
    $EffectiveCompress = $true
    $EffectiveRequireCodeSigning = $true
    Write-Step 'Modo release endurecido habilitado: assinatura, compressão, instalador e Git limpo obrigatórios'
}

$gitState = Get-GitBuildState -RepositoryRoot $ProjectRoot
$SourceCommit = $gitState['Commit']
$SourceDirty = $gitState['Dirty']
if ($ReleaseMode -and $SourceDirty -eq $null) {
    throw 'Release endurecido requer repositório Git legível para registrar commit e estado da árvore.'
}
if ($ReleaseMode -and $SourceDirty -and !$AllowDirty) {
    $dirtyPreview = ($gitState['StatusLines'] | Select-Object -First 20) -join [Environment]::NewLine
    throw "Release endurecido bloqueado: working tree sujo. Commit/stash antes de gerar release ou use -AllowDirty para registrar exceção explícita.$([Environment]::NewLine)$dirtyPreview"
}
if ($SourceDirty) {
    Write-Warning 'Working tree sujo. O manifesto registrará sourceDirty=true.'
}

$AutoHotkey64 = Find-AutoHotkey64 -ExplicitPath $AutoHotkeyBasePath
if (!$AutoHotkey64) {
    throw 'AutoHotkey64.exe não encontrado. Instale AutoHotkey v2 ou informe -AutoHotkeyBasePath.'
}

$Ahk2Exe = Find-Ahk2Exe -ExplicitPath $Ahk2ExePath
if (!$Ahk2Exe -and $InstallAhk2Exe) {
    $Ahk2ExeInstaller = Join-Path (Split-Path (Split-Path $AutoHotkey64 -Parent) -Parent) 'UX\install-ahk2exe.ahk'
    if (!(Test-Path -LiteralPath $Ahk2ExeInstaller)) {
        throw "Instalador oficial do Ahk2Exe não encontrado: $Ahk2ExeInstaller"
    }

    Write-Step 'Instalando Ahk2Exe pelo instalador oficial do AutoHotkey'
    & $AutoHotkey64 $Ahk2ExeInstaller /Y
    Assert-NativeCommandSucceeded 'Falha ao instalar Ahk2Exe.'
    $Ahk2Exe = Find-Ahk2Exe -ExplicitPath $Ahk2ExePath
}

if (!$Ahk2Exe) {
    throw 'Ahk2Exe.exe não encontrado. Execute novamente com -InstallAhk2Exe ou informe -Ahk2ExePath.'
}

$InnoSetup = $null
if (!$SkipInstaller) {
    $InnoSetup = Find-InnoSetupCompiler -ExplicitPath $InnoSetupPath
    if (!$InnoSetup) {
        throw 'ISCC.exe não encontrado. Instale Inno Setup 6, informe -InnoSetupPath ou use -SkipInstaller.'
    }
    if (!(Test-Path -LiteralPath $InstallerScript)) {
        throw "Script do instalador não encontrado: $InstallerScript"
    }
}

$NormalizedCertificateThumbprint = Normalize-CertificateThumbprint -Thumbprint $CertificateThumbprint
if ($EffectiveRequireCodeSigning -and [string]::IsNullOrWhiteSpace($NormalizedCertificateThumbprint)) {
    throw 'Assinatura digital obrigatória: informe -CertificateThumbprint com o thumbprint do certificado de code signing.'
}

if (![string]::IsNullOrWhiteSpace($NormalizedCertificateThumbprint)) {
    $ResolvedSignToolPath = Find-SignTool -ExplicitPath $SignToolPath
    if (!$ResolvedSignToolPath) {
        Write-Warning 'SignTool não encontrado. O build usará Set-AuthenticodeSignature como fallback local.'
    }

    $cert = Get-CodeSigningCertificate -Thumbprint $NormalizedCertificateThumbprint -StoreLocation $CertificateStoreLocation -StoreName $CertificateStoreName
    $CodeSigningEnabled = $true
    Write-Step "Assinatura digital habilitada: $($cert.Subject) [$CertificateStoreLocation\\$CertificateStoreName]"
} elseif ($EffectiveRequireCodeSigning) {
    throw 'Assinatura digital obrigatória, mas nenhum certificado foi configurado.'
} else {
    Write-Warning 'Assinatura digital desabilitada. Use -CertificateThumbprint ou -RequireCodeSigning para bloquear releases sem assinatura.'
}

Write-Step 'Limpando saída anterior'
if (Test-Path -LiteralPath $ReleaseRoot) {
    Remove-Item -LiteralPath $ReleaseRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $StageDir, $InstallerOutDir | Out-Null

Write-Step 'Compilando AutoHotkey para EXE'
Write-Step 'Gerando manifesto de integridade embutido no EXE'
New-AhkIntegrityManifest -RepositoryRoot $ProjectRoot -OutputPath $IntegrityManifestSourcePath -UiDir (Join-Path $ProjectRoot 'ui') -ImagesDir $ImagesDir -WebView2LoaderPath (Join-Path $ProjectRoot 'lib\64bit\WebView2Loader.dll')

$compileArgs = @('/in', $MainScript, '/out', $ExePath, '/base', $AutoHotkey64)
if (Test-Path -LiteralPath $AppIconPath) {
    $compileArgs += @('/icon', $AppIconPath)
}
if ($EffectiveCompress) {
    # Compressão dificulta inspeção casual, mas não é criptografia.
    $compileArgs += @('/compress', '2')
}
& $Ahk2Exe @compileArgs
Assert-NativeCommandSucceeded 'Falha na compilação Ahk2Exe.'
Wait-ForFile -Path $ExePath

Invoke-SignFile -Path $ExePath

Write-Step 'Copiando recursos distribuíveis sem código-fonte AHK'
Copy-Item -LiteralPath (Join-Path $ProjectRoot 'ui') -Destination (Join-Path $StageDir 'ui') -Recurse
Copy-Item -LiteralPath $ImagesDir -Destination (Join-Path $StageDir 'images') -Recurse
New-Item -ItemType Directory -Path (Join-Path $StageDir 'lib\64bit') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $ProjectRoot 'lib\64bit\WebView2Loader.dll') -Destination (Join-Path $StageDir 'lib\64bit\WebView2Loader.dll')
foreach ($legalFile in @('LICENSE','COPYRIGHT','NOTICE.md','EULA.md','NDA.md','PRIVACY_LGPD.md','THIRD_PARTY_NOTICES.md','README.md')) {
    $source = Join-Path $ProjectRoot $legalFile
    if (Test-Path -LiteralPath $source) {
        Copy-Item -LiteralPath $source -Destination (Join-Path $StageDir $legalFile)
    }
}

$leakedSources = Get-ChildItem -LiteralPath $StageDir -File -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -in @('.ahk', '.ps1', '.iss') }
if ($leakedSources) {
    $leakedList = ($leakedSources | ForEach-Object { $_.FullName }) -join [Environment]::NewLine
    throw "O staging contém arquivos de fonte/script que não devem ser distribuídos:$([Environment]::NewLine)$leakedList"
}

$codeSigningMetadata = [ordered]@{
    enabled = $CodeSigningEnabled
    required = $EffectiveRequireCodeSigning
    certificateThumbprint = if ($CodeSigningEnabled) { $NormalizedCertificateThumbprint } else { $null }
    certificateStore = if ($CodeSigningEnabled) { "$CertificateStoreLocation\\$CertificateStoreName" } else { $null }
    signTool = if ($CodeSigningEnabled -and $ResolvedSignToolPath) { $ResolvedSignToolPath } else { $null }
    signingMethod = if ($CodeSigningEnabled -and $ResolvedSignToolPath) { 'signtool' } elseif ($CodeSigningEnabled) { 'Set-AuthenticodeSignature' } else { $null }
    timestampUrl = if ($CodeSigningEnabled) { $TimestampUrl } else { $null }
}

Write-Step 'Gerando manifesto de hashes do pacote'
New-HashManifest -RootPath $StageDir -OutputPath $ManifestPath -Metadata @{
    Version = $Version
    SourceCommit = $SourceCommit
    SourceDirty = $SourceDirty
    ReleaseMode = $ReleaseMode
    AllowDirty = [bool]$AllowDirty
    Compress = $EffectiveCompress
    CodeSigning = $codeSigningMetadata
}
Copy-Item -LiteralPath $ManifestPath -Destination (Join-Path $StageDir 'Praxis-build-manifest.json')

if (!$SkipInstaller) {
    Write-Step 'Gerando instalador Inno Setup'
    & $InnoSetup "/DAppVersion=$Version" "/DAppVersionInfoVersion=$VersionInfoVersion" "/DSourceDir=$StageDir" "/DOutputDir=$InstallerOutDir" "/DAssetsDir=$InstallerAssetsDir" $InstallerScript
    Assert-NativeCommandSucceeded 'Falha ao gerar instalador Inno Setup.'

    $setupPath = Join-Path $InstallerOutDir "Praxis-Setup-$Version.exe"
    Wait-ForFile -Path $setupPath
    Invoke-SignFile -Path $setupPath

    Write-Step 'Atualizando manifesto com hash do instalador'
    $installerHash = Get-FileHash -LiteralPath $setupPath -Algorithm SHA256
    $installerManifest = [ordered]@{
        product = 'Praxis'
        version = $Version
        builtAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        codeSigning = $codeSigningMetadata
        sourceCommit = $SourceCommit
        sourceDirty = $SourceDirty
        releaseMode = $ReleaseMode
        allowDirty = [bool]$AllowDirty
        compress = $EffectiveCompress
        installer = [ordered]@{
            path = (Get-PortableRelativePath -BasePath $ReleaseRoot -TargetPath $setupPath).Replace('\', '/')
            sha256 = $installerHash.Hash.ToLowerInvariant()
            bytes = (Get-Item -LiteralPath $setupPath).Length
        }
        stageManifest = (Get-PortableRelativePath -BasePath $ReleaseRoot -TargetPath $ManifestPath).Replace('\', '/')
    }
    $installerManifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $ReleaseRoot 'Praxis-installer-manifest.json') -Encoding UTF8
}

Write-Step 'Build concluído'
Write-Host "Release: $ReleaseRoot" -ForegroundColor Green
Write-Host "Executável: $ExePath" -ForegroundColor Green
if (!$SkipInstaller) {
    Write-Host "Instalador: $(Join-Path $InstallerOutDir "Praxis-Setup-$Version.exe")" -ForegroundColor Green
}
