<#
.SYNOPSIS
Build portátil do Praxis: compila AutoHotkey para EXE e gera ZIP pronto para uso.

.DESCRIPTION
Este script reduz a exposição do código-fonte ao distribuir somente o executável compilado,
recursos necessários, documentos legais e manifesto de hashes. Isso NÃO é criptografia forte
nem impede engenharia reversa por atacante determinado; é uma camada técnica dentro de uma
estratégia maior com registro, contrato, assinatura, hashes e controle de distribuição.

Pré-requisitos para build:
- AutoHotkey v2 instalado.
- Ahk2Exe disponível no ambiente de build ou informado por parâmetro.

Exemplos:
  powershell -ExecutionPolicy Bypass -File .\tools\build-praxis.ps1 -Version 1.0.0
  powershell -ExecutionPolicy Bypass -File .\tools\build-praxis.ps1 -Version 1.0.0 -CertificateThumbprint <THUMBPRINT> -RequireCodeSigning
  powershell -ExecutionPolicy Bypass -File .\tools\build-praxis.ps1 -Version 1.0.0 -CertificateThumbprint <THUMBPRINT> -Release
#>

[CmdletBinding()]
param(
    [ValidatePattern('^\d+\.\d+\.\d+([-.+][A-Za-z0-9.-]+)?$')]
    [string]$Version = '1.0.0',

    [string]$Ahk2ExePath,
    [string]$AutoHotkeyBasePath,
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
$ImagesDir = Join-Path $ProjectRoot 'images'
$UiDir = Join-Path $ProjectRoot 'lib\ui'
$UiIndexPath = Join-Path $UiDir 'index.html'
$OcrReferencesPath = Join-Path $ProjectRoot 'lib\globals\mv\FFCV_ErrorReferences.json'
$OcrProbePath = Join-Path $ProjectRoot 'tools\ocr-probe.ps1'
$AssetsDir = Join-Path $ProjectRoot 'assets'
$AppIconPath = Join-Path $AssetsDir 'icon.ico'
$DistRoot = Join-Path $ProjectRoot 'dist'
$ReleaseRoot = Join-Path $DistRoot "Praxis-$Version"
$StageDir = Join-Path $ReleaseRoot 'stage'
$DistributionOutDir = Join-Path $ReleaseRoot 'distribution'
$ManifestPath = Join-Path $ReleaseRoot 'Praxis-build-manifest.json'
$GeneratedDir = Join-Path $ProjectRoot 'build\generated'
$GeneratedUiPath = Join-Path $GeneratedDir 'Praxis_Ui.ahk'
$GeneratedOcrReferencesPath = Join-Path $GeneratedDir 'Praxis_OcrReferences.ahk'
$GeneratedOcrProbePath = Join-Path $GeneratedDir 'Praxis_OcrProbe.ahk'
$IntegrityManifestSourcePath = Join-Path $GeneratedDir 'Praxis_IntegrityManifest.ahk'
$ExePath = Join-Path $StageDir 'Praxis.exe'
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

function ConvertTo-Base64Utf8 {
    param([string]$Text)

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    return [Convert]::ToBase64String($bytes)
}

function New-EmbeddedBase64Module {
    param(
        [string]$OutputPath,
        [string]$VariableName,
        [string]$Text
    )

    $encoded = ConvertTo-Base64Utf8 -Text $Text
    $chunkSize = 8000
    $lines = @(
        '; Gerado automaticamente por tools/build-praxis.ps1.',
        '; Não edite manualmente.',
        "$VariableName := `"`""
    )

    for ($offset = 0; $offset -lt $encoded.Length; $offset += $chunkSize) {
        $length = [Math]::Min($chunkSize, $encoded.Length - $offset)
        $chunk = $encoded.Substring($offset, $length)
        $lines += "$VariableName .= `"$chunk`""
    }

    $outputDir = Split-Path -Parent $OutputPath
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    Set-Content -LiteralPath $OutputPath -Value ($lines -join [Environment]::NewLine) -Encoding UTF8
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
        protectionNotice = 'Build compilado e empacotado sem arquivos .ahk. Assinatura, compressão e manifesto elevam o custo de adulteração/inspeção casual, mas não são criptografia forte contra engenharia reversa profissional.'
        files = @($files)
    }

    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
}

