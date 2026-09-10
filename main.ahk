; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, OutputDebug

; ─── Project root (used by all #Include directives below) ────
global gRoot := A_ScriptDir

for arg in A_Args {
    if (arg = "--integrity-check" || arg = "--check") {
        ; Check interno do EXE compilado: usa o manifesto embutido
        ; (build/generated/Praxis_IntegrityManifest.ahk) e o A_ScriptDir
        ; do executável. Não depende de AutoHotkey instalado no destino e
        ; não distribui cli-check.ahk no stage.
        ; Exit codes: 0 = OK; 70 = recurso ausente/alterado (docs/DISTRIBUTION.md).
        IntegrityDoCheck()
        ExitApp 0
    }
}

; ─── Includes (ordem importa) ────────────────────────────────
; AppState.ahk deve vir antes do manifesto e do App.ahk, 
; pois ambos dependem dos globais e variáveis declarados nele.
#Include lib\app\AppState.ahk
#Include *i build\generated\Praxis_IntegrityManifest.ahk
#Include lib\app\IntegrityCheck.ahk
#Include lib\ui\UiBridge.ahk
#Include lib\ui\UiLog.ahk
; Ordem importa: UiBridge carrega Dispatcher antes de App. O include
; transitivo é a única entrada do Dispatcher para evitar redefinição de
; funções quando o entry point é composto.
#Include lib\app\App.ahk
#Include lib\app\ScriptRegistry.ahk
#Include lib\config\Paths.ahk

; Cancelamento global: Esc interrompe a execução atual definitivamente.
; A próxima execução passa por TryBeginAppRun(), que limpa gStopRequested.
Esc::StopScript()

App_Run()
