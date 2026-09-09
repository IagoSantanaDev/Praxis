; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug

; ════════════════════════════════════════════════════════════════
;  MV DIALOGS — wrappers de modais Forms e OCR de erros
; ════════════════════════════════════════════════════════════════

#Include ..\components\Controls.ahk
#Include ..\MVConstants.ahk
#Include ..\FFCV_ErrorTemplates.ahk

; ── Títulos de janela de modais Forms (derivados de RemessaProtocolo) ──
DIALOG_MODAL_FORMS_CLASS := MV_CLASS_MODAL_FORMS
DIALOG_MOVDOC_POPUP      := "Forms " MV_CLASS_MODAL_FORMS

; ── Helpers de logging interno ────────────────────────────────
; Usa MV_Log de components/Controls.ahk (consolidado em 2026-06-26).

; ════════════════════════════════════════════════════════════════
;  API PÚBLICA
; ════════════════════════════════════════════════════════════════

; Detecta se algum modal Forms (ui60Modal_W32) está ativo.
; Retorna o WinTitle do modal se existir, ou string vazia caso contrário.
Dialog_ActiveModalTitle() {
    result := WinExist(DIALOG_MODAL_FORMS_CLASS)
        ? DIALOG_MODAL_FORMS_CLASS
        : ""
    MV_Log("Dialog_ActiveModalTitle", "modal ativo=" (result != ""), result != "")
    return result
}

; Classifica erros do modal Oracle Forms via OCR, usando FFCV_ClassifyErrorModal, 
; e retorna um Map com tipo, descrição, fonte, texto e imagem.
Dialog_ClassifyErroContaModal(winTitle := "") {
    if (winTitle = "")
        winTitle := Dialog_ActiveModalTitle()

    if (winTitle = "")
        return Map("tipo", "erro_desconhecido", "descricao", "modal Forms nao classificado", "fonte", "sem modal Forms", "texto", "", "img", "")

    result := FFCV_ClassifyErrorModal(winTitle)
    MV_Log("Dialog_ClassifyErroContaModal",
        "tipo=" result.Get("tipo", "?") " descricao=" result.Get("descricao", "?"), true)
    return result
}

; Detecta se o popup de última linha do MOV DOC está visível.
; Wrapper fino sobre WinExist do título do popup MOV DOC.
Dialog_MovDocPopupVisible() {
    result := WinExist(DIALOG_MOVDOC_POPUP)
    MV_Log("Dialog_MovDocPopupVisible", "popup visivel=" result, result)
    return result
}

; Fecha o popup modal do MOV DOC (ultimo registro / navegacao).
; Usa MV_ClickFirstControl com MV_MODAL_OK_CLASS; fallback Enter.
Dialog_DismissMovDocPopup() {
    try {
        if !WinExist(DIALOG_MOVDOC_POPUP) {
            MV_Log("Dialog_DismissMovDocPopup", "popup nao existe", false)
            return false
        }

        WinActivate DIALOG_MOVDOC_POPUP
        Sleep MV_DELAY_INPUT

        if !MV_Poll(() => Popup_FirstControlByClass(DIALOG_MOVDOC_POPUP, MV_MODAL_OK_CLASS) != 0, 5) {
            MV_Log("Dialog_DismissMovDocPopup", "OK botao nao ficou disponivel", false)
            return false
        }

        if !MV_ClickFirstControl(DIALOG_MOVDOC_POPUP, MV_MODAL_OK_CLASS) {
            MV_Log("Dialog_DismissMovDocPopup", "MV_ClickFirstControl falhou, usando Enter", false)
            Send "{Enter}"
        }

        result := MV_Poll(() => !WinExist(DIALOG_MOVDOC_POPUP), 3)
        MV_Log("Dialog_DismissMovDocPopup", "popup fechado=" result, result)
        return result
    }

    MV_Log("Dialog_DismissMovDocPopup", "excecao", false)
    return false
}