function Restore-WebView2Loader {
    param(
        [string]$ProjectRoot,
        [string]$Vendor64Path,
        [string]$Vendor32Path
    )

    # O pacote portátil precisa das duas arquiteturas; só reutilize o cache
    # quando ambas as DLLs já estiverem presentes.
    if ((Test-Path -LiteralPath $Vendor64Path) -and (Test-Path -LiteralPath $Vendor32Path)) {
        return
    }

    Write-Host "   [nuget] WebView2Loader.dll nao encontrado em vendor — restaurando Microsoft.Web.WebView2..." -ForegroundColor DarkGray

    $pkgName = 'Microsoft.Web.WebView2'
    $pkgVersion = '1.0.2535.41'
    $tempDir = Join-Path ([IO.Path]::GetTempPath()) ('praxis-wv2-' + [Guid]::NewGuid().ToString('N'))
    $nupkgPath = Join-Path $tempDir "$pkgName.$pkgVersion.nupkg"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    try {
        $nupkgUrl = "https://api.nuget.org/v3-flatcontainer/$($pkgName.ToLowerInvariant())/$pkgVersion/$($pkgName.ToLowerInvariant()).$pkgVersion.nupkg"
        Write-Host "   [nuget] Baixando $nupkgUrl" -ForegroundColor DarkGray

        # Usa curl.exe diretamente (funciona no ambiente bash onde powershell-invoke-webrequest pode falhar)
        $curlExe = Get-Command curl.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
        if ($curlExe) {
            $null = & $curlExe -sL --max-time 30 -o $nupkgPath $nupkgUrl 2>&1
            if ((Test-Path -LiteralPath $nupkgPath) -and ((Get-Item $nupkgPath).Length -lt 1024)) {
                Remove-Item -LiteralPath $nupkgPath -Force -ErrorAction SilentlyContinue
                Write-Warning "Download do NuGet package retornou arquivo muito pequeno — possivelmente bloqueado"
                return
            }
        } else {
            try {
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                Invoke-WebRequest -Uri $nupkgUrl -OutFile $nupkgPath -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
            } catch {
                Write-Warning "Falha ao baixar NuGet package: $_"
                return
            }
        }

        if (!(Test-Path -LiteralPath $nupkgPath)) {
            Write-Warning "Download nao gerou arquivo"
            return
        }

        # Extrair o .nupkg (ZIP com estrutura inside)
        $extractDir = Join-Path $tempDir 'extracted'
        try {
            Expand-Archive -LiteralPath $nupkgPath -DestinationPath $extractDir -Force -ErrorAction Stop
        } catch {
            Write-Warning "Falha ao extrair NuGet package: $_"
            return
        }

        # Localizar WebView2Loader.dll: preferir runtimes\win-x64\ sobre runtimes\win-x86\
        $allDlls = @(Get-ChildItem -LiteralPath $extractDir -Filter 'WebView2Loader.dll' -Recurse -ErrorAction SilentlyContinue)
        if ($allDlls.Count -eq 0) {
            Write-Warning "WebView2Loader.dll nao encontrado no pacote extraido"
            return
        }

        $chosen64 = $allDlls | Where-Object { $_.FullName -match '[\\/]runtimes[\\/]win-x64[\\/]' } | Select-Object -First 1
        $chosen32 = $allDlls | Where-Object { $_.FullName -match '[\\/]runtimes[\\/]win-x86[\\/]' } | Select-Object -First 1
        if (!$chosen64 -or !$chosen32) {
            throw "O pacote WebView2 nao contem loaders win-x64 e win-x86 simultaneamente."
        }

        $dest64 = Split-Path -Parent $Vendor64Path
        $dest32 = Split-Path -Parent $Vendor32Path
        New-Item -ItemType Directory -Path $dest64, $dest32 -Force | Out-Null
        Copy-Item -LiteralPath $chosen64.FullName -Destination $Vendor64Path -Force
        Copy-Item -LiteralPath $chosen32.FullName -Destination $Vendor32Path -Force
        Write-Host "   [nuget] Loaders WebView2 x64/x86 restaurados" -ForegroundColor DarkGray

    } finally {
        if (Test-Path -LiteralPath $tempDir) {
            Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function New-AhkIntegrityManifest {
    param(
        [string]$OutputPath,
        [object[]]$Files
    )

    # $Files: hashtable com { relative; path } — relative é o caminho relativo
    # ao A_ScriptDir do EXE distribuído (o stage/instalação). Entram apenas
    # recursos externos que de fato são copiados para o pacote (WebView2Loader
    # e documentos legais). Os fontes AHK/HTML/JSON são embutidos no EXE na
    # compilação e não têm caminho em disco no pacote para validar.
    $allFiles = @()
    foreach ($entry in $Files) {
        if (!(Test-Path -LiteralPath $entry.path)) {
            throw "Arquivo do manifesto de integridade não encontrado: $($entry.path)"
        }
        $h = (Get-FileHash -LiteralPath $entry.path -Algorithm SHA256).Hash.ToLowerInvariant()
        $allFiles += [ordered]@{ relative = $entry.relative; hash = $h }
    }

    # Emitir manifesto AHK: Map de path->SHA256 e variaveis indexadas FileSHA256_<index>
    $lines = @(
        '; Gerado automaticamente por tools/build-praxis.ps1.',
        '; Não edite manualmente. Este arquivo é embutido no Praxis.exe pelo Ahk2Exe.',
        'global gIntegrityExpectedFiles'
    )

    for ($i = 0; $i -lt $allFiles.Count; $i++) {
        $f = $allFiles[$i]
        # Variavel indexada: global FileSHA256_0 := "<hash>"
        $lines += "global FileSHA256_$i := `"$($f.hash)`""
    }

    $lines += ''
    $lines += 'gIntegrityExpectedFiles := Map('

    for ($i = 0; $i -lt $allFiles.Count; $i++) {
        $f = $allFiles[$i]
        $lines += "    `"$($f.relative)`", `"$($f.hash)`","
    }

    $lines += "    'fileCount', " + $allFiles.Count + ","
    $lines += "    'manifestVersion', '1'"
    $lines += ')'

    $outputDir = Split-Path -Parent $OutputPath
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    Set-Content -LiteralPath $OutputPath -Value ($lines -join [Environment]::NewLine) -Encoding UTF8
}

Write-Step 'Restaurando WebView2Loader.dll se necessario'
$Vendor64Dll = Join-Path $ProjectRoot 'lib\vendor\64bit\WebView2Loader.dll'
$Vendor32Dll = Join-Path $ProjectRoot 'lib\vendor\32bit\WebView2Loader.dll'
if (!(Test-Path -LiteralPath $Vendor64Dll) -or !(Test-Path -LiteralPath $Vendor32Dll)) {
    Restore-WebView2Loader -ProjectRoot $ProjectRoot -Vendor64Path $Vendor64Dll -Vendor32Path $Vendor32Dll
}

Write-Step 'Validando arquivos do projeto'
Write-Step 'Validando chamadas top-level em lib/'
$TopLevelCallsScript = Join-Path $PSScriptRoot 'find-top-level-calls.ps1'
if (Test-Path -LiteralPath $TopLevelCallsScript) {
    $PowerShellExe = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source
    if (-not $PowerShellExe) {
        Write-Warning "powershell.exe nao encontrado no PATH; sanity check ignorado."
    } else {
        & $PowerShellExe -NoProfile -ExecutionPolicy Bypass -File $TopLevelCallsScript -Root (Join-Path $ProjectRoot 'lib') -FailOnFindings
        Assert-NativeCommandSucceeded 'Encontradas chamadas top-level bare em lib/; corrija antes de compilar.'
    }
} else {
    Write-Warning "tools/find-top-level-calls.ps1 nao encontrado; sanity check ignorado."
}

Write-Step 'Validando atribuicoes implicitas a globais em lib/'
$ImplicitLocalsScript = Join-Path $PSScriptRoot 'find-implicit-locals.ps1'
if (Test-Path -LiteralPath $ImplicitLocalsScript) {
    $PowerShellExe = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source
    if (-not $PowerShellExe) {
        Write-Warning "powershell.exe nao encontrado no PATH; sanity check ignorado."
    } else {
        & $PowerShellExe -NoProfile -ExecutionPolicy Bypass -File $ImplicitLocalsScript -Root (Join-Path $ProjectRoot 'lib') -FailOnFindings
        Assert-NativeCommandSucceeded 'Encontradas atribuicoes implicitas a globais em lib/; corrija antes de compilar.'
    }
} else {
    Write-Warning "tools/find-implicit-locals.ps1 nao encontrado; sanity check ignorado."
}

# WebView2Loader.dll: o pacote deve conter x64 e x86. O runtime
# escolhe a pasta correta via A_PtrSize em App.ahk.
$ResolvedWebView2Dll64 = $Vendor64Dll
$ResolvedWebView2Dll32 = $Vendor32Dll
foreach ($requiredLoader in @($ResolvedWebView2Dll64, $ResolvedWebView2Dll32)) {
    if (!(Test-Path -LiteralPath $requiredLoader)) {
        throw "WebView2Loader.dll nao encontrado: $requiredLoader"
    }
}

foreach ($required in @(
    $MainScript,
    $UiIndexPath,
    $OcrReferencesPath,
    $OcrProbePath,
    $ResolvedWebView2Dll64,
    $ResolvedWebView2Dll32,
    (Join-Path $ProjectRoot 'LICENSE'),
    (Join-Path $ProjectRoot 'COPYRIGHT'),
    (Join-Path $ProjectRoot 'NOTICE.md'),
    $AppIconPath
)) {
    if (!(Test-Path -LiteralPath $required)) { throw "Arquivo obrigatório não encontrado: $required" }
}

if ($ReleaseMode) {
    $EffectiveCompress = $true
    $EffectiveRequireCodeSigning = $true
    Write-Step 'Modo release endurecido habilitado: assinatura, compressão e Git limpo obrigatórios'
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
if (!$Ahk2Exe) {
    throw 'Ahk2Exe.exe não encontrado. Instale a ferramenta de build separadamente ou informe -Ahk2ExePath.'
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
New-Item -ItemType Directory -Path $StageDir | Out-Null

Write-Step 'Gerando artefatos embutidos do EXE'
if (Test-Path -LiteralPath $GeneratedDir) {
    Remove-Item -LiteralPath $GeneratedDir -Recurse -Force
}
$uiText = Get-Content -LiteralPath $UiIndexPath -Raw -Encoding UTF8
if (Test-Path -LiteralPath $AppIconPath) {
    $iconBytes = [System.IO.File]::ReadAllBytes($AppIconPath)
    $iconDataUri = 'data:image/x-icon;base64,' + [Convert]::ToBase64String($iconBytes)
    $uiText = $uiText.Replace('../../assets/icon.ico', $iconDataUri)
}
New-EmbeddedBase64Module -OutputPath $GeneratedUiPath -VariableName 'gEmbeddedIndexHtmlBase64' -Text $uiText
New-EmbeddedBase64Module -OutputPath $GeneratedOcrReferencesPath -VariableName 'gEmbeddedOcrReferencesBase64' -Text (Get-Content -LiteralPath $OcrReferencesPath -Raw -Encoding UTF8)
New-EmbeddedBase64Module -OutputPath $GeneratedOcrProbePath -VariableName 'gEmbeddedOcrProbeBase64' -Text (Get-Content -LiteralPath $OcrProbePath -Raw -Encoding UTF8)
# Manifesto de integridade: apenas recursos EXTERNOS copiados para o stage
# (WebView2Loader + documentos legais presentes). A UI, imagens e dicionário
# OCR são embutidos no EXE e não têm caminho em disco no pacote.
$integrityFiles = @()
foreach ($loaderPath in @($ResolvedWebView2Dll64, $ResolvedWebView2Dll32)) {
    $integrityFiles += [ordered]@{
        relative = (Get-PortableRelativePath -BasePath $ProjectRoot -TargetPath $loaderPath).Replace('\', '/')
        path     = $loaderPath
    }
}
foreach ($legalDoc in @('LICENSE', 'COPYRIGHT', 'NOTICE.md')) {
    $docPath = Join-Path $ProjectRoot $legalDoc
    if (Test-Path -LiteralPath $docPath) {
        $integrityFiles += [ordered]@{ relative = $legalDoc; path = $docPath }
    }
}
New-AhkIntegrityManifest -OutputPath $IntegrityManifestSourcePath -Files $integrityFiles

Write-Step 'Compilando AutoHotkey para EXE'

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
foreach ($loaderPath in @($ResolvedWebView2Dll64, $ResolvedWebView2Dll32)) {
    $relativeLoaderDir = [System.IO.Path]::GetDirectoryName($loaderPath).Replace($ProjectRoot, '').TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $stageLoaderDir = Join-Path $StageDir $relativeLoaderDir
    New-Item -ItemType Directory -Path $stageLoaderDir -Force | Out-Null
    Copy-Item -LiteralPath $loaderPath -Destination (Join-Path $stageLoaderDir ([System.IO.Path]::GetFileName($loaderPath)))
}
foreach ($legalSource in @(
    (Join-Path $ProjectRoot 'LICENSE'),
    (Join-Path $ProjectRoot 'COPYRIGHT'),
    (Join-Path $ProjectRoot 'NOTICE.md')
)) {
    if (Test-Path -LiteralPath $legalSource) {
        Copy-Item -LiteralPath $legalSource -Destination (Join-Path $StageDir (Split-Path $legalSource -Leaf))
    }
}

# cli-check.ahk deixou de ser distribuído (2026-09-08): o EXE compilado
# executa IntegrityDoCheck() internamente com o manifesto embutido (ver
# lib/app/IntegrityCheck.ahk e main.ahk). Isso remove a dependência de um
# AutoHotkey instalado no PC de destino para rodar --integrity-check.

$leakedSources = Get-ChildItem -LiteralPath $StageDir -File -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -in @('.ahk', '.ps1', '.iss', '.html', '.json') }
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
Write-Step 'Montando pasta de distribuição portátil'
if (Test-Path -LiteralPath $DistributionOutDir) {
    Remove-Item -LiteralPath $DistributionOutDir -Recurse -Force
}
New-Item -ItemType Directory -Path $DistributionOutDir -Force | Out-Null
Get-ChildItem -LiteralPath $StageDir -Force | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $DistributionOutDir -Recurse -Force
}

Write-Step 'Gerando ZIP portátil do release'
$PortableZipName = "Praxis-Portable-$Version.zip"
$PortableZipPath = Join-Path $ReleaseRoot $PortableZipName
if (Test-Path -LiteralPath $PortableZipPath) {
    Remove-Item -LiteralPath $PortableZipPath -Force
}
# Copia para pasta com o nome do artefato para que o zip tenha raiz única
# (Compress-Archive usa o nome do diretório de origem como pasta raiz).
$PortableFolder = Join-Path $ReleaseRoot "Praxis-Portable-$Version"
if (Test-Path -LiteralPath $PortableFolder) {
    Remove-Item -LiteralPath $PortableFolder -Recurse -Force
}
Copy-Item -LiteralPath $DistributionOutDir -Destination $PortableFolder -Recurse -Force
Compress-Archive -LiteralPath $PortableFolder -DestinationPath $PortableZipPath -CompressionLevel Optimal
Remove-Item -LiteralPath $PortableFolder -Recurse -Force
if (!(Test-Path -LiteralPath $PortableZipPath)) {
    throw "Falha ao gerar ZIP portátil: $PortableZipPath"
}

Write-Step 'Build concluído'
Write-Host "Release: $ReleaseRoot" -ForegroundColor Green
Write-Host "Executável: $ExePath" -ForegroundColor Green
Write-Host "Distribuição portátil: $DistributionOutDir" -ForegroundColor Green
Write-Host "ZIP portátil: $PortableZipPath" -ForegroundColor Green
