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
        ; se a janela de identificação aparecer, a automação não prossegue
    }

    if WinExist(MV_WIN_IDENTIFICACAO)
        return MV_AbortAuthenticationRequired("MOV DOC")

    ; Não abrir novo MOV DOC via atalho. Se não estiver aberto, abortar.
    return false
}

MV_EnsureFFCV() {
    if WinExist(MV_WIN_FFCV_ANY) {
        MV_ActivateModule(MV_WIN_FFCV_ANY)
        if MV_WaitWindowStable(MV_WIN_FFCV_ANY, MV_MODULE_STABLE_MS, MV_TIMEOUT_LOAD)
            return true
        ; se a janela de identificação aparecer, a automação não prossegue
    }

    if WinExist(MV_WIN_IDENTIFICACAO)
        return MV_AbortAuthenticationRequired("FFCV")

    ; Não abrir novo FFCV via atalho. Se não estiver aberto, abortar.
    return false
}

; ════════════════════════════════════════════════════════════════
;  AUTENTICAÇÃO AUTOMÁTICA DESABILITADA
; ════════════════════════════════════════════════════════════════

MV_AbortAuthenticationRequired(moduleName) {
    global gRunning
    gRunning := false

    message := "O Praxis não executa autenticação automática. Abra e autentique o " moduleName " manualmente no MV2000i antes de iniciar a automação."
    try SendToUI(Map("type", "error", "message", message))
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
