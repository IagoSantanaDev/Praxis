; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_ScriptDir%\_mv_control_probe.ahk

; Configuração conservadora para computadores rápidos e lentos.
; Não usar prioridade alta: o Oracle Forms precisa reagir aos eventos de teclado/mouse.
ListLines(false)
SetKeyDelay(10, 10)
SetMouseDelay(-1)
SetDefaultMouseSpeed(0)
SetControlDelay(-1)

; Timeouts de sincronização. O teste não deve despejar inputs sem confirmar
; que o Oracle Forms terminou de reagir ao evento anterior.
MV_POLL_MS := 100
FIELD_FOCUS_SETTLE_MS := 100
FIELD_CLEAR_SETTLE_MS := 100
KEY_SETTLE_MS := 100
ORACLE_STABLE_MS := 800
ACTION_TIMEOUT_MS := 30000
XML_QUERY_MIN_WAIT_MS := 1200

; TESTE 12 - Continuação: entregar/fechar remessa + gerar XML
;
; Ponto de partida esperado:
; - FFCV aberto na tela Manutenção de Remessas, com a remessa já criada/buscada pelo macro 11.
;
; Fluxo testado:
; 1) Clicar "5 - Entregar Rem." na Manutenção de Remessas.
; 2) Na tela Entrega de Remessas, ler número da remessa, preencher datas, marcar fechar contas e confirmar.
; 3) Confirmar modal com "Não" quando solicitado.
; 4) Sair/voltar e abrir Monitoração de Faturamento - TISS.
; 5) Preencher remessa, F8, clicar "1 Faturamento".
; 6) Na tela XML gerado, preencher caminho, salvar, responder "Não" e voltar.
;
; Segurança:
; - DO_ACTION := false só localiza controles da tela atual.
; - Para executar, coloque DO_ACTION := true e ligue uma etapa por vez.
; - Não use Screen x/y; todos os pontos abaixo são Client do Window Spy.

; ════════════════════════════════════════════════════════════════
;  FLAGS DE SEGURANÇA - ligue uma etapa por vez
; ════════════════════════════════════════════════════════════════

DO_ACTION             := true
DO_OPEN_ENTREGA       := true ; clica "5 - Entregar Rem." na Manutenção de Remessas
DO_CONFIRM_ENTREGA    := true ; preenche datas, checkbox e confirma entrega
DO_OPEN_XML_TISS      := true ; abre Lançamentos -> Monitoração de Faturamento - TISS
DO_GERAR_XML          := true ; preenche remessa, gera XML e volta

; ════════════════════════════════════════════════════════════════
;  DADOS DE TESTE
; ════════════════════════════════════════════════════════════════

TEST_REMESSA := "" ; se vazio, tenta ler da tela Entrega de Remessas após abrir
TEST_DATA_ENTREGA := FormatTime(, "26/05/2026")
TEST_DATA_VENCIMENTO := FormatTime(, "10/07/2026")
TEST_XML_DIR := A_ScriptDir "\XML_TESTE"
ENTREGA_SAIR_ATALHO := "^q"

WIN_FFCV := "MV2000i - Faturamento ahk_exe ifrun60.EXE"
WIN_ENTREGA := "Cadastro: Faturas e Remessas"
WIN_RELATORIO := "Relatório de Atendimentos da Remessa ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"
WIN_XML := "Monitoração de Faturamento - TISS"
WIN_XML_FORM := "MV2000i - Faturamento - [WIN_PRINCIPAL]"
WIN_MODAL := "Mensagem ao Usuário do MV 2000 ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"
WIN_ANY_MODAL := "ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"

; Botão na tela Manutenção de Remessas.
BTN_ENTREGAR_CLASS := "Button6"
BTN_ENTREGAR_X     := 464
BTN_ENTREGAR_Y     := 458

; Tela Entrega de Remessas.
DATAS_CAMPO_REMESSA_X := 59
DATAS_CAMPO_REMESSA_Y := 101
DATAS_CAMPO_ENTREGA_X := 146
DATAS_CAMPO_ENTREGA_Y := 101
DATAS_CAMPO_VENCIMENTO_X := 244
DATAS_CAMPO_VENCIMENTO_Y := 227
DATAS_CHECKBOX_CLASS := "Button3"
DATAS_CHECKBOX_X     := 541
DATAS_CHECKBOX_Y     := 242
DATAS_BTN_CONFIRMAR_CLASS := "Button10"
DATAS_BTN_CONFIRMAR_X     := 30
DATAS_BTN_CONFIRMAR_Y     := 469

