# find-implicit-locals.ps1
#
# Detects the AHK v2 "implicit local" bug pattern in lib/ source files.
#
# In AutoHotkey v2, a function that assigns to a variable WITHOUT first
# declaring `global X` silently creates an empty LOCAL — the global is
# never touched. Reads of globals are fine; assignments are the bug.
# Same bug class as the App.ahk (gExitAfterStop) and Settings.ahk
# (gSettingsCache) fixes that motivated this tool.
#
# What counts as an assignment:
#   X := value
#   obj[key] := value   (Map / Object key write to a global)
#   X += value   (and -= *= /= .= &= |= ^= <<= >>= **=)
#   ++X / X++ / --X / X--
#
# What is intentionally NOT flagged:
#   X            (read)
#   if X == ...  (comparison)
#   return X     (read)
#   X(args)      (call)
#   "X := ..."   (string literal, heuristic — see Limitations)
#
# Verdicts:
#   BUG    - assignment to a top-level global with no `global X` in the
#            enclosing function scope. Silent shadow. Fix: add `global X`
#            at the top of the function.
#   OK     - assignment to a top-level global WITH `global X` declared
#            in the enclosing function. Reported in -Verbose mode only.
#   WARN   - edge case: `local X` shadow of a global, or `global` used
#            as assume-global mode (bareword first line of function),
#            or nested-function context. Not a hard bug but worth a look.
#
# Exit codes:
#   0 = clean (no BUG findings)
#   1 = BUG findings present
#   2 = usage / file system error
#
# Usage:
#   pwsh tools/find-implicit-locals.ps1 [-Root <path>] [-FailOnFindings]
#
# Wired into build-praxis.ps1 alongside find-top-level-calls.ps1.

[CmdletBinding()]
param(
    [string]$Root = 'lib',
    [switch]$FailOnFindings = $true
)

if (-not (Test-Path -LiteralPath $Root)) {
    Write-Error "Root path not found: $Root"
    exit 2
}

$ReservedKeywords = @(
    'if','else','while','for','until','loop','do','return','break','continue',
    'try','catch','finally','throw','class','extends','switch','case','default',
    'static','local','global','and','or','not','new','this','super','base',
    'true','false','unset','enum'
)

function Test-FunctionHeader {
    param([string]$Line)
    $clean = $Line -replace '\s+;.*$', ''
    if ($clean -notmatch '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*\([^)]*\)\s*\{?\s*$') { return $false }
    $name = $matches[1].ToLower()
    if ($ReservedKeywords -contains $name) { return $false }
    return $true
}

function Get-AssignedVariable {
    param([string]$Stripped)
    # Direct assignment (single := / == / != comparisons are excluded by checking next char isn't =)
    if ($Stripped -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*:=') {
        return $matches[1]
    }
    # Map / Object key write
    if ($Stripped -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\[[^\]]+\]\s*:=') {
        return $matches[1]
    }
    # Compound assignment: var <op>= (op in + - * / . & | ^ << >> **)
    # Must exclude == and != comparisons — check operator length and confirm
    if ($Stripped -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*([+\-*/.&|^]{1,2})=(?!=)') {
        # PowerShell regex doesn't support lookahead; fall back to manual check.
        $op = $matches[2]
        if ($op.Length -ge 2 -and $op.EndsWith('=')) {
            # Two-char operator like <<, >>, **
            return $matches[1]
        }
        if ($op.Length -eq 1) {
            return $matches[1]
        }
        return $null
    }
    # Pre-increment/decrement: ++X / --X
    if ($Stripped -match '^\s*(\+\+|--)\s*([A-Za-z_][A-Za-z0-9_]*)\s*$') {
        return $matches[2]
    }
    # Post-increment/decrement: X++ / X--
    if ($Stripped -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*(\+\+|--)\s*$') {
        return $matches[1]
    }
    return $null
}

function Split-GlobalNames {
    param([string]$Declaration)
    $names = @()
    foreach ($part in ($Declaration -split ',')) {
        $n = ($part -replace ':=.*$', '').Trim()
        if ($n -match '^[A-Za-z_][A-Za-z0-9_]*$') {
            $names += $n
        }
    }
    return ,$names
}

$findings = New-Object System.Collections.Generic.List[object]
$okCount = 0
$warnCount = 0
$fileCount = 0
$lineCount = 0
$totalGlobalsTracked = 0

