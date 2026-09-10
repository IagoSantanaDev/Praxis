; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug
#Include %A_LineFile%\..\..\MVSession.ahk
#Include %A_LineFile%\..\..\components\Dialogs.ahk
#Include %A_LineFile%\..\..\components\Popups.ahk
#Include %A_LineFile%\..\FfcvScreen.ahk
#Include %A_LineFile%\..\..\..\..\..\lib\config\Paths.ahk

; ── Internal helpers ─────────────────────────────────────────
; Verifica se um controle esta visivel e acessivel em coords XY.
; Delega para a implementacao canonica MV_FindControlAtPoint (Controls.ahk).
_ControlAtReady(winTitle, classNN, clientX, clientY, tolerance := 14) {
    if !WinExist(winTitle)
        return false
    return MV_FindControlAtPoint(winTitle, classNN, clientX, clientY, tolerance, "") != 0
}

; ════════════════════════════════════════════════════════════════
;  TISS XML SCREEN — GERACAO DE XML TISS DE REMESSA
; ════════════════════════════════════════════════════════════════
;
; Este modulo encapsula toda interacao com a tela de XML/TISS do
; sistema MV 2000i. Os helpers de click/teclado/modal abaixo
; foram movidos de RemessaProtocolo.ahk para quebrar a dependencia
; circular (RemessaProtocolo → TissXmlScreen e vice-versa).
;
; Constantes de tela (coordenadas):
;   WIN_XML, WIN_XML_PATH_FORM, WIN_XML_POPUP_SIMNAO,
;   XML_CAMPO_REMESSA, XML_BTN_FATURAMENTO, XML_FORM_*,
;   XML_BTN_NAO — definidas em globals/mv/screens/FfcvScreen.ahk.
;
; Timeouts herdados de FfcvScreen.ahk via RP_FINAL_*/FFCV_FINAL_*.
; ════════════════════════════════════════════════════════════════

; ── Timeouts (ms) ─────────────────────────────────────────────
; Compartilhados com callers XML em RemessaProtocolo.ahk.
; Bases em MVConstants (MV_FIELD_*); aliases preservam callers.
RP_KEY_SETTLE_MS         := MV_KEY_SETTLE_MS
RP_FIELD_FOCUS_SETTLE_MS := MV_FIELD_FOCUS_SETTLE_MS
RP_FIELD_CLEAR_SETTLE_MS := MV_FIELD_CLEAR_SETTLE_MS

RP_FINAL_STABLE_MS         := FFCV_FINAL_STABLE_MS
RP_FINAL_ACTION_TIMEOUT_MS  := FFCV_FINAL_ACTION_TIMEOUT_MS
RP_XML_QUERY_MIN_WAIT_MS   := FFCV_XML_QUERY_MIN_WAIT_MS

; ════════════════════════════════════════════════════════════════
;  HELPERS — click/teclado/modal (movidos de RemessaProtocolo.ahk)
; ════════════════════════════════════════════════════════════════

TissXml_SetTextByClickAt(winTitle, x, y, value) {
    return MV_SetTextByControl(winTitle, "Edit1", value, x, y, true)
}

TissXml_SetTextByClickNoClear(winTitle, x, y, value) {
    return MV_SetTextByControl(winTitle, "Edit1", value, x, y, false)
}

/*
TissXml_ClickBySpec(winTitle, classNN, x, y)
    Delega para a versão canônica MV_ClickBySpec (components/Controls.ahk).
*/
TissXml_ClickBySpec(winTitle, classNN, x, y) {
    return MV_ClickBySpec(winTitle, classNN, x, y)
}