; Tela Monitoração de Faturamento - TISS.
XML_CAMPO_REMESSA_X := 272
XML_CAMPO_REMESSA_Y := 89
XML_BTN_FATURAMENTO_CLASS := "Button7"
XML_BTN_FATURAMENTO_X     := 12
XML_BTN_FATURAMENTO_Y     := 446

; Tela XML gerado.
XML_FORM_CAMPO_PATH_X := 267
XML_FORM_CAMPO_PATH_Y := 467
XML_FORM_BTN_SALVAR_CLASS := "Button4"
XML_FORM_BTN_SALVAR_X     := 623
XML_FORM_BTN_SALVAR_Y     := 471
XML_FORM_BTN_VOLTAR_CLASS := "Button7"
XML_FORM_BTN_VOLTAR_X     := 731
XML_FORM_BTN_VOLTAR_Y     := 470

; Modais.
MODAL_NAO_CLASS := "Button2"
MODAL_OK_CLASS  := "Button1"

report := "SUÍTE: Continuação FFCV - fechar remessa + gerar XML`n"
        . "DO_ACTION=" DO_ACTION " DO_OPEN_ENTREGA=" DO_OPEN_ENTREGA " DO_CONFIRM_ENTREGA=" DO_CONFIRM_ENTREGA " DO_OPEN_XML_TISS=" DO_OPEN_XML_TISS " DO_GERAR_XML=" DO_GERAR_XML "`n"
        . "TEST_REMESSA=" (TEST_REMESSA = "" ? "(ler da tela)" : TEST_REMESSA) " TEST_DATA_ENTREGA=" TEST_DATA_ENTREGA " TEST_DATA_VENCIMENTO=" TEST_DATA_VENCIMENTO "`n"
        . "TEST_XML_DIR=" TEST_XML_DIR "`n`n"

if !DO_ACTION {
    report .= "Modo seguro: localizando controles conhecidos conforme a tela aberta.`n"

    if WinExist(WIN_FFCV) {
        report .= "`n[Manutenção de Remessas]`n"
        report .= MV_Test_RunOne(WIN_FFCV, Map("name", "BTN_ENTREGAR", "class", BTN_ENTREGAR_CLASS, "x", BTN_ENTREGAR_X, "y", BTN_ENTREGAR_Y, "action", "locate"), false, 20) "`n"
    }

    if WinExist(WIN_ENTREGA) {
        report .= "`n[Entrega de Remessas]`n"
        report .= MV_Test_RunOne(WIN_ENTREGA, Map("name", "DATAS_CAMPO_REMESSA", "class", "Edit5", "x", DATAS_CAMPO_REMESSA_X, "y", DATAS_CAMPO_REMESSA_Y, "action", "locate"), false, 20) "`n"
        report .= MV_Test_RunOne(WIN_ENTREGA, Map("name", "DATAS_CAMPO_ENTREGA", "class", "Edit1", "x", DATAS_CAMPO_ENTREGA_X, "y", DATAS_CAMPO_ENTREGA_Y, "action", "locate"), false, 20) "`n"
        report .= MV_Test_RunOne(WIN_ENTREGA, Map("name", "DATAS_CAMPO_VENCIMENTO", "class", "Edit1", "x", DATAS_CAMPO_VENCIMENTO_X, "y", DATAS_CAMPO_VENCIMENTO_Y, "action", "locate"), false, 20) "`n"
        report .= MV_Test_RunOne(WIN_ENTREGA, Map("name", "DATAS_CHECKBOX", "class", DATAS_CHECKBOX_CLASS, "x", DATAS_CHECKBOX_X, "y", DATAS_CHECKBOX_Y, "action", "locate"), false, 20) "`n"
        report .= MV_Test_RunOne(WIN_ENTREGA, Map("name", "DATAS_BTN_CONFIRMAR", "class", DATAS_BTN_CONFIRMAR_CLASS, "x", DATAS_BTN_CONFIRMAR_X, "y", DATAS_BTN_CONFIRMAR_Y, "action", "locate"), false, 20) "`n"
    }

    if WinExist(WIN_XML) {
        report .= "`n[Monitoração TISS]`n"
        report .= MV_Test_RunOne(WIN_XML, Map("name", "XML_CAMPO_REMESSA", "class", "Edit1", "x", XML_CAMPO_REMESSA_X, "y", XML_CAMPO_REMESSA_Y, "action", "locate"), false, 20) "`n"
        report .= MV_Test_RunOne(WIN_XML, Map("name", "XML_BTN_FATURAMENTO", "class", XML_BTN_FATURAMENTO_CLASS, "x", XML_BTN_FATURAMENTO_X, "y", XML_BTN_FATURAMENTO_Y, "action", "locate"), false, 20) "`n"
    }

    if WinExist(WIN_XML_FORM) {
        report .= "`n[XML gerado]`n"
        report .= MV_Test_RunOne(WIN_XML_FORM, Map("name", "XML_FORM_CAMPO_PATH", "class", "Edit1", "x", XML_FORM_CAMPO_PATH_X, "y", XML_FORM_CAMPO_PATH_Y, "action", "locate"), false, 20) "`n"
        report .= MV_Test_RunOne(WIN_XML_FORM, Map("name", "XML_FORM_BTN_SALVAR", "class", XML_FORM_BTN_SALVAR_CLASS, "x", XML_FORM_BTN_SALVAR_X, "y", XML_FORM_BTN_SALVAR_Y, "action", "locate"), false, 20) "`n"
        report .= MV_Test_RunOne(WIN_XML_FORM, Map("name", "XML_FORM_BTN_VOLTAR", "class", XML_FORM_BTN_VOLTAR_CLASS, "x", XML_FORM_BTN_VOLTAR_X, "y", XML_FORM_BTN_VOLTAR_Y, "action", "locate"), false, 20) "`n"
    }

    report .= "`nPara executar o fluxo, coloque DO_ACTION := true e ligue etapas uma por vez.`n"
    MV_Test_ShowReport(report)
    ExitApp
}

