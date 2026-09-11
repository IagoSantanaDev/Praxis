; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug

SetTitleMatchMode(2)
DetectHiddenText(true)
SetControlDelay(0)
SetWinDelay(0)
SetKeyDelay(0, 0)
CoordMode("Mouse", "Client")

; ════════════════════════════════════════════════════════════════
;  MV SESSION — módulo compartilhado
; ════════════════════════════════════════════════════════════════

; ── Dependências ─────────────────────────────────────────────
#Include %A_LineFile%\..\MVConstants.ahk
#Include %A_LineFile%\..\components\Controls.ahk
#Include %A_LineFile%\..\MVSync.ahk
#Include %A_LineFile%\..\components\ReportPrint.ahk

; ════════════════════════════════════════════════════════════════
;  API PÚBLICA
; ════════════════════════════════════════════════════════════════

MV_EnsureModule(moduleWin, stableMs := 0, timeoutSecs := 0) {
    if (stableMs = 0)
        stableMs := MV_MODULE_STABLE_MS
    if (timeoutSecs = 0)
        timeoutSecs := MV_TIMEOUT_LOAD

    if !WinExist(moduleWin)
        return false

    MV_ActivateModule(moduleWin)
    return MV_WaitWindowStable(moduleWin, stableMs, timeoutSecs)
}

MV_EnsureMovDoc() {
    return MV_EnsureModule(MV_WIN_MOVDOC_ANY)
}

MV_EnsureFFCV() {
    return MV_EnsureModule(MV_WIN_FFCV_ANY)
}

; ════════════════════════════════════════════════════════════════
;  DETECÇÃO / CONTROLES
; ════════════════════════════════════════════════════════════════

MV_ActivateModule(moduleWin) {
    if WinExist(moduleWin) {
        WinActivate moduleWin
        MV_Poll(() => WinActive(moduleWin), MV_WINDOW_ACTIVATE_TIMEOUT_SECS)
    }
}

; ════════════════════════════════════════════════════════════════
;  ERRO / ABORT
; ════════════════════════════════════════════════════════════════

; Aborta a execução de um módulo: envia erro à UI, encerra o estado de
; running (gRunning) e retorna false.
; sendStatus=true emite também a mensagem de status "Execução finalizada."
; (comportamento original do Protocolar).
MV_Abort(msg, sendStatus := false) {
    SendToUI(Map("type", "error", "message", msg))
    if (sendStatus)
        SendToUI(Map("type", "status", "message", "Execução finalizada.", "running", false))
    SetAppRunning(false)
    return false
}
