; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug
#Include %A_LineFile%\..\..\MVSession.ahk
#Include %A_LineFile%\..\..\FFCV_ErrorTemplates.ahk
#Include %A_LineFile%\..\..\components\Popups.ahk
#Include %A_LineFile%\..\..\components\Dialogs.ahk
#Include %A_LineFile%\..\FfcvContaPopup.ahk

; ════════════════════════════════════════════════════════════════
;  FFCV SCREEN — MANUTENÇÃO DE REMESSA / FECHAMENTO DE REMESSAS
; ════════════════════════════════════════════════════════════════
;
; Encapsula toda lógica de automação da tela Faturamento / Manutenção
; de Remessa e suas subtelas do sistema MV 2000i.
;
; Responsabilidades:
;   - Abrir Manutenção de Remessa via atalho validado (Alt+lm Enter).
;   - Carregar convênio via F7 + número + F8.
;   - Criar ou selecionar remessa existente.
;   - Inserir contas via popup "Informações da Conta".
;   - Fechar remessa e preencher datas de entrega/vencimento.
;   - Imprimir relatório de atendimentos.
;   - Abrir tela XML/TISS, consultar remessa, gerar XML.
;
; Notas de automação:
;   - Oracle Forms renumera EditN conforme estado da tela e quantidade
;     de remessas do convênio. Não usar EditN como contrato — usar
;     fluxo de teclado validado (F7/F8/F6/F10/Tab).
;   - O popup "Informações da Conta" não abre WinTitle próprio; detectar
;     pelo painel ui60Drawn W323 dentro da janela principal FFCV.
;   - Modais Oracle Forms não expõem mensagem pelo Window Spy/WinGetText.
;     A classificação confiável vem do OCR local ou do fluxo de popup.
; ════════════════════════════════════════════════════════════════

; ── Janelas ───────────────────────────────────────────────────
; MV_WIN_FFCV_ANY / MV_WIN_FFCV_REMESSA já existem em MVConstants.ahk.
; Usar diretamente nos callers; manter refs locais para compatibilidade.
WIN_FFCV_DATAS         := "Cadastro: Faturas e Remessas"
WIN_FFCV_DATAS_OK      := "Mensagem ao Usuário do MV 2000"
WIN_XML                := "Monitoração de Faturamento - TISS"
WIN_XML_PATH_FORM      := "MV2000i - Faturamento - [WIN_PRINCIPAL]"
WIN_XML_POPUP_SIMNAO   := "Mensagem ao Usuário do MV 2000"

; ── Controles FFCV Manutenção de Remessa ─────────────────────
; Manutenção de Remessa usa teclado/atalhos de propósito.
; Os campos de remessa são Oracle Forms com EditN variável conforme quantidade
; de remessas do convênio e estado da tela. Preferir o fluxo validado no
; mini macro 03: F7/F8 para consulta, F6/F10 para nova remessa e Tab apenas
; onde foi testado. ClassNN = "CLASSNN" indica que o botão existe mas
; o campo é Oracle Forms variável — não usar como seletor.
FFCV_BTN_HABILITAR     := ""         ; preferir F7; não mapear campo variável sem nova validação
FFCV_CAMPO_CONVENIO    := ""         ; fluxo atual usa F7 + digitação por foco do Oracle Forms
FFCV_AREA_REMESSAS     := ""         ; fluxo atual usa Tab x3 validado no mini macro 03
FFCV_BTN_BUSCAR_REM    := ""         ; preferir F8; não mapear campo variável sem nova validação
FFCV_CAMPO_NUM_REM     := ""         ; EditN variável; manter teclado no fluxo atual
FFCV_BTN_CONFIRMAR_REM := ""         ; preferir F8; não mapear campo variável sem nova validação
FFCV_BTN_NOVA_REM      := ""         ; preferir F6; não mapear campo variável sem nova validação
FFCV_CAMPO_DATA_REM    := ""         ; EditN variável; manter teclado no fluxo atual
FFCV_CAMPO_TIPO        := ""         ; EditN variável; manter teclado no fluxo atual
FFCV_BTN_SALVAR_REM    := ""         ; preferir F10; não mapear campo variável sem nova validação
FFCV_BTN_ADICIONAR     := MV_BTN_ADICIONAR_CONTA ; 1 - Inserir Conta
FFCV_BTN_ABRIR_DATAS   := "Button6"  ; 5 - Entregar Rem.
FFCV_BTN_IMPRIMIR      := "Button7"  ; Relatório/Imprimir atendimentos
FFCV_BTN_IMPRIMIR_X    := 567
FFCV_BTN_IMPRIMIR_Y    := 458