remessaAtual := Trim(TEST_REMESSA)

if DO_OPEN_ENTREGA {
    report .= "▶️ Abrindo Entrega de Remessas...`n"
    if !EnsureWindowActive(WIN_FFCV) {
        report .= "❌ FFCV não ficou ativa antes de clicar em Entregar Remessa.`n"
        MV_Test_ShowReport(report)
        ExitApp
    }

    startedAt := A_TickCount
    if !ClickBySpec(WIN_FFCV, BTN_ENTREGAR_CLASS, BTN_ENTREGAR_X, BTN_ENTREGAR_Y) {
        report .= "❌ Não consegui clicar em Entregar Remessa.`n"
        MV_Test_ShowReport(report)
        ExitApp
    }
    if !T_Poll(() => WinExist(WIN_ENTREGA), 10) {
        report .= "❌ Tela Entrega de Remessas não apareceu.`n"
        MV_Test_ShowReport(report)
        ExitApp
    }
    if !WaitOracleSettled(WIN_ENTREGA, ORACLE_STABLE_MS, ACTION_TIMEOUT_MS) {
        report .= "❌ Tela Entrega de Remessas apareceu, mas não estabilizou antes do preenchimento.`n"
        MV_Test_ShowReport(report)
        ExitApp
    }
    report .= "✅ Tela Entrega de Remessas detectada e estável em " (A_TickCount - startedAt) "ms.`n"
}

if DO_CONFIRM_ENTREGA {
    result := ConfirmarEntrega(remessaAtual)
    report .= result["report"]
    if !result["ok"] {
        MV_Test_ShowReport(report)
        ExitApp
    }
    remessaAtual := result["remessa"]
}

if DO_OPEN_XML_TISS {
    report .= "`n▶️ Abrindo Monitoração de Faturamento - TISS...`n"
    if !EnsureWindowActive(WIN_FFCV) {
        report .= "❌ FFCV não ficou ativa antes de abrir XML/TISS.`n"
        MV_Test_ShowReport(report)
        ExitApp
    }
    startedAt := A_TickCount
    Send "{Alt down}lt{Alt up}{Enter}"
    if !T_Poll(() => WinExist(WIN_XML), 20) {
        report .= "❌ Tela XML/TISS não apareceu.`n"
        MV_Test_ShowReport(report)
        ExitApp
    }
    if !WaitOracleSettled(WIN_XML, ORACLE_STABLE_MS, ACTION_TIMEOUT_MS) {
        report .= "❌ Tela XML/TISS apareceu, mas não estabilizou antes da consulta.`n"
        MV_Test_ShowReport(report)
        ExitApp
    }
    report .= "✅ Tela XML/TISS detectada e estável em " (A_TickCount - startedAt) "ms.`n"
}

if DO_GERAR_XML {
    if (remessaAtual = "")
        remessaAtual := Trim(TEST_REMESSA)
    if (remessaAtual = "") {
        report .= "❌ Não há número de remessa. Preencha TEST_REMESSA ou execute DO_CONFIRM_ENTREGA antes.`n"
        MV_Test_ShowReport(report)
        ExitApp
    }
    report .= GerarXML(remessaAtual)
}

MV_Test_ShowReport(report)