TissXml_WaitXmlQueryReady(timeoutMs := 30000) {
    startedAt := A_TickCount
    stableSince := 0

    Loop {
        ThrowIfAppStopped()
        modal := Dialog_ActiveModalTitle()
        if (modal != "")
            return Map("ok", false, "elapsed", A_TickCount - startedAt, "erro", "Modal apareceu apos consultar a remessa no XML/TISS: " modal)

        minWaitDone := (A_TickCount - startedAt >= RP_XML_QUERY_MIN_WAIT_MS)
        if (minWaitDone
            && _ControlAtReady(WIN_XML, XML_BTN_FATURAMENTO, XML_BTN_FATURAMENTO_X, XML_BTN_FATURAMENTO_Y, 20)
            && A_Cursor != "Wait" && A_Cursor != "AppStarting") {
            if (stableSince = 0)
                stableSince := A_TickCount
            if (A_TickCount - stableSince >= RP_FINAL_STABLE_MS)
                return Map("ok", true, "elapsed", A_TickCount - startedAt, "erro", "")
        } else {
            stableSince := 0
        }

        if (A_TickCount - startedAt >= timeoutMs)
            return Map("ok", false, "elapsed", A_TickCount - startedAt, "erro", "Consulta da remessa no XML/TISS nao estabilizou em " timeoutMs "ms.")

        Sleep MV_POLL_MS
    }
}

TissXml_WaitPathForm(timeoutSecs := 20) {
    startedAt := A_TickCount
    deadline := startedAt + timeoutSecs * 1000

    Loop {
        ThrowIfAppStopped()
        if WinExist(WIN_XML_PATH_FORM)
            return Map("ok", true, "erro", "")

        popup := Dialog_ActiveModalTitle()
        if (popup != "") {
            if TissXml_ClickModalButtonByText(popup, "&OK") {
                MV_Poll(() => !WinExist(MV_CLASS_MODAL_FORMS), MV_TIMEOUT_ACOE)
            } else {
                return Map("ok", false, "erro", "Modal apos Faturamento apareceu, mas nao encontrei botao &OK acessivel.")
            }
        }

        if (A_TickCount >= deadline)
            return Map("ok", false, "erro", "Tela de caminho do arquivo nao apareceu apos " timeoutSecs "s.")

        Sleep MV_POLL_MS
    }
}

/*
TissXml_HandleSaveModals()
    Trata modais de confirmacao que podem aparecer apos Salvar o XML
    (popup Sim/Nao para sobrescrita, &OK informativo, etc).
    @return true = todos modais tratados; false = erro bloqueante.
*/
TissXml_HandleSaveModals() {
    Loop 5 {
        ThrowIfAppStopped()
        if !MV_Poll(() => WinExist(MV_CLASS_MODAL_FORMS), 2) {
            if (A_Index = 1)
                Notify("Nenhum modal imediatamente apos salvar XML; aguardando estabilizacao.")
            if MV_WaitOracleSettled(WIN_XML_PATH_FORM, RP_FINAL_STABLE_MS, 5000)
                return true
            continue
        }

        popup := Dialog_ActiveModalTitle()

        ; Modal de sobrescrita: tem Sim e Nao. Regra: nao sobrescrever.
        if MV_FindButtonByText(popup, "&Sim") && MV_FindButtonByText(popup, "&Nao") {
            if TissXml_ClickModalButtonByText(popup, "&Nao")
                Notify("Modal Sim/Nao respondido com Nao.")
            else
                return false
        } else if MV_FindButtonByText(popup, "&OK") {
            if TissXml_ClickModalButtonByText(popup, "&OK")
                Notify("Modal OK fechado.")
            else
                return false
        } else {
            return false
        }

        if !MV_Poll(() => !WinExist(MV_CLASS_MODAL_FORMS), MV_TIMEOUT_ACOE)
            return false
    }
    return false
}

TissXml_ClickModalButtonByText(winTitle, buttonText) {
    hwnd := MV_FindButtonByText(winTitle, buttonText)
    if !hwnd
        return false
    ControlClick hwnd,,,,, "NA"
    return true
}

; ════════════════════════════════════════════════════════════════
;  Funcoes publicas — extraidas de RemessaProtocolo.ahk
; ════════════════════════════════════════════════════════════════