; ── Controles popup de envio de contas ────────────────────────
; Validado por captura do usuário: "Informações da Conta" não abre WinTitle próprio;
; o sentinela é o painel desenhado ui60Drawn W323 dentro da janela principal FFCV.
; ── Controles tela de datas (Cadastro: Faturas e Remessas) ────
; Spy em Fluxos/Fluxo_FecharRemessa.
DATAS_CAMPO_REMESSA    := "Edit5"
DATAS_CAMPO_REMESSA_X  := 59
DATAS_CAMPO_REMESSA_Y  := 101
DATAS_CAMPO_ENTREGA    := "Edit1"
DATAS_CAMPO_ENTREGA_X  := 146
DATAS_CAMPO_ENTREGA_Y  := 101
DATAS_CAMPO_VENCIMENTO := "Edit1"
DATAS_CAMPO_VENCIMENTO_X := 244
DATAS_CAMPO_VENCIMENTO_Y := 227
DATAS_CHECKBOX         := "Button3"
DATAS_CHECKBOX_X       := 541
DATAS_CHECKBOX_Y       := 242
DATAS_BTN_CONFIRMAR    := "Button10"
DATAS_BTN_CONFIRMAR_X  := 30
DATAS_BTN_CONFIRMAR_Y  := 426
DATAS_BTN_VOLTAR       := "Button7"
; PENDENTE: Esc não sai da tela Entrega de Remessas. Quando descobrir o atalho correto,
; preencha aqui, ex.: FFCV_ENTREGA_SAIR_ATALHO := "!x" ou "{F4}".
FFCV_ENTREGA_SAIR_ATALHO := "^q"

; ── Controles tela XML/TISS ───────────────────────────────────
; Spy em Fluxos/Fluxo_XML: tela "Monitoração de Faturamento - TISS".
XML_CAMPO_REMESSA   := "Edit1"
XML_CAMPO_REMESSA_X := 272
XML_CAMPO_REMESSA_Y := 89
XML_BTN_BUSCAR      := ""        ; consulta continua por F8
XML_BTN_FATURAMENTO := "Button7"  ; 1 Faturamento
XML_BTN_FATURAMENTO_X := 12
XML_BTN_FATURAMENTO_Y := 446
XML_FORM_CAMPO_PATH   := "Edit1"
XML_FORM_CAMPO_PATH_X := 267       ; Window Spy: client x dentro do Edit1 do caminho XML
XML_FORM_CAMPO_PATH_Y := 467       ; Window Spy: client y dentro do Edit1 do caminho XML
XML_FORM_BTN_SALVAR   := "Button4" ; Salvar_XML / Window Spy: Visualizar XML
XML_FORM_BTN_SALVAR_X := 623       ; Window Spy: client x do Button4
XML_FORM_BTN_SALVAR_Y := 471       ; Window Spy: client y do Button4
XML_BTN_NAO           := "Button2"
XML_FORM_BTN_VOLTAR   := "Button7" ; Voltar
XML_FORM_BTN_VOLTAR_X := 731       ; Window Spy: client x do Button7
XML_FORM_BTN_VOLTAR_Y := 470       ; Window Spy: client y do Button7
XML_BTN_SAIR_TELA     := ""        ; pendente

; ── Fragmentos/classificação de erros no popup de envio ───────
; Modais Oracle Forms não expõem a mensagem pelo Window Spy/WinGetText de forma confiável.
; A classificação confiável vem do OCR local do Windows na área client do modal.
; (Constantes ERR_* mortas removidas: taxonomia canônica vive em FFCV_ErrorReferences.json.)

; ── Esperas e timings ──────────────────────────────────────────
; Padrão validado no macro 11: micro-settle suficiente para
; estabilidade sem sleeps longos em campos Oracle Forms.
; ── Performance FFCV Inserir Conta ───────────────────────────
; Contrato do macro 11: manter popup aberto, reagir ao modal e liberar próxima conta por estado.

