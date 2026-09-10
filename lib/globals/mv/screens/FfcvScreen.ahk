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
WIN_CAPA_REMESSA       := "Relatório de Atendimentos da Remessa"
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
; Constantes canônicas do popup ficam em MVConstants.ahk (MV_POPUP_*).
; Mantidos apenas aliases de compatibilidade para callers existentes.
FFCV_POPUP_CONTA_SENTINEL_CLASS := MV_POPUP_CONTA_SENTINEL_CLASS
FFCV_POPUP_CONTA_SENTINEL_X     := MV_POPUP_CONTA_SENTINEL_X
FFCV_POPUP_CONTA_SENTINEL_Y     := MV_POPUP_CONTA_SENTINEL_Y

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
; Timings canonicos em MVConstants (MV_FIELD_*). Aliases de compat.
FFCV_FIELD_FOCUS_SETTLE_MS := MV_FIELD_FOCUS_SETTLE_MS
FFCV_FIELD_CLEAR_SETTLE_MS := MV_FIELD_CLEAR_SETTLE_MS
FFCV_KEY_SETTLE_MS         := MV_KEY_SETTLE_MS

; ── Performance FFCV Inserir Conta ───────────────────────────
; Contrato do macro 11: manter popup aberto, reagir ao modal e liberar próxima conta por estado.
; Timings canonicos em MVConstants (MV_CONTA_*). Aliases de compat.
FFCV_CONTA_FOCUS_SETTLE_MS      := MV_CONTA_FOCUS_SETTLE_MS
FFCV_CONTA_CLEAR_SETTLE_MS      := MV_CONTA_CLEAR_SETTLE_MS
FFCV_CONTA_READY_MIN_MS         := MV_CONTA_READY_MIN_MS
FFCV_CONTA_FIELD_EMPTY_MIN_MS   := MV_CONTA_FIELD_EMPTY_MIN_MS
FFCV_CONTA_STABLE_MS            := MV_CONTA_STABLE_MS
FFCV_CONTA_SUBMIT_TIMEOUT_MS    := MV_CONTA_SUBMIT_TIMEOUT_MS

; ── Esperas da fase de fechamento/XML ─────────────────────────
; Esta fase dispara processamentos pesados no Oracle Forms.
FFCV_FINAL_STABLE_MS             := 800
FFCV_FINAL_ACTION_TIMEOUT_MS     := 30000
FFCV_XML_QUERY_MIN_WAIT_MS       := 1200

; ════════════════════════════════════════════════════════════════
;  Funções públicas — Manutenção de Remessa
; ════════════════════════════════════════════════════════════════

Ffcv_AbrirManutencaoRemessa() {
    MV_ActivateModule(MV_WIN_FFCV_ANY)
    if !MV_WaitWindowStable(MV_WIN_FFCV_ANY, MV_MODULE_STABLE_MS, MV_TIMEOUT_LOAD)
        return false

    ; Atalho validado no macro 03: Lançamentos → Manutenção de Remessa.
    Send "{Alt down}lm{Alt up}{Enter}"

    if !MV_Poll(() => WinExist(MV_WIN_FFCV_REMESSA), MV_TIMEOUT_LOAD)
        return false

    return MV_WaitWindowStable(MV_WIN_FFCV_REMESSA, MV_TARGET_STABLE_MS, MV_TIMEOUT_LOAD)
}

Ffcv_AbrirTelaEntregaRemessas() {
    if !MV_EnsureFFCV()
        return false

    Send "{Alt down}le{Alt up}"
    if !MV_Poll(() => WinExist(WIN_FFCV_DATAS), MV_TIMEOUT_LOAD)
        return false
    return MV_WaitWindowStable(WIN_FFCV_DATAS, MV_TARGET_STABLE_MS, MV_TIMEOUT_LOAD)
}

Ffcv_CarregarConvenio(convenioNum) {
    MV_ActivateModule(MV_WIN_FFCV_ANY)
    Send "{F7}"
    Sleep FFCV_KEY_SETTLE_MS
    SendText convenioNum
    Sleep FFCV_KEY_SETTLE_MS
    Send "{F8}"
    return FFCV_WaitLoad()
}

