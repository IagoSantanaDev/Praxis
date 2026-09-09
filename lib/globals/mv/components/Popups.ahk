; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug

; ════════════════════════════════════════════════════════════════
;  MV POPUPS — wrappers de deteccao e fechamento de popups/modais
; ════════════════════════════════════════════════════════════════

#Include ..\components\Controls.ahk
#Include ..\MVConstants.ahk

; ── Constantes de popups do MV (derivadas de RemessaProtocolo) ──
; Sentinel do popup "Informacoes da Conta" embarcado na janela FFCV.
POPUP_CONTA_SENTINEL_CLASS := "ui60Drawn W323"
POPUP_CONTA_SENTINEL_X     := 432
POPUP_CONTA_SENTINEL_Y     := 109
POPUP_CAMPO_CONTA          := "Edit2"
POPUP_CAMPO_CONTA_X        := 298
POPUP_CAMPO_CONTA_Y        := 143
POPUP_DROPDOWN_1           := "ComboBox2"
POPUP_DROPDOWN_1_X         := 84
POPUP_DROPDOWN_1_Y         := 143
POPUP_DROPDOWN_2           := "ComboBox1"
POPUP_DROPDOWN_2_X         := 190
POPUP_DROPDOWN_2_Y         := 143
POPUP_STABLE_MS            := 100

; ── Helpers de logging interno ────────────────────────────────
; Usa MV_Log de components/Controls.ahk (consolidado em 2026-06-26).

; ════════════════════════════════════════════════════════════════
;  API PÚBLICA
; ════════════════════════════════════════════════════════════════

; Detecta se o popup "Informações da Conta" está visível na janela FFCV.
; Usa sentinela ui60Drawn + busca do campo de conta por classe/posição.
Popup_ContaVisible() {
    sentinel := Popup_FindControlByClassPrefixAtPoint(
        MV_WIN_FFCV_ANY, "ui60Drawn",
        POPUP_CONTA_SENTINEL_X, POPUP_CONTA_SENTINEL_Y, 35)
    if !sentinel
        return false

    campoConta := MV_FindControlByClientPoint(
        MV_WIN_FFCV_ANY, POPUP_CAMPO_CONTA,
        POPUP_CAMPO_CONTA_X, POPUP_CAMPO_CONTA_Y, 35)
    if !campoConta
        campoConta := Popup_FindControlByClassPrefixAtPoint(
            MV_WIN_FFCV_ANY, "Edit",
            POPUP_CAMPO_CONTA_X, POPUP_CAMPO_CONTA_Y, 50)

    if !campoConta
        campoConta := Popup_FindControlByClassPrefixAtPoint(
            MV_WIN_FFCV_ANY, "ComboBox",
            POPUP_DROPDOWN_1_X, POPUP_DROPDOWN_1_Y, 40)

    if !campoConta
        campoConta := Popup_FindControlByClassPrefixAtPoint(
            MV_WIN_FFCV_ANY, "ComboBox",
            POPUP_DROPDOWN_2_X, POPUP_DROPDOWN_2_Y, 40)

    MV_Log("Popup_ContaVisible", "campoConta=" campoConta, campoConta != 0)
    return campoConta != 0
}

; Localiza o controle mais próximo do ponto informado, filtrando pelo prefixo ClassNN;
; retorna o hwnd ou 0 se não encontrar.
Popup_FindControlByClassPrefixAtPoint(winTitle, classPrefix, targetX, targetY, tolerance := 35) {
    try hwnds := WinGetControlsHwnd(winTitle)
    catch {
        MV_Log("Popup_FindControlByClassPrefixAtPoint",
            "WinGetControlsHwnd falhou winTitle=" winTitle, false)
        return 0
    }

    bestHwnd := 0
    bestDist := 999999

    for hwnd in hwnds {
        try ctrlClass := ControlGetClassNN(hwnd)
        catch
            continue

        if (SubStr(ctrlClass, 1, StrLen(classPrefix)) != classPrefix)
            continue

        try ControlGetPos &cx, &cy, &cw, &ch, hwnd
        catch
            continue

        if (targetX >= cx && targetX <= cx + cw && targetY >= cy && targetY <= cy + ch)
            return hwnd

        centerX := cx + (cw / 2)
        centerY := cy + (ch / 2)
        dist := Sqrt((targetX - centerX) ** 2 + (targetY - centerY) ** 2)
        if (dist < bestDist) {
            bestDist := dist
            bestHwnd := hwnd
        }
    }

    result := (bestHwnd && bestDist <= tolerance) ? bestHwnd : 0
    MV_Log("Popup_FindControlByClassPrefixAtPoint",
        "winTitle=" winTitle " classPrefix=" classPrefix " targetX=" targetX " targetY=" targetY " => hwnd=" result, result != 0)
    return result
}

; Encontra o primeiro controle com a classe ClassNN exata na janela informada.
; Retorna hwnd do controle ou 0 se não encontrado.
Popup_FirstControlByClass(winTitle, classNN) {
    try hwnds := WinGetControlsHwnd(winTitle)
    catch {
        MV_Log("Popup_FirstControlByClass",
            "WinGetControlsHwnd falhou winTitle=" winTitle, false)
        return 0
    }

    for hwnd in hwnds {
        try ctrlClass := ControlGetClassNN(hwnd)
        catch
            continue
        if (ctrlClass = classNN) {
            MV_Log("Popup_FirstControlByClass",
                "winTitle=" winTitle " classNN=" classNN " => hwnd=" hwnd, true)
            return hwnd
        }
    }

    MV_Log("Popup_FirstControlByClass",
        "winTitle=" winTitle " classNN=" classNN " => NAO ENCONTRADO", false)
    return 0
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
        Sleep MV_DELAY_INPUT

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

        Sleep POPUP_STABLE_MS
        MV_Log("Popup_DismissActiveModal", "modal fechado com sucesso", true)
        return Map("ok", true, "report",
            "OK do modal clicado e janela fechada/estabilizada.")
    }

    MV_Log("Popup_DismissActiveModal", "excecao", false)
    return Map("ok", false, "report", "Excecao ao tentar fechar o modal.")
}