; ── Esperas da fase de fechamento/XML ─────────────────────────
; Esta fase dispara processamentos pesados no Oracle Forms.
FFCV_FINAL_STABLE_MS             := 800
FFCV_FINAL_ACTION_TIMEOUT_MS     := 30000
FFCV_XML_QUERY_MIN_WAIT_MS       := 1200

; ════════════════════════════════════════════════════════════════
;  Predicados de estado operacional
; ════════════════════════════════════════════════════════════════

Ffcv_IsTelaManutencaoRemessa(hwnd) {
    if !hwnd || MV_SafeWinProcess(hwnd) != "ifrun60.EXE"
        return false
    return MV_FindControlAtPoint(hwnd, FFCV_BTN_ADICIONAR, FFCV_BTN_IMPRIMIR_X, FFCV_BTN_IMPRIMIR_Y, 40) != 0
        || MV_FindControlAtPoint(hwnd, MV_BTN_ADICIONAR_CONTA, MV_BTN_ADICIONAR_CONTA_X, MV_BTN_ADICIONAR_CONTA_Y, 40) != 0
}

Ffcv_IsTelaEntregaRemessas(hwnd) {
    if !hwnd || MV_SafeWinProcess(hwnd) != "ifrun60.EXE"
        return false
    return MV_FindControlAtPoint(hwnd, DATAS_BTN_CONFIRMAR, DATAS_BTN_CONFIRMAR_X, DATAS_BTN_CONFIRMAR_Y, 40) != 0
}

Ffcv_IsTelaTISS(hwnd) {
    if !hwnd || MV_SafeWinProcess(hwnd) != "ifrun60.EXE"
        return false
    return MV_FindControlAtPoint(hwnd, XML_BTN_FATURAMENTO, XML_BTN_FATURAMENTO_X, XML_BTN_FATURAMENTO_Y, 40) != 0
}

; ════════════════════════════════════════════════════════════════
;  Funções públicas — Manutenção de Remessa
; ════════════════════════════════════════════════════════════════

Ffcv_AbrirManutencaoRemessa() {
    MV_ActivateModule(MV_WIN_FFCV_ANY)
    if !MV_WaitScreenStable(MV_WIN_FFCV_ANY, MV_MODULE_STABLE_MS, MV_TIMEOUT_LOAD * 1000)
        return false

    ; Atalho validado no macro 03: Lançamentos → Manutenção de Remessa.
    if !MV_SendAndWait(MV_WIN_FFCV_ANY, "{Alt down}lm{Alt up}{Enter}", MV_TIMEOUT_LOAD * 1000,
        , "abertura de Manutenção de Remessa")
        return false
    if !MV_WaitScreenStable(MV_WIN_FFCV_REMESSA, MV_TARGET_STABLE_MS, MV_TIMEOUT_LOAD * 1000)
        return false
    return MV_WaitExpectedState((hwnd, state) => Ffcv_IsTelaManutencaoRemessa(hwnd), MV_WIN_FFCV_REMESSA,
        MV_TIMEOUT_LOAD * 1000, "Manutencao de Remessa operacional")
}

Ffcv_AbrirTelaEntregaRemessas() {
    if !MV_EnsureFFCV()
        return false

    if !MV_SendAndWait(MV_WIN_FFCV_ANY, "{Alt down}le{Alt up}", MV_TIMEOUT_LOAD * 1000,
        , "abertura de Entrega de Remessas")
        return false
    if !MV_WaitScreenStable(WIN_FFCV_DATAS, MV_TARGET_STABLE_MS, MV_TIMEOUT_LOAD * 1000)
        return false
    return MV_WaitExpectedState((hwnd, state) => Ffcv_IsTelaEntregaRemessas(hwnd), WIN_FFCV_DATAS,
        MV_TIMEOUT_LOAD * 1000, "Entrega de Remessas operacional")
}

Ffcv_CarregarConvenio(convenioNum) {
    MV_ActivateModule(MV_WIN_FFCV_ANY)
    if !MV_SendFunctionAndWait(MV_WIN_FFCV_ANY, "F7", MV_TIMEOUT_LOAD * 1000, , "modo de consulta de convenio")
        return false
    if !MV_SendTextAndWait(MV_WIN_FFCV_ANY, convenioNum, MV_TIMEOUT_LOAD * 1000,
        , "convenio preenchido")
        return false
    if !MV_SendFunctionAndWait(MV_WIN_FFCV_ANY, "F8", MV_TIMEOUT_LOAD * 1000, , "consulta de convenio")
        return false
    return FFCV_WaitLoad()
}