Ffcv_SelecionarRemessaExistente(numRemessa) {
    Send "{F7}"
    Sleep FFCV_KEY_SETTLE_MS
    SendText numRemessa
    Sleep FFCV_KEY_SETTLE_MS
    Send "{F8}"
    return FFCV_WaitLoad()
}

Ffcv_CriarNovaRemessa(tipoConta) {
    Send "{F6}"
    Sleep FFCV_KEY_SETTLE_MS

    hoje := FormatTime(, "dd/MM/yyyy")
    SendText hoje
    Sleep FFCV_KEY_SETTLE_MS
    Send "{Tab 3}"
    Sleep FFCV_KEY_SETTLE_MS
    SendText _TipoContaCodigo(tipoConta)
    Sleep FFCV_KEY_SETTLE_MS
    Send "{F10}"
    return FFCV_WaitLoad()
}

Ffcv_PosicionarAreaRemessas() {
    Send "{Tab 3}"
    Sleep FFCV_KEY_SETTLE_MS
    return true
}

Ffcv_ImprimirRelatorioAtendimentos() {
    if !MV_EnsureFFCV() {
        Notify("FFCV não ficou ativa antes de imprimir relatório de atendimentos.")
        return false
    }

    if !MV_ClickControlAt(MV_WIN_FFCV_ANY, FFCV_BTN_IMPRIMIR, FFCV_BTN_IMPRIMIR_X, FFCV_BTN_IMPRIMIR_Y) {
        Notify("Não consegui clicar em Relatório Atendimentos.")
        return false
    }

    if !MV_Poll(() => WinExist(WIN_CAPA_REMESSA), MV_TIMEOUT_LOAD) {
        Notify("Janela Relatório de Atendimentos da Remessa não apareceu.")
        return false
    }

    WinActivate WIN_CAPA_REMESSA
    Sleep FFCV_KEY_SETTLE_MS
    Send "{Enter}"
    MV_Poll(() => !WinExist(WIN_CAPA_REMESSA), MV_TIMEOUT_LOAD)
    Notify("Relatório de atendimentos confirmado para impressão.")
    return true
}

Ffcv_AbrirTelaTISS() {
    if !MV_EnsureFFCV()
        return false

    startedAt := A_TickCount

    ; Atalho validado em Fluxos/FecharEXML: Lançamentos → Monitoração de Faturamento - TISS.
    Send "{Alt down}lmm{Enter}{Alt up}"

    ok := MV_Poll(() => WinExist(WIN_XML), MV_TIMEOUT_LOAD)
    if ok
        Notify("Tela XML/TISS detectada em " (A_TickCount - startedAt) "ms.")
    return ok
}

Ffcv_SairTelaEntregaPendente() {
    if !MV_EnsureWindowActive(WIN_FFCV_DATAS)
        return false

    ; Fluxos/FecharEXML e FecharEXMLOLD comprovam Ctrl+Q como saída da tela.
    ControlSend "^q",, WIN_FFCV_DATAS
    if MV_Poll(() => !WinExist(WIN_FFCV_DATAS), MV_TIMEOUT_ACOE)
        return true

    Send "^q"
    if MV_Poll(() => !WinExist(WIN_FFCV_DATAS), MV_TIMEOUT_ACOE)
        return true

    try WinClose WIN_FFCV_DATAS
    return MV_Poll(() => !WinExist(WIN_FFCV_DATAS), MV_TIMEOUT_ACOE)
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

    if !MV_Poll(() => WinExist(WIN_CAPA_REMESSA), MV_TIMEOUT_LOAD)
        return Map("ok", false, "erro", "Relatorio de atendimentos da remessa nao apareceu.", "remessa", "")
    if !MV_EnsureWindowActive(WIN_CAPA_REMESSA)
        return Map("ok", false, "erro", "Relatorio de atendimentos nao ficou ativo.", "remessa", "")
    reportButton := MV_FirstControlByClass(WIN_CAPA_REMESSA, "Button2")
    if !reportButton
        return Map("ok", false, "erro", "Botao Imprimir do relatorio nao foi encontrado.", "remessa", "")
    try ControlClick reportButton,,,,, "NA"
    catch
        return Map("ok", false, "erro", "Falha ao iniciar impressao do relatorio da remessa.", "remessa", "")
    if !MV_WaitWindowGone(WIN_CAPA_REMESSA, MV_TIMEOUT_LOAD)
        return Map("ok", false, "erro", "Relatorio da remessa nao concluiu.", "remessa", "")

    return Map("ok", true, "erro", "", "remessa", datas["remessa"])
}

