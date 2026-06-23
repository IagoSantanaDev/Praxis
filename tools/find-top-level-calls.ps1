# find-top-level-calls.ps1
#
# Detects top-level bare function calls in AHK v2 source files.
# Catches the bug pattern where a file defines Foo() AND has a top-level Foo() call,
# causing double execution when included by main.ahk (e.g., two GUI windows opening).
#
# Top-level = column 0, not inside a comment, not a directive, not inside a function.
# Ignores JSDoc-style multi-line comments and inline /* ... */ comments.
#
# Exit codes:
#   0 = clean (no findings), or warnings only with -PassThrough
#   1 = findings present
#   2 = usage / file system error
#
# Usage:
#   pwsh tools/find-top-level-calls.ps1 [-Root <path>] [-FailOnFindings]
#
# Wired into build-praxis.ps1 before Ahk2Exe compilation.

[CmdletBinding()]
param(
    [string]$Root = 'lib',
    [switch]$FailOnFindings = $true
)

if (-not (Test-Path -LiteralPath $Root)) {
    Write-Error "Root path not found: $Root"
    exit 2
}

$inBlock = $false
$findings = New-Object System.Collections.Generic.List[object]

Get-ChildItem -Path $Root -Recurse -Filter '*.ahk' -File -ErrorAction SilentlyContinue | ForEach-Object {
    $rel = $_.FullName.Substring((Get-Location).Path.Length + 1)
    $lines = Get-Content -LiteralPath $_.FullName -ErrorAction SilentlyContinue
    if ($null -eq $lines) { return }

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        if ($inBlock) {
            if ($line -match '\*/') { $inBlock = $false }
            continue
        }
        if ($line -match '/\*') {
            if ($line -notmatch '\*/') { $inBlock = $true }
            continue
        }
        if ($line -match '^\s*;') { continue }
        if ($line -match '^\s') { continue }
        if ($line -match '^#') { continue }
        if ($line -match '^\s*$') { continue }
        if ($line -match '^[A-Za-z0-9_]+:') { continue }

        if ($line -match '^[A-Z][A-Za-z0-9_]*\(\)\s*$') {
            $findings.Add([pscustomobject]@{
                File    = $rel
                Line    = $i + 1
                Content = $line.Trim()
            })
        }
    }
}

if ($findings.Count -eq 0) {
    Write-Host "OK: no top-level bare function calls in $Root" -ForegroundColor Green
    exit 0
}

Write-Host ""
Write-Host "FOUND: $($findings.Count) top-level call(s) in $Root" -ForegroundColor Yellow
Write-Host ""
foreach ($f in $findings) {
    Write-Host ("  {0}:{1}  {2}" -f $f.File, $f.Line, $f.Content)
}
Write-Host ""
Write-Host "Top-level calls of functions defined in the same file cause double" -ForegroundColor Yellow
Write-Host "execution when the file is #Include'd. Move the call into main.ahk" -ForegroundColor Yellow
Write-Host "(or wherever the caller lives) so the file is included but never self-invokes." -ForegroundColor Yellow
Write-Host ""

if ($FailOnFindings) {
    exit 1
}
exit 0