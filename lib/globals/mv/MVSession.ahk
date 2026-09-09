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

; ════════════════════════════════════════════════════════════════
;  API PÚBLICA
; ════════════════════════════════════════════════════════════════

MV_EnsureMovDoc() {
    if WinExist(MV_WIN_MOVDOC_ANY) {
        MV_ActivateModule(MV_WIN_MOVDOC_ANY)
        if MV_WaitWindowStable(MV_WIN_MOVDOC_ANY, MV_MODULE_STABLE_MS, MV_TIMEOUT_LOAD)
            return true
    }
    return false
}

MV_EnsureFFCV() {
    if WinExist(MV_WIN_FFCV_ANY) {
        MV_ActivateModule(MV_WIN_FFCV_ANY)
        if MV_WaitWindowStable(MV_WIN_FFCV_ANY, MV_MODULE_STABLE_MS, MV_TIMEOUT_LOAD)
            return true
    }
    return false
}

; ════════════════════════════════════════════════════════════════
;  DETECÇÃO / CONTROLES
; ════════════════════════════════════════════════════════════════

MV_ActivateModule(moduleWin) {
    if WinExist(moduleWin) {
        WinActivate moduleWin
        MV_Poll(() => WinActive(moduleWin), 3)
    }
}

; ════════════════════════════════════════════════════════════════
;  ERRO / ABORT
; ════════════════════════════════════════════════════════════════

; Aborta a execução de um módulo: envia erro à UI, encerra o estado de
; running (gRunning) e retorna false. Canônica única de Protocolar_Abort
; (ProtocolarParsers.ahk) e RP_Abort (RemessaProtocolo.ahk).
; sendStatus=true emite também a mensagem de status "Execução finalizada."
; (comportamento original do Protocolar).
MV_Abort(msg, sendStatus := false) {
    global gRunning
    SendToUI(Map("type", "error", "message", msg))
    if (sendStatus)
        SendToUI(Map("type", "status", "message", "Execução finalizada.", "running", false))
    gRunning := false
    return false
}