ConfirmarEntrega(remessaEntrada) {
    msg := "`n▶️ Confirmando entrega/fechamento...`n"
    if !WinExist(WIN_ENTREGA)
        return Map("ok", false, "report", msg "❌ Tela Entrega de Remessas não está aberta.`n", "remessa", remessaEntrada)

    datas := PreencherDatasEntregaPorTeclado(remessaEntrada)
    msg .= datas["report"]
    if !datas["ok"]
        return Map("ok", false, "report", msg, "remessa", datas["remessa"])

    remessa := datas["remessa"]

    checked := ControlCheckedAt(WIN_ENTREGA, DATAS_CHECKBOX_CLASS, DATAS_CHECKBOX_X, DATAS_CHECKBOX_Y)
    if (checked = 0) {
        if !ClickBySpec(WIN_ENTREGA, DATAS_CHECKBOX_CLASS, DATAS_CHECKBOX_X, DATAS_CHECKBOX_Y)
            return Map("ok", false, "report", msg "❌ Não consegui marcar checkbox Fechar contas.`n", "remessa", remessa)
        if !T_Poll(() => ControlCheckedAt(WIN_ENTREGA, DATAS_CHECKBOX_CLASS, DATAS_CHECKBOX_X, DATAS_CHECKBOX_Y) = 1, 5)
            return Map("ok", false, "report", msg "❌ Checkbox Fechar contas foi clicado, mas não ficou marcado em tempo.`n", "remessa", remessa)
        msg .= "✅ Checkbox Fechar contas marcado e confirmado.`n"
    } else if (checked = 1) {
        msg .= "✅ Checkbox Fechar contas já estava marcado.`n"
    } else {
        return Map("ok", false, "report", msg "❌ Não consegui ler estado do checkbox Fechar contas.`n", "remessa", remessa)
    }

    if !WaitOracleSettled(WIN_ENTREGA, ORACLE_STABLE_MS, ACTION_TIMEOUT_MS)
        return Map("ok", false, "report", msg "❌ Tela Entrega de Remessas não estabilizou antes de confirmar.`n", "remessa", remessa)

    if !ClickBySpec(WIN_ENTREGA, DATAS_BTN_CONFIRMAR_CLASS, DATAS_BTN_CONFIRMAR_X, DATAS_BTN_CONFIRMAR_Y)
        return Map("ok", false, "report", msg "❌ Não consegui clicar Confirmar Entrega.`n", "remessa", remessa)
    msg .= "✅ Confirmar Entrega clicado; aguardando modal de confirmação.`n"

    if !T_Poll(() => WinExist(WIN_MODAL) || WinExist(WIN_ANY_MODAL), 10)
        return Map("ok", false, "report", msg "❌ Modal de confirmação não apareceu.`n", "remessa", remessa)

    modal := WinExist(WIN_MODAL) ? WIN_MODAL : WIN_ANY_MODAL
    if ClickFirstByClass(modal, MODAL_NAO_CLASS)
        msg .= "✅ Modal confirmado com Não (Button2).`n"
    else
        return Map("ok", false, "report", msg "❌ Não consegui clicar Não no modal.`n", "remessa", remessa)

    if !WaitConfirmationModalTransition(modal, ACTION_TIMEOUT_MS)
        return Map("ok", false, "report", msg "❌ Modal de confirmação foi clicado, mas não fechou nem avançou para o relatório em tempo.`n", "remessa", remessa)

    if T_Poll(() => WinExist(WIN_RELATORIO), 10) {
        if !EnsureWindowActive(WIN_RELATORIO)
            return Map("ok", false, "report", msg "❌ Relatório de Atendimentos apareceu, mas não ficou ativo.`n", "remessa", remessa)
        if !WaitOracleSettled(WIN_RELATORIO, ORACLE_STABLE_MS, ACTION_TIMEOUT_MS)
            return Map("ok", false, "report", msg "❌ Relatório de Atendimentos apareceu, mas não estabilizou antes do Enter.`n", "remessa", remessa)
        Send "{Enter}"
        if !WaitWindowGone(WIN_RELATORIO, ACTION_TIMEOUT_MS)
            return Map("ok", false, "report", msg "❌ Enter enviado no relatório, mas a janela não fechou em tempo.`n", "remessa", remessa)
        msg .= "✅ Relatório de Atendimentos confirmado e fechado.`n"
    } else {
        msg .= "⚠️ Relatório de Atendimentos não apareceu após confirmação.`n"
    }

    if WinExist(WIN_ENTREGA) {
        if !WaitOracleSettled(WIN_ENTREGA, ORACLE_STABLE_MS, ACTION_TIMEOUT_MS)
            return Map("ok", false, "report", msg "❌ Tela Entrega de Remessas não estabilizou para saída.`n", "remessa", remessa)
        sair := SairTelaEntregaPendente()
        msg .= sair["report"]
        if !sair["ok"]
            return Map("ok", false, "report", msg "⚠️ Fluxo pausado nesta tela até mapear o atalho correto de saída da Entrega de Remessas.`n", "remessa", remessa)
        if !WaitOracleSettled(WIN_FFCV, ORACLE_STABLE_MS, ACTION_TIMEOUT_MS)
            return Map("ok", false, "report", msg "❌ FFCV não estabilizou após sair da Entrega de Remessas.`n", "remessa", remessa)
    }

    return Map("ok", true, "report", msg, "remessa", remessa)
}

