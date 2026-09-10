<#
.SYNOPSIS
Gera o build portátil do Praxis (EXE sem fonte), zipla e publica/atualiza um GitHub Release rolling por branch.

.DESCRIPTION
Fluxo:
  1. Deriva a versão (default: 1.0.0-<sha curto do HEAD>) e roda tools/build-praxis.ps1
     (que gera dist\Praxis-<ver>\distribution\ e o ZIP portátil).
  2. Gera SHA256SUMS.txt com o hash do ZIP.
  3. Publica (ou atualiza, com --clobber) um GitHub Release da branch informada.
     A tag deve ser única por branch, por exemplo continuous-main ou continuous-kan-03.

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

    [string]$Branch,

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

function Invoke-Gh {
    param([string[]]$Arguments)

    # Windows PowerShell 5.1 converte stderr de exe nativo em NativeCommandError
    # que, com $ErrorActionPreference='Stop', aborta o script até com 2>$null
    # (ex.: `gh release view` com release inexistente imprime "release not found"
    # no stderr e retorna exit 1). Isolamos a chamada com EAP=Continue e avaliamos
    # o $LASTEXITCODE — padrão recomendado pela documentação oficial do GitHub.
    $previousEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & gh @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousEap
    }

    return [pscustomobject]@{
        ExitCode = [int]$exitCode
        Output   = (@($output) -join [Environment]::NewLine).Trim()
    }
}

function Assert-GhSucceeded {
    param([string[]]$Arguments)

    $result = Invoke-Gh -Arguments $Arguments
    if ($result.ExitCode -ne 0) {
        throw "gh $($Arguments[0]) falhou com exit code $($result.ExitCode): $($result.Output)"
    }
}

# 1. Versão
$gitState = Get-GitHead -RepositoryRoot $ProjectRoot
if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = "1.0.0-$($gitState.Short)"
}
if ([string]::IsNullOrWhiteSpace($Branch)) {
    $Branch = (& git -C $ProjectRoot branch --show-current 2>$null).Trim()
    if ([string]::IsNullOrWhiteSpace($Branch)) { $Branch = 'detached' }
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
    $buildArgs = @('-Version', $Version)
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
    "- **Branch:** $Branch",
    "- **Tag:** $Tag",
    "- **Versão:** $Version",
    "- **Commit:** $($gitState.Sha)",
    "- **Estado da árvore de origem:** $(if ($gitState.Dirty) {'working tree sujo'} else {'limpa'})",
    "- **Data (UTC):** $((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss'))",
    "- **ZIP:** $zipName  ($($zipHash.Substring(0, 12))…)",
    "",
    "Pronto para uso: descompacte e execute `Praxis.exe` (Windows 64-bit). O PC de destino precisa do Microsoft Edge WebView2 Runtime.",
    "Este release rolling pertence exclusivamente à branch $Branch e é atualizado a cada push nela."
) -join [Environment]::NewLine
Set-Content -LiteralPath $NotesPath -Value $notes -Encoding UTF8

# 5. Publicar/atualizar o release rolling
Write-Step "Publicando release GitHub '$Tag'"
$releaseExists = $false
if ($DryRun) {
    Write-Host "   [dry-run] gh release view $Tag --json tagName" -ForegroundColor DarkGray
} else {
    $view = Invoke-Gh -Arguments @('release', 'view', $Tag, '--json', 'tagName')
    $releaseExists = $view.ExitCode -eq 0
}

if (!$releaseExists) {
    Write-Step "Release '$Tag' não existe — criando"
    if ($DryRun) {
        Write-Host "   [dry-run] gh release create $Tag $ZipPath $SumsPath --title 'Praxis $Version - $Branch' --notes-file $NotesPath" -ForegroundColor DarkGray
    } else {
        Assert-GhSucceeded @('release', 'create', $Tag, $ZipPath, $SumsPath, '--title', "Praxis $Version - $Branch", '--notes-file', $NotesPath)
    }
} else {
    Write-Step "Release '$Tag' existe — atualizando assets e metadados"
    if ($DryRun) {
        Write-Host "   [dry-run] gh release upload $Tag $ZipPath $SumsPath --clobber" -ForegroundColor DarkGray
        Write-Host "   [dry-run] gh release edit $Tag --title 'Praxis $Version - $Branch' --notes-file $NotesPath" -ForegroundColor DarkGray
    } else {
        Assert-GhSucceeded @('release', 'upload', $Tag, $ZipPath, $SumsPath, '--clobber')
        Assert-GhSucceeded @('release', 'edit', $Tag, '--title', "Praxis $Version - $Branch", '--notes-file', $NotesPath)
    }
}

$url = $null
if ($DryRun) {
    Write-Host "   [dry-run] gh release view $Tag --json url -q '.url'" -ForegroundColor DarkGray
} else {
    $view = Invoke-Gh -Arguments @('release', 'view', $Tag, '--json', 'url', '-q', '.url')
    $url = $view.Output
}
Write-Step 'Publicação concluída'
Write-Host "Release: $Tag  ($url)" -ForegroundColor Green