Ffcv_SelecionarRemessaExistente(numRemessa) {
    if !MV_SendFunctionAndWait(MV_WIN_FFCV_ANY, "F7", MV_TIMEOUT_LOAD * 1000, , "modo de consulta de remessa")
        return false
    if !MV_SendTextAndWait(MV_WIN_FFCV_ANY, numRemessa, MV_TIMEOUT_LOAD * 1000,
        , "remessa preenchida")
        return false
    if !MV_SendFunctionAndWait(MV_WIN_FFCV_ANY, "F8", MV_TIMEOUT_LOAD * 1000, , "consulta de remessa")
        return false
    return FFCV_WaitLoad()
}

Ffcv_CriarNovaRemessa(tipoConta) {
    if !MV_SendFunctionAndWait(MV_WIN_FFCV_ANY, "F6", MV_TIMEOUT_LOAD * 1000, , "formulario de nova remessa")
        return false

    hoje := FormatTime(, "dd/MM/yyyy")
    if !MV_SendTextAndWait(MV_WIN_FFCV_ANY, hoje, MV_TIMEOUT_LOAD * 1000, , "data da nova remessa")
        return false
    if !MV_SendAndWait(MV_WIN_FFCV_ANY, "{Tab 3}", MV_TIMEOUT_LOAD * 1000, , "posicionamento do tipo")
        return false
    if !MV_SendTextAndWait(MV_WIN_FFCV_ANY, _TipoContaCodigo(tipoConta), MV_TIMEOUT_LOAD * 1000, , "tipo da nova remessa")
        return false
    if !MV_SendFunctionAndWait(MV_WIN_FFCV_ANY, "F10", MV_TIMEOUT_LOAD * 1000, , "salvamento da nova remessa")
        return false
    return FFCV_WaitLoad()
}

Ffcv_PosicionarAreaRemessas() {
    return !!MV_SendAndWait(MV_WIN_FFCV_ANY, "{Tab 3}", 3000, , "área de remessas posicionada")
}

Ffcv_ImprimirRelatorioAtendimentos(&outRemessa?) {
    if !MV_EnsureFFCV() {
        Notify("FFCV não ficou ativa antes de imprimir relatório de atendimentos.")
        return false
    }

    try {
        return MV_PrintDeliveryReport(
            "Impressão do relatório de atendimentos em andamento...",
            MV_WIN_FFCV_ANY,
            FFCV_BTN_IMPRIMIR,
            &outRemessa)
    } catch as err {
        Notify(err.Message)
        return false
    }
}

Ffcv_ReiniciarManutencaoRemessa() {
    if !MV_EnsureFFCV()
        return false
    MV_SendAndWait(MV_WIN_FFCV_ANY, "{Esc 2}", 1000, , "limpeza da tela de manutenção")
    return Ffcv_AbrirManutencaoRemessa()
}


Ffcv_AbrirTelaTISS() {
    if !MV_EnsureFFCV()
        return false

    ; Atalho validado em Fluxos/FecharEXML: Lançamentos → Monitoração de Faturamento - TISS.
    if !MV_SendAndWait(MV_WIN_FFCV_ANY, "{Alt down}lmm{Enter}{Alt up}", MV_TIMEOUT_LOAD * 1000,
        , "abertura do XML/TISS")
        return false
    if !MV_WaitScreenStable(WIN_XML, MV_TARGET_STABLE_MS, MV_TIMEOUT_LOAD * 1000)
        return false
    result := MV_WaitExpectedState((hwnd, state) => Ffcv_IsTelaTISS(hwnd), WIN_XML,
        MV_TIMEOUT_LOAD * 1000, "XML/TISS operacional")
    if result
        Notify("Tela XML/TISS operacional.")
    return !!result
}

Ffcv_SairTelaEntregaPendente() {
    if !MV_EnsureWindowActive(WIN_FFCV_DATAS)
        return false

    ; Fluxos/FecharEXML e FecharEXMLOLD comprovam Ctrl+Q como saída da tela.
    if MV_CloseWindowAndWait(WIN_FFCV_DATAS, Ffcv_SendControlQ,
        MV_WIN_FFCV_ANY, MV_TIMEOUT_ACOE * 1000, "saída da tela de entrega")
        return true
    if MV_CloseWindowAndWait(WIN_FFCV_DATAS, Ffcv_SendControlQActive,
        MV_WIN_FFCV_ANY, MV_TIMEOUT_ACOE * 1000, "saída da tela de entrega por foco")
        return true
    return MV_CloseWindowAndWait(WIN_FFCV_DATAS, Ffcv_CloseEntregaWindow,
        MV_WIN_FFCV_ANY, MV_TIMEOUT_ACOE * 1000, "fechamento da tela de entrega")
}