Ffcv_PrepararEntregaPorProtocolo() {
    ; Ponte usada depois da ultima conta: inicia diretamente no atalho
    ; "5 - Entregar Rem." da Parte 1 recuperada.
    Send "{Alt down}5{Alt up}"
    return MV_Poll(() => WinExist(WIN_FFCV_DATAS), MV_TIMEOUT_LOAD)
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
        Click(DATAS_CAMPO_ENTREGA_X + 15, DATAS_CAMPO_ENTREGA_Y + 8, 1)
        Sleep FFCV_KEY_SETTLE_MS
        Send("+{Tab}")
        Sleep FFCV_KEY_SETTLE_MS
        numRemessa := MV_CopyFocusedText(600, true)
        if (numRemessa = "")
            return Map("ok", false, "erro", "Não consegui copiar o número da remessa via Shift+Tab na tela de datas.", "remessa", "")
        Send("{Tab}")
    }
    Sleep FFCV_KEY_SETTLE_MS
    SendText dataEntrega
    Sleep FFCV_KEY_SETTLE_MS
    Send("{Enter}")
    Sleep FFCV_KEY_SETTLE_MS
    SendText dataVenc
    Sleep FFCV_KEY_SETTLE_MS
    Notify("Datas enviadas: remessa " numRemessa ", entrega " dataEntrega ", vencimento " dataVenc ".")

    return Map("ok", true, "erro", "", "remessa", numRemessa)
}