/*
TissXml_Gerar(numRemessa)
    Gera o arquivo XML TISS para a remessa informada.
    Abre a tela XML/TISS, preenche o numero da remessa, aciona
    Faturamento, espera o formulario de caminho, salva o XML em
    Documentos\XML\<numRemessa>.xml e volta para a tela principal.

    Parametros:
        numRemessa (inteiro) — numero da remessa MovDoc.

    Retorna:
        Map("ok", true, "path", <caminho do arquivo salvo>)
        Map("ok", false, "erro", <mensagem de erro>)

    Nota:
        As coordenadas TISS_* estao marcadas como TODO em FfcvScreen.ahk.
        Esta implementacao usa as constantes de FfcvScreen.ahk; quando
        TissXmlScreen for totalmente mapeado, troque TissXml_SetTextByClick*
        por versoes com ClassNN validados.
*/
TissXml_Gerar(numRemessa) {
    if !Ffcv_AbrirTelaTISS()
        return Map("ok", false, "erro", "Erro: tela XML/TISS nao abriu via Ffcv_AbrirTelaTISS.")

    if !TissXml_SetTextByClickNoClear(WIN_XML, XML_CAMPO_REMESSA_X, XML_CAMPO_REMESSA_Y, numRemessa)
        return Map("ok", false, "erro", "Nao consegui preencher a remessa na tela XML/TISS.")
    Sleep RP_KEY_SETTLE_MS
    Send "{F8}"

    queryReady := TissXml_WaitXmlQueryReady(RP_FINAL_ACTION_TIMEOUT_MS)
    if !queryReady["ok"]
        return Map("ok", false, "erro", "Consulta XML/TISS nao estabilizou: " queryReady["erro"])
    Notify("Consulta XML/TISS estabilizada em " queryReady["elapsed"] "ms.")

    if !TissXml_ClickBySpec(WIN_XML, XML_BTN_FATURAMENTO, XML_BTN_FATURAMENTO_X, XML_BTN_FATURAMENTO_Y)
        return Map("ok", false, "erro", "Nao consegui acionar o botao Faturamento na tela XML/TISS.")

    faturamento := TissXml_WaitPathForm(MV_TIMEOUT_LOAD)
    if !faturamento["ok"]
        return Map("ok", false, "erro", "Formulario de caminho nao abriu apos Faturamento: " faturamento["erro"])

    xmlDir := Config_GetPath("XmlDir")
    xmlPath := xmlDir "\" numRemessa ".xml"

    if !TissXml_SetTextByClickAt(WIN_XML_PATH_FORM, XML_FORM_CAMPO_PATH_X, XML_FORM_CAMPO_PATH_Y, xmlPath)
        return Map("ok", false, "erro", "Nao consegui preencher o campo de caminho do XML.")

    if !MV_WaitOracleSettled(WIN_XML_PATH_FORM, RP_FINAL_STABLE_MS, RP_FINAL_ACTION_TIMEOUT_MS)
        return Map("ok", false, "erro", "Tela de caminho do XML nao estabilizou antes de salvar.")

    if !TissXml_ClickBySpec(WIN_XML_PATH_FORM, XML_FORM_BTN_SALVAR, XML_FORM_BTN_SALVAR_X, XML_FORM_BTN_SALVAR_Y)
        return Map("ok", false, "erro", "Nao consegui acionar o botao Salvar_XML.")

    if !TissXml_HandleSaveModals()
        return Map("ok", false, "erro", "Erro ao tratar modais apos salvar XML.")

    if !MV_WaitOracleSettled(WIN_XML_PATH_FORM, RP_FINAL_STABLE_MS, RP_FINAL_ACTION_TIMEOUT_MS)
        return Map("ok", false, "erro", "Apos salvar o XML, a tela nao estabilizou para voltar.")

    if !TissXml_ClickBySpec(WIN_XML_PATH_FORM, XML_FORM_BTN_VOLTAR, XML_FORM_BTN_VOLTAR_X, XML_FORM_BTN_VOLTAR_Y)
        return Map("ok", false, "erro", "Nao consegui voltar da tela de XML gerado.")

    if !MV_WaitOracleSettled(WIN_XML_PATH_FORM, RP_FINAL_STABLE_MS, RP_FINAL_ACTION_TIMEOUT_MS)
        Notify("Aviso: a tela de XML nao confirmou estabilidade apos Voltar; tentando sair mesmo assim.")

    Send "{Esc}"
    Sleep MV_DELAY_INPUT
    return Map("ok", true, "path", xmlPath)
}