SairTelaEntregaPendente() {
    if (Trim(ENTREGA_SAIR_ATALHO) = "")
        return Map("ok", false, "report", "⚠️ Atalho para sair da tela Entrega de Remessas ainda não mapeado. Esc foi removido porque não funciona. Configure ENTREGA_SAIR_ATALHO quando descobrir.`n")

    if !EnsureWindowActive(WIN_ENTREGA)
        return Map("ok", false, "report", "❌ Tela Entrega de Remessas não ficou ativa para enviar atalho de saída.`n")

    Send ENTREGA_SAIR_ATALHO
    ok := WaitWindowGone(WIN_ENTREGA, ACTION_TIMEOUT_MS)
    detail := ok ? " e janela fechada.`n" : "; janela não fechou em tempo.`n"
    return Map("ok", ok, "report", "▶️ Atalho de saída da Entrega enviado: " ENTREGA_SAIR_ATALHO detail)
}

PreencherDatasEntregaPorTeclado(remessaEntrada) {
    msg := ""
    remessa := Trim(remessaEntrada)

    if !EnsureWindowActive(WIN_ENTREGA)
        return Map("ok", false, "report", "❌ Tela Entrega de Remessas não ficou ativa para preencher datas.`n", "remessa", remessa)

    ; Ancora o foco no campo Data de Entrega para que Shift+Tab sempre volte ao campo Remessa.
    CoordMode("Mouse", "Client")
    Click(DATAS_CAMPO_ENTREGA_X + 15, DATAS_CAMPO_ENTREGA_Y + 8, 1)
    WaitAfterInput()

    ; Regra validada para Entrega de Remessas:
    ; Shift+Tab vai para o campo da remessa com o conteúdo selecionado; copiar.
    ; Tab volta para Data de Entrega com o conteúdo selecionado; digitar data e Enter.
    ; Enter leva para Data de Vencimento; digitar vencimento. Não usar Ctrl+A.
    Send("+{Tab}")
    WaitAfterInput()

    remessaTela := CopySelectedNumericText(600)
    if (remessaTela != "") {
        remessa := remessaTela
        msg .= "✅ Remessa copiada via Shift+Tab: " remessa "`n"
    } else if (remessa != "") {
        msg .= "⚠️ Não consegui copiar remessa via Shift+Tab; usando TEST_REMESSA: " remessa "`n"
    } else {
        return Map("ok", false, "report", "❌ Não consegui copiar o número da remessa via Shift+Tab.`n", "remessa", "")
    }

    Send("{Tab}")
    WaitAfterInput()
    SendText(TEST_DATA_ENTREGA)
    WaitAfterInput()
    Send("{Enter}")
    WaitAfterInput()
    msg .= "✅ Data da Entrega enviada por teclado: " TEST_DATA_ENTREGA "`n"

    SendText(TEST_DATA_VENCIMENTO)
    WaitAfterInput()
    msg .= "✅ Data Prevista enviada por teclado: " TEST_DATA_VENCIMENTO "`n"

    return Map("ok", true, "report", msg, "remessa", remessa)
}

CopySelectedNumericText(timeoutMs := 600) {
    A_Clipboard := ""
    Send("^c")
    if !ClipWait(timeoutMs / 1000)
        return ""

    value := Trim(A_Clipboard)
    if RegExMatch(value, "\d+", &m)
        return m[0]
    return ""
}

