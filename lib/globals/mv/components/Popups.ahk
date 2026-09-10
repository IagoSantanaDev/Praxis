; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug

; ════════════════════════════════════════════════════════════════
;  MV POPUPS — wrappers de deteccao e fechamento de popups/modais
; ════════════════════════════════════════════════════════════════

#Include %A_LineFile%\..\Controls.ahk
#Include %A_LineFile%\..\..\MVConstants.ahk

; Constantes do popup "Informacoes da Conta" ficam em MVConstants.ahk
; (MV_POPUP_*), junto de MV_TIPO_CONTA e dos timings MV_CONTA_*.

; ── Helpers de logging interno ────────────────────────────────
; Usa MV_Log de components/Controls.ahk (consolidado em 2026-06-26).

; ════════════════════════════════════════════════════════════════
;  API PÚBLICA
; ════════════════════════════════════════════════════════════════

; Detecta se o popup "Informações da Conta" está visível na janela FFCV.
; Usa sentinela ui60Drawn + busca do campo de conta por classe/posição.
Popup_ContaVisible() {
    sentinel := Popup_FindControlByClassPrefixAtPoint(
        MV_WIN_FFCV_ANY, MV_POPUP_CONTA_SENTINEL_CLASS,
        MV_POPUP_CONTA_SENTINEL_X, MV_POPUP_CONTA_SENTINEL_Y, 35)
    if !sentinel
        return false

    campoConta := MV_FindControlByClientPoint(
        MV_WIN_FFCV_ANY, MV_POPUP_CAMPO_CONTA,
        MV_POPUP_CAMPO_CONTA_X, MV_POPUP_CAMPO_CONTA_Y, 35)
    if !campoConta
        campoConta := Popup_FindControlByClassPrefixAtPoint(
            MV_WIN_FFCV_ANY, "Edit",
            MV_POPUP_CAMPO_CONTA_X, MV_POPUP_CAMPO_CONTA_Y, 50)

    if !campoConta
        campoConta := Popup_FindControlByClassPrefixAtPoint(
            MV_WIN_FFCV_ANY, "ComboBox",
            MV_POPUP_DROPDOWN_TIPO_X, MV_POPUP_DROPDOWN_TIPO_Y, 40)

    if !campoConta
        campoConta := Popup_FindControlByClassPrefixAtPoint(
            MV_WIN_FFCV_ANY, "ComboBox",
            MV_POPUP_DROPDOWN_SUB_TIPO_X, MV_POPUP_DROPDOWN_SUB_TIPO_Y, 40)

    MV_Log("Popup_ContaVisible", "campoConta=" campoConta, campoConta != 0)
    return campoConta != 0
}

; Localiza o controle mais próximo do ponto informado, filtrando pelo prefixo ClassNN;
; retorna o hwnd ou 0. Delegated para a implementação canônica MV_FindControlAtPoint
; (Controls.ahk) com classPrefix não-vazio.
Popup_FindControlByClassPrefixAtPoint(winTitle, classPrefix, targetX, targetY, tolerance := 35) {
    return MV_FindControlAtPoint(winTitle, classPrefix, targetX, targetY, tolerance, classPrefix)
}

; Encontra o primeiro controle com a classe ClassNN exata na janela informada.
; Retorna hwnd do controle ou 0. Delegated para MV_FirstControlByClass (Controls.ahk).
Popup_FirstControlByClass(winTitle, classNN) {
    return MV_FirstControlByClass(winTitle, classNN)
}

; Fecha o modal Forms ativo (ui60Modal_W32) clicando o botão OK.
; Retorna Map("ok", bool, "report", string).
Popup_DismissActiveModal() {
    popup := WinExist("Forms " MV_CLASS_MODAL_FORMS)
        ? "Forms " MV_CLASS_MODAL_FORMS
        : ""

    if (popup = "") {
        MV_Log("Popup_DismissActiveModal", "nenhum modal ativo", true)
        return Map("ok", true, "report", "")
    }

    try {
        WinActivate popup

        if !MV_Poll(() => Popup_FirstControlByClass(popup, MV_MODAL_OK_CLASS) != 0, 5) {
            MV_Log("Popup_DismissActiveModal",
                "modal existe mas botao OK nao ficou disponivel", false)
            return Map("ok", false, "report",
                "Modal existe, mas o botao OK nao ficou disponivel em tempo.")
        }

        if !MV_ClickFirstControl(popup, MV_MODAL_OK_CLASS) {
            MV_Log("Popup_DismissActiveModal", "MV_ClickFirstControl falhou", false)
            return Map("ok", false, "report",
                "Nao consegui clicar OK do modal.")
        }

        if !MV_Poll(() => !WinExist(popup), MV_TIMEOUT_ACOE) {
            MV_Log("Popup_DismissActiveModal", "modal nao fechou apos clique", false)
            return Map("ok", false, "report",
                "Cliquei OK, mas o modal nao fechou em tempo.")
        }

        Sleep MV_CONTA_STABLE_MS
        MV_Log("Popup_DismissActiveModal", "modal fechado com sucesso", true)
        return Map("ok", true, "report",
            "OK do modal clicado e janela fechada/estabilizada.")
    }

    MV_Log("Popup_DismissActiveModal", "excecao", false)
    return Map("ok", false, "report", "Excecao ao tentar fechar o modal.")
}
