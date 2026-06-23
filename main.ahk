; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, OutputDebug

; ─── Project root (used by all #Include directives below) ────
global gRoot := A_ScriptDir

; ─── CLI argument dispatch ───────────────────────────────────
; Supports: --integrity-check
for arg in A_Args {
    if (arg = "--integrity-check" || arg = "--check") {
        ; Delegate to cli-check.ahk to avoid pulling in App.ahk
        ; (App.ahk calls App_Run() at parse-time which blocks on GUI)
        cliResult := RunWait(A_ScriptDir "\cli-check.ahk", , "Min")
        ExitApp cliResult
    }
}

; ─── Includes (ordem importa) ────────────────────────────────
; AppState.ahk deve vir ANTES de Praxis_IntegrityManifest.ahk: o manifesto
; reatribui gIntegrityExpectedFiles com os hashes reais, e so funciona se
; AppState.ahk ja tiver declarado o Map como global (caso contrario cria
; implicit-local). Documentado em lib/app/AppState.ahk:28-29.
; App.ahk vem depois de AppState.ahk pelos mesmos motivos (gRunning,
; gStopRequested, gExitAfterStop, gExitDeadline).
#Include lib\app\AppState.ahk
#Include *i build\generated\Praxis_IntegrityManifest.ahk
#Include lib\ui\UiBridge.ahk
#Include lib\ui\UiLog.ahk
; Ordem importa: UiBridge (e seu include transitivo de Dispatcher) ANTES de App.
; Include explicito de Dispatcher restaurado por defesa em profundidade —
; UiBridge.ahk:9 tambem carrega Dispatcher, mas explicitar aqui elimina o
; acoplamento implicito fragil contra reordenacao futura dos includes.
#Include lib\app\Dispatcher.ahk
#Include lib\app\App.ahk
#Include lib\app\ScriptRegistry.ahk
#Include lib\config\Paths.ahk
#Include lib\config\Settings.ahk
App_Run()