GerarXML(remessa) {
    msg := "`n▶️ Gerando XML da remessa " remessa "...`n"
    if !WinExist(WIN_XML)
        return msg "❌ Tela XML/TISS não está aberta.`n"

    if !SetTextAtNoClear(WIN_XML, XML_CAMPO_REMESSA_X, XML_CAMPO_REMESSA_Y, remessa)
        return msg "❌ Não consegui preencher remessa na tela XML/TISS.`n"
    msg .= "✅ Remessa digitada na tela XML/TISS.`n"

    Send "{F8}"
    queryReady := WaitXmlQueryReady(ACTION_TIMEOUT_MS)
    if !queryReady["ok"]
        return msg "❌ " queryReady["erro"] "`n"
    msg .= "✅ F8 enviado; consulta XML/TISS estabilizada em " queryReady["elapsed"] "ms.`n"

    if !ClickBySpec(WIN_XML, XML_BTN_FATURAMENTO_CLASS, XML_BTN_FATURAMENTO_X, XML_BTN_FATURAMENTO_Y)
        return msg "❌ Não consegui clicar em 1 Faturamento.`n"
    msg .= "✅ Botão 1 Faturamento clicado.`n"

    faturamento := WaitXmlFormOrModal(20)
    msg .= faturamento["report"]
    if !faturamento["ok"]
        return msg

    if !DirExist(TEST_XML_DIR)
        DirCreate TEST_XML_DIR
    xmlPath := TEST_XML_DIR "\" remessa ".xml"

    if !SetEditAt(WIN_XML_FORM, XML_FORM_CAMPO_PATH_X, XML_FORM_CAMPO_PATH_Y, xmlPath)
        return msg "❌ Não consegui preencher caminho do XML.`n"
    if !WaitOracleSettled(WIN_XML_FORM, ORACLE_STABLE_MS, ACTION_TIMEOUT_MS)
        return msg "❌ Tela XML gerado não estabilizou após preencher caminho.`n"
    msg .= "✅ Caminho do XML preenchido e tela estável.`n"

    if !ClickBySpec(WIN_XML_FORM, XML_FORM_BTN_SALVAR_CLASS, XML_FORM_BTN_SALVAR_X, XML_FORM_BTN_SALVAR_Y)
        return msg "❌ Não consegui clicar Salvar/Visualizar XML.`n"
    msg .= "✅ Salvar/Visualizar XML clicado.`n"

    msg .= HandleXmlSaveModals()

    if !WaitOracleSettled(WIN_XML_FORM, ORACLE_STABLE_MS, ACTION_TIMEOUT_MS)
        return msg "❌ Tela XML gerado não estabilizou antes de voltar.`n"

    if ClickBySpec(WIN_XML_FORM, XML_FORM_BTN_VOLTAR_CLASS, XML_FORM_BTN_VOLTAR_X, XML_FORM_BTN_VOLTAR_Y) {
        WaitAfterInput()
        msg .= "✅ Voltar clicado na tela XML gerado.`n"
    } else
        msg .= "⚠️ Não consegui clicar Voltar na tela XML gerado.`n"

    return msg
}

SetTextAtNoClear(winTitle, x, y, value) {
    if !EnsureWindowActive(winTitle)
        return false

    try {
        CoordMode("Mouse", "Client")
        Click(x + 15, y + 8, 1)
        Sleep FIELD_FOCUS_SETTLE_MS
        SendText value
        Sleep KEY_SETTLE_MS
        return true
    } catch {
        return false
    }
}

WaitXmlFormOrModal(timeoutSecs := 20) {
    startedAt := A_TickCount
    deadline := startedAt + timeoutSecs * 1000

    Loop {
        if WinExist(WIN_XML_FORM) {
            if WaitOracleSettled(WIN_XML_FORM, ORACLE_STABLE_MS, ACTION_TIMEOUT_MS)
                return Map("ok", true, "report", "✅ Tela XML gerado detectada e estável em " (A_TickCount - startedAt) "ms.`n")
            return Map("ok", false, "report", "❌ Tela XML gerado apareceu, mas não estabilizou em tempo.`n")
        }

        modal := ActiveModalTitle()
        if (modal != "") {
            if ClickModalButtonByText(modal, "&OK") {
                ; Modal pós-1 Faturamento é continuável. Não depender do texto desenhado.
                if !WaitModalGone(ACTION_TIMEOUT_MS)
                    return Map("ok", false, "report", "❌ Modal após 1 Faturamento foi fechado, mas não sumiu em tempo.`n")
            } else {
                return Map("ok", false, "report", "❌ Modal após 1 Faturamento apareceu, mas não encontrei botão &OK acessível.`n")
            }
        }

        if (A_TickCount >= deadline)
            return Map("ok", false, "report", "❌ Tela XML gerado não apareceu após tratar possíveis modais em " timeoutSecs "s.`n")

        Sleep MV_POLL_MS
    }
}

