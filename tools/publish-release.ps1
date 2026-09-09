<#
.SYNOPSIS
Gera o build portátil do Praxis (EXE sem fonte), zipla e publica/atualiza um GitHub Release único (rolling).

.DESCRIPTION
Fluxo:
  1. Deriva a versão (default: 1.0.0-<sha curto do HEAD>) e roda tools/build-praxis.ps1 -SkipInstaller
     (que gera dist\Praxis-<ver>\distribution\ e o ZIP portátil).
  2. Gera SHA256SUMS.txt com o hash do ZIP.
  3. Publica (ou atualiza, com --clobber) um GitHub Release de tag fixa (default "continuous")
     marcado como Latest — o release rolling contém sempre a versão mais recente do Praxis.

Autenticação:
  - No GitHub Actions, defina o env GH_TOKEN=secrets.GITHUB_TOKEN (feito pelo workflow release.yml).
  - Localmente, faça `gh auth login` antes de rodar.

Exemplos:
  powershell -ExecutionPolicy Bypass -File .\tools\publish-release.ps1
  powershell -ExecutionPolicy Bypass -File .\tools\publish-release.ps1 -Version 1.0.0
  powershell -ExecutionPolicy Bypass -File .\tools\publish-release.ps1 -Tag stable -DryRun
#>

[CmdletBinding()]
param(
    [ValidatePattern('^\d+\.\d+\.\d+([-.+][A-Za-z0-9.-]+)?$')]
    [string]$Version,

    [string]$Tag = 'continuous',

    # Repassados ao build quando o AutoHotkey/Ahk2Exe não estão no PATH
    # (caso do GitHub Actions, que baixa os zips oficiais por step).
    [string]$AutoHotkeyBasePath,
    [string]$Ahk2ExePath,

    [switch]$SkipBuild,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$BuildScript = Join-Path $ProjectRoot 'tools\build-praxis.ps1'

function Write-Step {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Get-GitHead {
    param([string]$RepositoryRoot)

    $sha = (& git -C $RepositoryRoot rev-parse HEAD 2>$null)
    if ($LASTEXITCODE -ne 0) { throw 'Não foi possível ler o HEAD do repositório git.' }
    $short = (& git -C $RepositoryRoot rev-parse --short HEAD 2>$null)
    $status = @(& git -C $RepositoryRoot status --porcelain 2>$null)
    return [ordered]@{
        Sha    = $sha.Trim()
        Short  = $short.Trim()
        Dirty  = $status.Count -gt 0
    }
}

function Invoke-Publish {
    param([string[]]$Arguments)

    if ($DryRun) {
        Write-Host "   [dry-run] gh $($Arguments -join ' ')" -ForegroundColor DarkGray
        return $false
    }
    & gh @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "gh $($Arguments[0]) falhou com exit code $LASTEXITCODE"
    }
    return $true
}

# 1. Versão
$gitState = Get-GitHead -RepositoryRoot $ProjectRoot
if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = "1.0.0-$($gitState.Short)"
}
if ($gitState.Dirty) {
    Write-Warning "Working tree sujo. O build registrará sourceDirty=true e o artefato pode não corresponder a um commit publicado."
}

$ReleaseRoot = Join-Path $ProjectRoot "dist\Praxis-$Version"
$ZipPath = Join-Path $ReleaseRoot "Praxis-Portable-$Version.zip"
$SumsPath = Join-Path $ReleaseRoot 'SHA256SUMS.txt'

# 2. Build
if (!$SkipBuild) {
    Write-Step "Build portátil (versão $Version)"
    $buildArgs = @('-Version', $Version, '-SkipInstaller')
    if (![string]::IsNullOrWhiteSpace($AutoHotkeyBasePath)) { $buildArgs += @('-AutoHotkeyBasePath', $AutoHotkeyBasePath) }
    if (![string]::IsNullOrWhiteSpace($Ahk2ExePath)) { $buildArgs += @('-Ahk2ExePath', $Ahk2ExePath) }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $BuildScript @buildArgs
    if ($LASTEXITCODE -ne 0) {
        throw "tools/build-praxis.ps1 falhou com exit code $LASTEXITCODE."
    }
}

if (!(Test-Path -LiteralPath $ZipPath)) {
    throw "ZIP portátil não encontrado: $ZipPath (rode o build ou use -SkipBuild somente com build completo prévio)."
}

# 3. SHA256SUMS
Write-Step "Gerando SHA256SUMS.txt"
$zipHash = (Get-FileHash -LiteralPath $ZipPath -Algorithm SHA256).Hash.ToLowerInvariant()
$zipName = Split-Path $ZipPath -Leaf
Set-Content -LiteralPath $SumsPath -Value "$zipHash  $zipName" -Encoding ASCII
Write-Host "   $zipHash  $zipName" -ForegroundColor DarkGray

# 4. Release notes
$NotesPath = Join-Path $ReleaseRoot 'release-notes.md'
$notes = @(
    "# Praxis - pacote portátil (rolling)",
    "",
    "- **Versão:** $Version",
    "- **Commit:** $($gitState.Sha)",
    "- **Estado da árvore de origem:** $(if ($gitState.Dirty) {'working tree sujo'} else {'limpa'})",
    "- **Data (UTC):** $((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss'))",
    "- **ZIP:** $zipName  ($($zipHash.Substring(0, 12))…)",
    "",
    "Pronto para uso: descompacte e execute `Praxis.exe` (Windows 64-bit). O PC de destino precisa do Microsoft Edge WebView2 Runtime.",
    "Artefatos versionados são entregues como releases fixos; a tag $Tag é o release rolling atualizado a cada push em main."
) -join [Environment]::NewLine
Set-Content -LiteralPath $NotesPath -Value $notes -Encoding UTF8

# 5. Publicar/atualizar o release rolling
Write-Step "Publicando release GitHub '$Tag'"
$releaseExists = $false
if ($DryRun) {
    Write-Host "   [dry-run] gh release view $Tag --json tagName" -ForegroundColor DarkGray
} else {
    & gh release view $Tag --json tagName 2>$null | Out-Null
    $releaseExists = $LASTEXITCODE -eq 0
}

if (!$releaseExists) {
    Write-Step "Release '$Tag' não existe — criando"
    Invoke-Publish @('release', 'create', $Tag, $ZipPath, $SumsPath, '--title', "Praxis $Version", '--notes-file', $NotesPath, '--latest') | Out-Null
} else {
    Write-Step "Release '$Tag' existe — atualizando assets e metadados"
    Invoke-Publish @('release', 'upload', $Tag, $ZipPath, $SumsPath, '--clobber') | Out-Null
    Invoke-Publish @('release', 'edit', $Tag, '--title', "Praxis $Version", '--notes-file', $NotesPath, '--latest') | Out-Null
}

$url = $null
if ($DryRun) {
    Write-Host "   [dry-run] gh release view $Tag --json url -q '.url'" -ForegroundColor DarkGray
} else {
    $url = (& gh release view $Tag --json url -q '.url' 2>$null)
}
Write-Step 'Publicação concluída'
Write-Host "Release: $Tag  ($url)" -ForegroundColor Green