Get-ChildItem -Path $Root -Recurse -Filter '*.ahk' -File -ErrorAction SilentlyContinue | ForEach-Object {
    $fileCount++
    $rel = $_.FullName.Substring((Get-Location).Path.Length + 1)
    $lines = Get-Content -LiteralPath $_.FullName -ErrorAction SilentlyContinue
    if ($null -eq $lines) { return }
    $lineCount += $lines.Count

    # ── Pass 1: collect top-level globals ─────────────────────
    $topLevelGlobals = [ordered]@{}
    $depth = 0
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $stripped = ($lines[$i] -replace '\s+;.*$', '')
        $opens = ([regex]::Matches($stripped, '\{')).Count
        $closes = ([regex]::Matches($stripped, '\}')).Count
        $depth += $opens - $closes
        if ($depth -ne 0) { continue }
        # Top-level (depth == 0): skip comments
        if ($stripped -match '^\s*;') { continue }
        if ($stripped -match '^\s*global\s+(.+?)\s*$') {
            foreach ($n in (Split-GlobalNames $matches[1])) {
                if (-not $topLevelGlobals.Contains($n)) {
                    $topLevelGlobals[$n] = $i + 1
                }
            }
        }
    }

    if ($topLevelGlobals.Count -eq 0) { return }
    $totalGlobalsTracked += $topLevelGlobals.Count

    # ── Pass 2: walk scopes, find assignments inside functions ──
    $depth = 0
    $scopeStack = New-Object System.Collections.Generic.Stack[object]

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $raw = $lines[$i]
        $stripped = ($raw -replace '\s+;.*$', '')
        $wasDepth = $depth
        $opens = ([regex]::Matches($stripped, '\{')).Count
        $closes = ([regex]::Matches($stripped, '\}')).Count
        $depth += $opens - $closes

        # New scopes opened on this line
        for ($d = $wasDepth; $d -lt $depth; $d++) {
            $isFunc = $false
            if (Test-FunctionHeader $raw) {
                $isFunc = $true
            } elseif ($i -gt 0 -and (Test-FunctionHeader $lines[$i - 1])) {
                $isFunc = $true
            }
            $newScope = [pscustomobject]@{
                Globals        = @{}
                Locals         = @{}
                IsFunction     = $isFunc
                AssumeGlobal   = $false
                FuncName       = ''
                FuncLine       = $i + 1
            }
            [void]$scopeStack.Push($newScope)
        }
        # Scopes closed on this line
        for ($d = $depth; $d -lt $wasDepth; $d++) {
            if ($scopeStack.Count -gt 0) { [void]$scopeStack.Pop() }
        }

        if ($scopeStack.Count -eq 0) { continue }
        $currentScope = $scopeStack.Peek()

        # Find the enclosing function scope (if any) — we may be inside an
        # if/loop/try block nested inside a function. Track that function.
        $enclosingFunc = $null
        foreach ($scope in $scopeStack) {
            if ($scope.IsFunction) { $enclosingFunc = $scope; break }
        }
        if (-not $enclosingFunc) { continue }

        # Record function name on first line of the function header for diagnostics
        if ($enclosingFunc.FuncName -eq '') {
            $headerLine = if (Test-FunctionHeader $raw) { $raw } elseif ($i -gt 0) { $lines[$i - 1] } else { '' }
            if ($headerLine -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*\(') {
                $enclosingFunc.FuncName = $matches[1]
            }
        }

        # Bare `global` line → assume-global mode (function-scoped)
        if ($stripped -match '^\s*global\s*$') {
            $enclosingFunc.AssumeGlobal = $true
            continue
        }
        # `global X[, Y, Z]` declaration (function-scoped)
        if ($stripped -match '^\s*global\s+(.+?)\s*$') {
            foreach ($n in (Split-GlobalNames $matches[1])) {
                $enclosingFunc.Globals[$n] = $true
            }
            continue
        }
        # `local X[, Y, Z]` declaration (function-scoped shadowing record)
        if ($stripped -match '^\s*local\s+(.+?)\s*$') {
            foreach ($n in (Split-GlobalNames $matches[1])) {
                $enclosingFunc.Locals[$n] = $true
            }
            continue
        }

        $assigned = Get-AssignedVariable $stripped
        if (-not $assigned) { continue }
        if (-not $topLevelGlobals.Contains($assigned)) { continue }

        # Is this global declared as global somewhere in an active scope?
        $declaredAsGlobal = $false
        foreach ($scope in $scopeStack) {
            if ($scope.Globals.ContainsKey($assigned)) { $declaredAsGlobal = $true; break }
        }
        if ($declaredAsGlobal) {
            $okCount++
            Write-Verbose ("  OK    {0}:{1}  {2} := ...   in {3}()" -f $rel, ($i + 1), $assigned, $enclosingFunc.FuncName)
            continue
        }

        # Was this global shadowed via local in the current function?
        $shadowedLocal = $false
        foreach ($scope in $scopeStack) {
            if ($scope.Locals.ContainsKey($assigned)) { $shadowedLocal = $true; break }
        }
        if ($shadowedLocal) {
            $warnCount++
            [void]$findings.Add([pscustomobject]@{
                File    = $rel
                Line    = $i + 1
                Global  = $assigned
                Func    = $enclosingFunc.FuncName
                Content = $raw.Trim()
                Verdict = 'WARN'
                Reason  = 'shadowed via local in same function'
            })
            continue
        }

        if ($enclosingFunc.AssumeGlobal) {
            $warnCount++
            [void]$findings.Add([pscustomobject]@{
                File    = $rel
                Line    = $i + 1
                Global  = $assigned
                Func    = $enclosingFunc.FuncName
                Content = $raw.Trim()
                Verdict = 'WARN'
                Reason  = 'function uses assume-global mode'
            })
            continue
        }

        # Nested function context: if the current function is nested inside another function
        $nested = $false
        if ($scopeStack.Count -gt 1) {
            $foundFirst = $false
            foreach ($scope in $scopeStack) {
                if ($scope.IsFunction) {
                    if ($foundFirst) { $nested = $true; break }
                    $foundFirst = $true
                }
            }
        }

        $findingsEntry = [pscustomobject]@{
            File    = $rel
            Line    = $i + 1
            Global  = $assigned
            Func    = $enclosingFunc.FuncName
            Content = $raw.Trim()
            Verdict = if ($nested) { 'WARN' } else { 'BUG' }
            Reason  = if ($nested) { 'nested function context' } else { 'no `global X` in enclosing function' }
        }
        [void]$findings.Add($findingsEntry)
        if ($nested) { $warnCount++ }
    }
}