HandleXmlSaveModals() {
    msg := ""
    Loop 5 {
        if !T_Poll(() => WinExist(WIN_ANY_MODAL), 2) {
            if (A_Index = 1)
                msg .= "ℹ️ Nenhum modal apareceu imediatamente após salvar XML; aguardando estabilização da tela.`n"
            if WaitOracleSettled(WIN_XML_FORM, ORACLE_STABLE_MS, 5000)
                return msg
            continue
        }

        modal := ActiveModalTitle()

        ; Modal de sobrescrita: tem Sim e Não. Regra atual: não sobrescrever.
        if ModalHasButton(modal, "&Sim") && ModalHasButton(modal, "&Não") {
            if ClickModalButtonByText(modal, "&Não")
                msg .= "✅ Modal com Sim/Não respondido com Não.`n"
            else
                msg .= "⚠️ Modal com Sim/Não apareceu, mas não consegui clicar Não.`n"
        } else if ModalHasButton(modal, "&OK") {
            if ClickModalButtonByText(modal, "&OK")
                msg .= "✅ Modal informativo do XML fechado com OK.`n"
            else
                msg .= "⚠️ Modal com OK apareceu, mas não consegui clicar OK.`n"
        } else {
            msg .= "⚠️ Modal do XML apareceu, mas não encontrei botão seguro (&Não ou &OK).`n"
            return msg
        }

        if !WaitModalGone(ACTION_TIMEOUT_MS) {
            msg .= "⚠️ Modal do XML foi acionado, mas não fechou em tempo.`n"
            return msg
        }
    }
    return msg "⚠️ XML não estabilizou após salvar e tratar modais.`n"
}

ActiveModalTitle() {
    return WinExist(WIN_ANY_MODAL) ? WIN_ANY_MODAL : ""
}

SafeWinGetText(winTitle) {
    try text := WinGetText(winTitle)
    catch as e
        return "<erro WinGetText: " e.Message ">"
    return Trim(text)
}

ClickModalButtonByText(winTitle, buttonText) {
    try hwnds := WinGetControlsHwnd(winTitle)
    catch
        return false

    for hwnd in hwnds {
        try ctrlClass := ControlGetClassNN(hwnd)
        catch
            continue
        if (SubStr(ctrlClass, 1, 6) != "Button")
            continue
        try text := ControlGetText(hwnd)
        catch
            continue
        if (text = buttonText) {
            ControlClick hwnd,,,,, "NA"
            return true
        }
    }
    return false
}

ModalHasButton(winTitle, buttonText) {
    try hwnds := WinGetControlsHwnd(winTitle)
    catch
        return false

    for hwnd in hwnds {
        try ctrlClass := ControlGetClassNN(hwnd)
        catch
            continue
        if (SubStr(ctrlClass, 1, 6) != "Button")
            continue
        try text := ControlGetText(hwnd)
        catch
            continue
        if (text = buttonText)
            return true
    }
    return false
}

EnsureWindowActive(winTitle, timeoutSecs := 3) {
    if !WinExist(winTitle)
        return false

    WinActivate winTitle
    return WinWaitActive(winTitle,, timeoutSecs) != 0
}

SetEditAt(winTitle, x, y, value) {
    if !EnsureWindowActive(winTitle)
        return false

    try {
        CoordMode("Mouse", "Client")
        Click(x + 15, y + 8, 1)
        Sleep FIELD_FOCUS_SETTLE_MS
        Send("{Home}{Shift down}{End}{Shift up}{Backspace}")
        Sleep FIELD_CLEAR_SETTLE_MS
        SendText value
        Sleep KEY_SETTLE_MS
        return true
    } catch {
        return false
    }
}

ReadEditAt(winTitle, x, y, expectedPattern := "") {
    hwnd := FindEditByClientPoint(winTitle, x, y, 20)
    if !hwnd
        return ""
    try text := Trim(ControlGetText(hwnd))
    catch
        return ""
    if (expectedPattern != "" && !RegExMatch(text, expectedPattern))
        return ""
    return text
}