Ffcv_ConfirmarEntregaRemessa(dataEntrega, dataVenc) {
    if !MV_EnsureWindowActive(MV_WIN_FFCV_ANY)
        return Map("ok", false, "erro", "FFCV nao ficou ativa antes de abrir a tela de fechar remessa/datas.", "remessa", "")

    startedAt := A_TickCount
    if !MV_ClickBySpec(MV_WIN_FFCV_ANY, FFCV_BTN_ABRIR_DATAS, 464, 458)
        return Map("ok", false, "erro", "Nao consegui clicar em Entregar Remessa.", "remessa", "")

    if !MV_Poll(() => WinExist(WIN_FFCV_DATAS), MV_TIMEOUT_LOAD)
        return Map("ok", false, "erro", "Tela de fechar remessa/datas nao abriu.", "remessa", "")
    Notify("Tela de datas detectada em " (A_TickCount - startedAt) "ms.")

    datas := Ffcv_PreencherDatasEntrega(dataEntrega, dataVenc)
    if !datas["ok"]
        return Map("ok", false, "erro", datas["erro"], "remessa", "")
    numRemessa := datas["remessa"]

    checkedFecharContas := MV_ControlCheckedAt(WIN_FFCV_DATAS, DATAS_CHECKBOX, DATAS_CHECKBOX_X, DATAS_CHECKBOX_Y, 20)
    if (checkedFecharContas = 0) {
        if !MV_ClickBySpec(WIN_FFCV_DATAS, DATAS_CHECKBOX, DATAS_CHECKBOX_X, DATAS_CHECKBOX_Y)
            return Map("ok", false, "erro", "Nao consegui marcar 'Fechar contas sem imprimir faturas'.", "remessa", "")
    } else if (checkedFecharContas = "") {
        return Map("ok", false, "erro", "Nao consegui ler o estado de 'Fechar contas sem imprimir faturas'.", "remessa", "")
    }
    Sleep MV_DELAY_INPUT

    if !MV_ClickBySpec(WIN_FFCV_DATAS, DATAS_BTN_CONFIRMAR, DATAS_BTN_CONFIRMAR_X, DATAS_BTN_CONFIRMAR_Y)
        return Map("ok", false, "erro", "Nao consegui confirmar a entrega da remessa.", "remessa", "")

    if !MV_Poll(() => WinExist(MV_CLASS_MODAL_FORMS), MV_TIMEOUT_ACOE)
        return Map("ok", false, "erro", "Popup de confirmacao nao apareceu.", "remessa", "")
    if !_ClickNaoModal()
        return Map("ok", false, "erro", "Nao consegui clicar Nao no popup de confirmacao.", "remessa", "")
    if !MV_WaitModalGone(FFCV_FINAL_ACTION_TIMEOUT_MS)
        return Map("ok", false, "erro", "Popup de confirmacao nao fechou em tempo.", "remessa", "")

    if !MV_Poll(() => WinExist(WIN_CAPA_REMESSA), MV_TIMEOUT_LOAD)
        return Map("ok", false, "erro", "Tela de impressao nao apareceu.", "remessa", "")
    if !MV_EnsureWindowActive(WIN_CAPA_REMESSA)
        return Map("ok", false, "erro", "Tela de impressao nao ficou ativa para confirmar.", "remessa", "")
    if !MV_WaitOracleSettled(WIN_CAPA_REMESSA, FFCV_FINAL_STABLE_MS, FFCV_FINAL_ACTION_TIMEOUT_MS)
        return Map("ok", false, "erro", "Tela de impressao nao estabilizou antes do Enter.", "remessa", "")

    Send "{Enter}"
    if !MV_WaitWindowGone(WIN_CAPA_REMESSA, FFCV_FINAL_ACTION_TIMEOUT_MS)
        return Map("ok", false, "erro", "Enter enviado, mas a tela de impressao nao fechou em tempo.", "remessa", "")

    if !MV_WaitOracleSettled(WIN_FFCV_DATAS, FFCV_FINAL_STABLE_MS, FFCV_FINAL_ACTION_TIMEOUT_MS)
        return Map("ok", false, "erro", "A tela de Entrega de Remessas nao estabilizou para sair.", "remessa", "")

    if !Ffcv_SairTelaEntregaPendente()
        return Map("ok", false, "erro", "Atalho para sair da tela Entrega de Remessas ainda nao mapeado.", "remessa", "")
    if !MV_WaitOracleSettled(MV_WIN_FFCV_ANY, FFCV_FINAL_STABLE_MS, FFCV_FINAL_ACTION_TIMEOUT_MS)
        return Map("ok", false, "erro", "FFCV nao estabilizou apos sair da tela Entrega de Remessas.", "remessa", "")

    return Map("ok", true, "erro", "", "remessa", Trim(numRemessa))
}








; ── Shared helpers (also used by RemessaProtocolo) ────────────

/*
_ClickNaoModal()
    Click "Nao" button in active modal or WIN_XML_POPUP_SIMNAO.
*/
_ClickNaoModal() {
    if WinExist(WIN_XML_POPUP_SIMNAO)
        return MV_ClickFirstControl(WIN_XML_POPUP_SIMNAO, XML_BTN_NAO)
    popup := Dialog_ActiveModalTitle()
    if (popup != "")
        return MV_ClickFirstControl(popup, XML_BTN_NAO)
    return false
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
    Sleep FFCV_KEY_SETTLE_MS
    return WinExist(MV_WIN_FFCV_ANY)
}

_TipoContaCodigo(tipoConta) {
    ; Valor canônico em MVConstants.MV_TIPO_CONTA (Internamento->1, Emergência->2, Ambulatório->3).
    return MV_TIPO_CONTA.Has(tipoConta) ? Str(MV_TIPO_CONTA[tipoConta]) : ""
}