Ffcv_SendControlQ() {
    ControlSend "^q",, WIN_FFCV_DATAS
    return true
}

Ffcv_SendControlQActive() {
    Send "^q"
    return true
}

Ffcv_CloseEntregaWindow() {
    try WinClose WIN_FFCV_DATAS
    catch
        return false
    return true
}

Ffcv_ConfirmarEntregaNaTela(dataEntrega, dataVenc, lerRemessaDireto := false) {
    datas := Ffcv_PreencherDatasEntrega(dataEntrega, dataVenc, lerRemessaDireto)
    if !datas["ok"]
        return datas

    checked := MV_ControlCheckedAt(WIN_FFCV_DATAS, DATAS_CHECKBOX, DATAS_CHECKBOX_X, DATAS_CHECKBOX_Y, 20)
    if (checked = 0) {
        if !MV_ClickBySpec(WIN_FFCV_DATAS, DATAS_CHECKBOX, DATAS_CHECKBOX_X, DATAS_CHECKBOX_Y)
            return Map("ok", false, "erro", "Nao consegui marcar Fechar contas sem imprimir faturas.", "remessa", "")
    } else if (checked = "") {
        return Map("ok", false, "erro", "Nao consegui ler o estado da opcao de fechamento.", "remessa", "")
    }

    if !MV_ClickBySpec(WIN_FFCV_DATAS, DATAS_BTN_CONFIRMAR, DATAS_BTN_CONFIRMAR_X, DATAS_BTN_CONFIRMAR_Y)
        return Map("ok", false, "erro", "Nao consegui confirmar a entrega da remessa.", "remessa", "")

    if !MV_Poll(() => WinExist(MV_CLASS_MODAL_FORMS), MV_TIMEOUT_ACOE)
        return Map("ok", false, "erro", "Popup de confirmacao da entrega nao apareceu.", "remessa", "")
    if !_ClickNaoModal()
        return Map("ok", false, "erro", "Nao consegui responder o popup de confirmacao da entrega.", "remessa", "")
    if !MV_WaitModalGone(FFCV_FINAL_ACTION_TIMEOUT_MS)
        return Map("ok", false, "erro", "Popup de confirmacao da entrega nao fechou.", "remessa", "")

    try {
        MV_PrintDeliveryReport("Impressão da remessa " datas["remessa"] " em andamento...")
    } catch as err {
        return Map("ok", false, "erro", err.Message, "remessa", "")
    }

    return Map("ok", true, "erro", "", "remessa", datas["remessa"])
}

Ffcv_PrepararEntregaPorProtocolo() {
    ; Ponte usada depois da ultima conta: inicia diretamente no atalho
    ; "5 - Entregar Rem." da Parte 1 recuperada.
    if !MV_SendAndWait(MV_WIN_FFCV_ANY, "{Alt down}5{Alt up}", MV_TIMEOUT_LOAD * 1000,
        , "abertura de Entrega por protocolo")
        return false
    return MV_WaitExpectedState((hwnd, state) => Ffcv_IsTelaEntregaRemessas(hwnd), WIN_FFCV_DATAS,
        MV_TIMEOUT_LOAD * 1000, "Entrega de Remessas operacional") != false
}