$bugs = @(($findings | Where-Object { $_.Verdict -eq 'BUG' }))
$warns = @(($findings | Where-Object { $_.Verdict -eq 'WARN' }))

Write-Host ""
Write-Host ("Scanned {0} file(s), {1} line(s)" -f $fileCount, $lineCount)
Write-Host ("Top-level globals tracked: {0}" -f $totalGlobalsTracked)
Write-Host ("OK (with global X declared): {0}" -f $okCount)
Write-Host ("BUG (silent implicit-local): {0}" -f $bugs.Count) -ForegroundColor $(if ($bugs.Count -gt 0) { 'Red' } else { 'Green' })
Write-Host ("WARN (edge case): {0}" -f $warns.Count) -ForegroundColor $(if ($warns.Count -gt 0) { 'Yellow' } else { 'Green' })
Write-Host ""

if ($bugs.Count -gt 0) {
    Write-Host "BUG findings:" -ForegroundColor Red
    foreach ($f in $bugs) {
        Write-Host ("  {0}:{1}  {2} := ...  in {3}()  ->  {4}" -f $f.File, $f.Line, $f.Global, $f.Func, $f.Reason) -ForegroundColor Red
        Write-Host ("    {0}" -f $f.Content) -ForegroundColor DarkRed
    }
    Write-Host ""
    Write-Host "Fix: add `global X` (or `global X, Y, Z`) as the first executable" -ForegroundColor Yellow
    Write-Host "line inside the function. AHK v2 otherwise makes the assignment" -ForegroundColor Yellow
    Write-Host "a silent local that gets thrown away when the function returns." -ForegroundColor Yellow
    Write-Host ""
}

if ($warns.Count -gt 0) {
    Write-Host "WARN findings (review but not failures):" -ForegroundColor Yellow
    foreach ($f in $warns) {
        Write-Host ("  {0}:{1}  {2} := ...  in {3}()  ->  {4}" -f $f.File, $f.Line, $f.Global, $f.Func, $f.Reason) -ForegroundColor Yellow
    }
    Write-Host ""
}

if ($bugs.Count -eq 0) {
    Write-Host "OK: no implicit-local writes in $Root" -ForegroundColor Green
    exit 0
}

if ($FailOnFindings) { exit 1 } else { exit 0 }