FindEditByClientPoint(winTitle, targetX, targetY, tolerance := 20) {
    try hwnds := WinGetControlsHwnd(winTitle)
    catch
        return 0

    bestHwnd := 0
    bestDist := 999999

    for hwnd in hwnds {
        try ctrlClass := ControlGetClassNN(hwnd)
        catch
            continue

        if (SubStr(ctrlClass, 1, 4) != "Edit")
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

    return (bestHwnd && bestDist <= tolerance) ? bestHwnd : 0
}

ControlCheckedAt(winTitle, classNN, x, y) {
    found := MV_Test_FindControlByClientPoint(winTitle, classNN, x + 0, y + 0, 20)
    hwnd := found.Get("hwnd", 0)
    if !hwnd
        return ""
    try return ControlGetChecked(hwnd)
    catch
        return ""
}

ClickBySpec(winTitle, classNN, x, y) {
    found := MV_Test_FindControlByClientPoint(winTitle, classNN, x + 0, y + 0, 20)
    hwnd := found.Get("hwnd", 0)
    if !hwnd
        return false
    try {
        ControlClick hwnd,,,,, "NA"
        return true
    } catch {
        return false
    }
}

ClickFirstByClass(winTitle, classNN) {
    try hwnds := WinGetControlsHwnd(winTitle)
    catch
        return false

    for hwnd in hwnds {
        try ctrlClass := ControlGetClassNN(hwnd)
        catch
            continue
        if (ctrlClass = classNN) {
            ControlClick hwnd,,,,, "NA"
            return true
        }
    }
    return false
}

WaitAfterInput() {
    Sleep KEY_SETTLE_MS
    return T_Poll(() => ActiveModalTitle() = "" && A_Cursor != "Wait" && A_Cursor != "AppStarting", 3)
}

WaitConfirmationModalTransition(clickedModal, timeoutMs := 30000) {
    startedAt := A_TickCount
    Loop {
        if WinExist(WIN_RELATORIO)
            return true
        if (clickedModal != WIN_ANY_MODAL && !WinExist(clickedModal))
            return true
        if (clickedModal = WIN_ANY_MODAL && ActiveModalTitle() = "")
            return true
        if (A_TickCount - startedAt >= timeoutMs)
            return false
        Sleep MV_POLL_MS
    }
}

WaitModalGone(timeoutMs := 30000) {
    startedAt := A_TickCount
    Loop {
        if (ActiveModalTitle() = "")
            return true
        if (A_TickCount - startedAt >= timeoutMs)
            return false
        Sleep MV_POLL_MS
    }
}

WaitWindowGone(winTitle, timeoutMs := 30000) {
    startedAt := A_TickCount
    Loop {
        if !WinExist(winTitle) {
            Sleep KEY_SETTLE_MS
            return true
        }
        if (A_TickCount - startedAt >= timeoutMs)
            return false
        Sleep MV_POLL_MS
    }
}

WaitOracleSettled(winTitle, stableMs := 800, timeoutMs := 30000) {
    startedAt := A_TickCount
    stableSince := 0
    lastCount := -1

    Loop {
        modalClear := (ActiveModalTitle() = "")
        cursorReady := (A_Cursor != "Wait" && A_Cursor != "AppStarting")
        exists := WinExist(winTitle)
        count := -1

        if exists {
            try hwnds := WinGetControlsHwnd(winTitle)
            catch
                hwnds := []
            count := hwnds.Length
        }

        if (exists && modalClear && cursorReady && count = lastCount) {
            if (stableSince = 0)
                stableSince := A_TickCount
            if (A_TickCount - stableSince >= stableMs)
                return true
        } else {
            stableSince := 0
            lastCount := count
        }

        if (A_TickCount - startedAt >= timeoutMs)
            return false

        Sleep MV_POLL_MS
    }
}

ControlAtReady(winTitle, classNN, clientX, clientY, tolerance := 20) {
    found := MV_Test_FindControlByClientPoint(winTitle, classNN, clientX + 0, clientY + 0, tolerance)
    hwnd := found.Get("hwnd", 0)
    if !hwnd
        return false
    try return ControlGetEnabled(hwnd)
    catch
        return true
}

WaitXmlQueryReady(timeoutMs := 30000) {
    startedAt := A_TickCount
    stableSince := 0

    Loop {
        modal := ActiveModalTitle()
        if (modal != "")
            return Map("ok", false, "elapsed", A_TickCount - startedAt, "erro", "Modal apareceu após consultar a remessa no XML/TISS: " SafeWinGetText(modal))

        minWaitDone := (A_TickCount - startedAt >= XML_QUERY_MIN_WAIT_MS)
        if (minWaitDone
            && ControlAtReady(WIN_XML, XML_BTN_FATURAMENTO_CLASS, XML_BTN_FATURAMENTO_X, XML_BTN_FATURAMENTO_Y, 20)
            && A_Cursor != "Wait" && A_Cursor != "AppStarting") {
            if (stableSince = 0)
                stableSince := A_TickCount
            if (A_TickCount - stableSince >= ORACLE_STABLE_MS)
                return Map("ok", true, "elapsed", A_TickCount - startedAt, "erro", "")
        } else {
            stableSince := 0
        }

        if (A_TickCount - startedAt >= timeoutMs)
            return Map("ok", false, "elapsed", A_TickCount - startedAt, "erro", "Consulta da remessa no XML/TISS não estabilizou em " timeoutMs "ms.")

        Sleep MV_POLL_MS
    }
}

T_Poll(condFn, timeoutSecs) {
    deadline := A_TickCount + timeoutSecs * 1000
    Loop {
        if condFn()
            return true
        if A_TickCount > deadline
            return false
        Sleep MV_POLL_MS
    }
}