Ffcv_PreencherDatasEntrega(dataEntrega, dataVenc, lerRemessaDireto := false) {
    if !MV_EnsureWindowActive(WIN_FFCV_DATAS)
        return Map("ok", false, "erro", "Tela de datas não ficou ativa para preencher entrega/vencimento.", "remessa", "")

    if lerRemessaDireto {
        try numRemessa := Trim(ControlGetText(DATAS_CAMPO_REMESSA, WIN_FFCV_DATAS))
        catch
            numRemessa := ""
        if (numRemessa = "")
            return Map("ok", false, "erro", "Nao consegui ler Edit5 da tela Entrega de Remessas.", "remessa", "")

        try ControlFocus DATAS_CAMPO_ENTREGA, WIN_FFCV_DATAS
        catch
            return Map("ok", false, "erro", "Nao consegui focar a data de entrega.", "remessa", "")
    } else {
        ; Contrato validado no teste 12: ancorar foco em Data de Entrega,
        ; Shift+Tab seleciona Remessa e Tab volta para Data de Entrega.
        if !MV_ClickAtAndWait(WIN_FFCV_DATAS, DATAS_CAMPO_ENTREGA_X + 15,
            DATAS_CAMPO_ENTREGA_Y + 8, 3000, , "data de entrega focada")
            return Map("ok", false, "erro", "Nao consegui focar a data de entrega.", "remessa", "")
        if !MV_SendAndWait(WIN_FFCV_DATAS, "+{Tab}", 3000, , "campo de remessa selecionado")
            return Map("ok", false, "erro", "Nao consegui selecionar a remessa.", "remessa", "")
        numRemessa := MV_CopyFocusedText(600, true)
        if (numRemessa = "")
            return Map("ok", false, "erro", "Não consegui copiar o número da remessa via Shift+Tab na tela de datas.", "remessa", "")
        if !MV_SendAndWait(WIN_FFCV_DATAS, "{Tab}", 3000, , "campo de entrega selecionado")
            return Map("ok", false, "erro", "Nao consegui retornar ao campo de entrega.", "remessa", numRemessa)
    }
    if !MV_SendTextAndWait(WIN_FFCV_DATAS, dataEntrega, 3000, , "data de entrega preenchida")
        return Map("ok", false, "erro", "Data de entrega nao foi confirmada.", "remessa", numRemessa)
    if !MV_SendEnterAndWait(WIN_FFCV_DATAS, 3000, , "data de entrega validada")
        return Map("ok", false, "erro", "Data de entrega nao foi validada.", "remessa", numRemessa)
    if !MV_SendTextAndWait(WIN_FFCV_DATAS, dataVenc, 3000, , "data de vencimento preenchida")
        return Map("ok", false, "erro", "Data de vencimento nao foi confirmada.", "remessa", numRemessa)
    Notify("Datas enviadas: remessa " numRemessa ", entrega " dataEntrega ", vencimento " dataVenc ".")

    return Map("ok", true, "erro", "", "remessa", numRemessa)
}

; ── Shared helpers ───────────────────────────────────────────

/*
_ClickNaoModal()
    Click "Nao" button in active modal or WIN_XML_POPUP_SIMNAO.
*/
_ClickNaoModal() {
    popup := WinExist(WIN_XML_POPUP_SIMNAO)
        ? WIN_XML_POPUP_SIMNAO
        : Dialog_ActiveModalTitle()
    if (popup = "")
        return false
    hwnd := MV_FirstControlByClass(popup, XML_BTN_NAO)
    if !hwnd
        return false
    return MV_ClickModalAndWait(popup, hwnd, FFCV_FINAL_ACTION_TIMEOUT_MS,
        WIN_FFCV_DATAS, "modal de confirmação respondido com Não")
}

; ════════════════════════════════════════════════════════════════
;  Funções internas (privadas do módulo)
; ════════════════════════════════════════════════════════════════

/*
FFCV_WaitLoad()
    Micro-settle para o Oracle Forms consumir F7/F8/F10.
    Não há popup de confirmação nos passos de manutenção de remessa;
    a validação real acontece na próxima ação observável.
    Retorna true se MV_WIN_FFCV_ANY ainda existe.
*/
FFCV_WaitLoad() {
    return !!MV_WaitScreenStable(MV_WIN_FFCV_ANY, MV_KEY_SETTLE_MS, MV_TIMEOUT_LOAD * 1000)
}

_TipoContaCodigo(tipoConta) {
    normalized := StrLower(Trim(String(tipoConta)))

    ; Conversao local para evitar dependencia de escopo/global durante o
    ; preenchimento Oracle Forms. Contrato: Internamento=1, Emergencia=2,
    ; Ambulatorio=3.
    switch normalized {
        case "internamento":
            return "1"
        case "emergencia", "emergência":
            return "2"
        case "ambulatorio", "ambulatório":
            return "3"
        default:
            throw Error("Tipo de conta invalido: " tipoConta ". Use Internamento, Emergencia ou Ambulatorio.")
    }
}
