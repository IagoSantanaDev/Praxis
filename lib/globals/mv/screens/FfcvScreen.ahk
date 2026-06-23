; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug
#Include ..\..\..\..\lib\globals\mv\MVSession.ahk
#Include ..\FFCV_ErrorTemplates.ahk
#Include ..\components\Popups.ahk
#Include ..\components\Dialogs.ahk
#Include FfcvContaPopup.ahk

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
FFCV_BTN_ADICIONAR     := "Button10" ; 1 - Inserir Conta
FFCV_BTN_ABRIR_DATAS   := "Button6"  ; 5 - Entregar Rem.
FFCV_BTN_IMPRIMIR      := "Button7"  ; Relatório/Imprimir atendimentos
FFCV_BTN_IMPRIMIR_X    := 567
FFCV_BTN_IMPRIMIR_Y    := 458

; ── Controles popup de envio de contas ────────────────────────
; Validado por captura do usuário: "Informações da Conta" não abre WinTitle próprio;
; o sentinela é o painel desenhado ui60Drawn W323 dentro da janela principal FFCV.
FFCV_POPUP_CONTA_SENTINEL_CLASS := "ui60Drawn W323"
FFCV_POPUP_CONTA_SENTINEL_X     := 432
FFCV_POPUP_CONTA_SENTINEL_Y     := 109
POPUP_DROPDOWN_1   := "ComboBox2"
POPUP_DROPDOWN_1_X := 84
POPUP_DROPDOWN_1_Y := 143
POPUP_DROPDOWN_2   := "ComboBox1"
POPUP_DROPDOWN_2_X := 190
POPUP_DROPDOWN_2_Y := 143
POPUP_CAMPO_CONTA  := "Edit2"
POPUP_CAMPO_CONTA_X := 298
POPUP_CAMPO_CONTA_Y := 143
POPUP_BTN_OK       := "Button1"  ; modal de aviso/erro usa o primeiro Button1

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
ERR_JA_DIGITADA        := "já digitada"
ERR_CONVENIO_DIFERENTE := "convênio diferente"
ERR_CONTA_ABERTA       := "conta aberta"
ERR_CONTA_JA_EM_REMESSA := "já em remessa"
ERR_TIPO_DIFERENTE     := "tipo diferente"

; ── Esperas e timings ──────────────────────────────────────────
; Padrão validado no macro 11: micro-settle suficiente para
; estabilidade sem sleeps longos em campos Oracle Forms.
FFCV_FIELD_FOCUS_SETTLE_MS := 100
FFCV_FIELD_CLEAR_SETTLE_MS := 100
FFCV_KEY_SETTLE_MS         := 100

; ── Performance FFCV Inserir Conta ───────────────────────────
; Contrato do macro 11: manter popup aberto, reagir ao modal e liberar próxima conta por estado.
FFCV_CONTA_FOCUS_SETTLE_MS      := 100
FFCV_CONTA_CLEAR_SETTLE_MS      := 100
FFCV_CONTA_READY_MIN_MS         := 180
FFCV_CONTA_FIELD_EMPTY_MIN_MS   := 100
FFCV_CONTA_STABLE_MS            := 100
FFCV_CONTA_SUBMIT_TIMEOUT_MS    := 650

; ── Esperas da fase de fechamento/XML ─────────────────────────
; Esta fase dispara processamentos pesados no Oracle Forms.
FFCV_FINAL_STABLE_MS             := 800
FFCV_FINAL_ACTION_TIMEOUT_MS     := 30000
FFCV_XML_QUERY_MIN_WAIT_MS       := 1200

; ════════════════════════════════════════════════════════════════
;  Funções públicas — Manutenção de Remessa
; ════════════════════════════════════════════════════════════════

/*
Ffcv_AbrirManutencaoRemessa()
    Abre a tela Manutenção de Remessa via atalho Alt+lm Enter.
    Sempre abre uma nova instância; não reutiliza tela já aberta.
    Retorna true se a janela ficou estável, false em timeout.
*/
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

/*
Ffcv_CarregarConvenio(convenioNum)
    Aciona F7, digita o número do convênio e confirma com F8.
    Retorna true se a janela ficou estável após F8, false em falha.
*/
Ffcv_CarregarConvenio(convenioNum) {
    MV_ActivateModule(MV_WIN_FFCV_ANY)
    Send "{F7}"
    Sleep FFCV_KEY_SETTLE_MS
    SendText convenioNum
    Sleep FFCV_KEY_SETTLE_MS
    Send "{F8}"
    return FFCV_WaitLoad()
}

/*
Ffcv_SelecionarRemessaExistente(numRemessa)
    Aciona F7, digita o número da remessa e confirma com F8.
    Retorna true se a janela ficou estável, false em falha.
*/
Ffcv_SelecionarRemessaExistente(numRemessa) {
    Send "{F7}"
    Sleep FFCV_KEY_SETTLE_MS
    SendText numRemessa
    Sleep FFCV_KEY_SETTLE_MS
    Send "{F8}"
    return FFCV_WaitLoad()
}

/*
Ffcv_CriarNovaRemessa(tipoConta)
    Cria nova remessa: F6, data atual, Tab x3, código do tipo, F10.
    @param tipoConta  "Internamento", "Emergência" ou "Ambulatório".
    Retorna true se a janela ficou estável após F10, false em falha.
*/
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

/*
Ffcv_PosicionarAreaRemessas()
    Envia Tab x3 para posicionar o cursor na área de remessas.
    Usado após carregar convênio antes de selecionar/criar remessa.
    Retorna sempre true (operação de teclado).
*/
Ffcv_PosicionarAreaRemessas() {
    Send "{Tab 3}"
    Sleep FFCV_KEY_SETTLE_MS
    return true
}

/*
Ffcv_ImprimirRelatorioAtendimentos()
    Clica em Relatório/Imprimir atendimentos na tela FFCV ativa.
    Confirma a janela de relatório com Enter.
    Retorna true se a impressão foi acionada, false em falha.
*/
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

/*
Ffcv_AbrirTelaTISS()
    Abre a tela Monitoração de Faturamento - TISS via atalho Alt+lt Enter.
    Sempre abre uma nova instância; não reutilizar TISS já aberta.
    Retorna true se a janela existe, false em timeout.
*/
Ffcv_AbrirTelaTISS() {
    if !MV_EnsureFFCV()
        return false

    startedAt := A_TickCount

    ; Atalho esperado: Lançamentos → Monitoração de Faturamento - TISS.
    Send "{Alt down}lt{Alt up}{Enter}"

    ok := MV_Poll(() => WinExist(WIN_XML), MV_TIMEOUT_LOAD)
    if ok
        Notify("Tela XML/TISS detectada em " (A_TickCount - startedAt) "ms.")
    return ok
}

/*
Ffcv_SairTelaEntregaPendente()
    Envia o atalho configurado em FFCV_ENTREGA_SAIR_ATALHO para sair
    da tela "Cadastro: Faturas e Remessas" (Entrega de Remessas).
    Retorna true se a tela fechou, false se o atalho não está mapeado
    ou a tela não fechou.
*/
Ffcv_SairTelaEntregaPendente() {
    ; M1 (auditoria 2026-06-27): FFCV_ENTREGA_SAIR_ATALHO esta como placeholder "^q"
    ; desde M001. Se nao foi corrigido, falhar cedo com erro explicito em vez de
    ; enviar Ctrl+Q arbitrariamente e potencialmente corromper o estado da tela.
    if (FFCV_ENTREGA_SAIR_ATALHO = "^q") {
        Notify("PENDENTE: atalho de saida da tela Entrega de Remessas ainda nao foi mapeado (FFCV_ENTREGA_SAIR_ATALHO). Use Window Spy para descobrir a combinacao correta e atualizar a constante antes de continuar ate XML.")
        return false
    }
    if (Trim(FFCV_ENTREGA_SAIR_ATALHO) = "") {
        Notify("Pendente: atalho para sair da tela Entrega de Remessas ainda não mapeado. Preencha FFCV_ENTREGA_SAIR_ATALHO para continuar até XML.")
        return false
    }

    if !_EnsureWindowActive(WIN_FFCV_DATAS) {
        Notify("Não consegui ativar a tela Entrega de Remessas para enviar o atalho de saída.")
        return false
    }

    Send FFCV_ENTREGA_SAIR_ATALHO
    return MV_Poll(() => !WinExist(WIN_FFCV_DATAS), MV_TIMEOUT_ACOE)
}

/*
Ffcv_PreencherDatasEntrega(dataEntrega, dataVenc)
    Preenche data de entrega, copia número da remessa via Shift+Tab,
    preenche data de vencimento na tela "Cadastro: Faturas e Remessas".
    Retorna Map("ok", bool, "erro", string, "remessa", string).
*/
Ffcv_PreencherDatasEntrega(dataEntrega, dataVenc) {
    if !_EnsureWindowActive(WIN_FFCV_DATAS)
        return Map("ok", false, "erro", "Tela de datas não ficou ativa para preencher entrega/vencimento.", "remessa", "")

    ; Contrato validado no teste 12:
    ; ancorar foco em Data de Entrega, Shift+Tab seleciona Remessa, Tab volta
    ; para Data de Entrega, Enter avança para Data Prevista. Não usar Ctrl+A.
    Click(DATAS_CAMPO_ENTREGA_X + 15, DATAS_CAMPO_ENTREGA_Y + 8, 1)
    Sleep FFCV_KEY_SETTLE_MS

    Send("+{Tab}")
    Sleep FFCV_KEY_SETTLE_MS
    numRemessa := _CopyFocusedNumericText(600)
    if (numRemessa = "")
        return Map("ok", false, "erro", "Não consegui copiar o número da remessa via Shift+Tab na tela de datas.", "remessa", "")

    Send("{Tab}")
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

/*
Ffcv_ConfirmarEntregaRemessa(dataEntrega, dataVenc)
    Orchestrates the full "Entregar Remessa" flow.
    @return Map("ok", bool, "erro", string, "remessa", string)
*/
Ffcv_ConfirmarEntregaRemessa(dataEntrega, dataVenc) {
    if !_EnsureWindowActive(MV_WIN_FFCV_ANY)
        return Map("ok", false, "erro", "FFCV nao ficou ativa antes de abrir a tela de fechar remessa/datas.", "remessa", "")

    startedAt := A_TickCount
    if !_ClickBySpec(MV_WIN_FFCV_ANY, FFCV_BTN_ABRIR_DATAS, 464, 458)
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
        if !_ClickBySpec(WIN_FFCV_DATAS, DATAS_CHECKBOX, DATAS_CHECKBOX_X, DATAS_CHECKBOX_Y)
            return Map("ok", false, "erro", "Nao consegui marcar 'Fechar contas sem imprimir faturas'.", "remessa", "")
    } else if (checkedFecharContas = "") {
        return Map("ok", false, "erro", "Nao consegui ler o estado de 'Fechar contas sem imprimir faturas'.", "remessa", "")
    }
    Sleep MV_DELAY_INPUT

    if !_ClickBySpec(WIN_FFCV_DATAS, DATAS_BTN_CONFIRMAR, DATAS_BTN_CONFIRMAR_X, DATAS_BTN_CONFIRMAR_Y)
        return Map("ok", false, "erro", "Nao consegui confirmar a entrega da remessa.", "remessa", "")

    if !_WaitAnyModalOrDelay(MV_TIMEOUT_ACOE)
        return Map("ok", false, "erro", "Popup de confirmacao nao apareceu.", "remessa", "")
    if !_ClickNaoModal()
        return Map("ok", false, "erro", "Nao consegui clicar Nao no popup de confirmacao.", "remessa", "")
    if !_WaitModalGone(FFCV_FINAL_ACTION_TIMEOUT_MS)
        return Map("ok", false, "erro", "Popup de confirmacao nao fechou em tempo.", "remessa", "")

    if !MV_Poll(() => WinExist(WIN_CAPA_REMESSA), MV_TIMEOUT_LOAD)
        return Map("ok", false, "erro", "Tela de impressao nao apareceu.", "remessa", "")
    if !_EnsureWindowActive(WIN_CAPA_REMESSA)
        return Map("ok", false, "erro", "Tela de impressao nao ficou ativa para confirmar.", "remessa", "")
    if !MV_WaitOracleSettled(WIN_CAPA_REMESSA, FFCV_FINAL_STABLE_MS, FFCV_FINAL_ACTION_TIMEOUT_MS)
        return Map("ok", false, "erro", "Tela de impressao nao estabilizou antes do Enter.", "remessa", "")

    Send "{Enter}"
    if !_WaitWindowGone(WIN_CAPA_REMESSA, FFCV_FINAL_ACTION_TIMEOUT_MS)
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
_ClickBySpec(winTitle, classNN, x, y)
    Click by ClassNN + client coords; fallback direct Click.
*/
_ClickBySpec(winTitle, classNN, x, y) {
    if (classNN = "" || classNN = "CLASSNN" || x = "" || y = "")
        return false
    if MV_ClickControlAt(winTitle, classNN, x, y, 20)
        return true
    if !WinExist(winTitle)
        return false
    try {
        WinActivate winTitle
        if !MV_Poll(() => WinActive(winTitle), 3)
            return false
        Click(x, y, 1)
        return true
    } catch {
        return false
    }
}

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

/*
_WaitAnyModalOrDelay(timeoutSecs)
    Poll for any Oracle Forms modal window.
*/
_WaitAnyModalOrDelay(timeoutSecs) {
    return MV_Poll(() => WinExist(MV_CLASS_MODAL_FORMS), timeoutSecs)
}

/*
_WaitModalGone(timeoutMs)
    Wait for no active modal.
*/
_WaitModalGone(timeoutMs := 30000) {
    startedAt := A_TickCount
    Loop {
        if (Dialog_ActiveModalTitle() = "")
            return true
        if (A_TickCount - startedAt >= timeoutMs)
            return false
        Sleep MV_POLL_MS
    }
}

/*
_WaitWindowGone(winTitle, timeoutMs)
    Wait for a window to disappear.
*/
_WaitWindowGone(winTitle, timeoutMs := 30000) {
    startedAt := A_TickCount
    Loop {
        if !WinExist(winTitle) {
            Sleep 100
            return true
        }
        if (A_TickCount - startedAt >= timeoutMs)
            return false
        Sleep MV_POLL_MS
    }
}

/*
_WaitOracleSettled removido em 2026-06-26 — use MV_WaitOracleSettled de
components/Controls.ahk (consolidado).
*/

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

/*
_CopyFocusedNumericText(timeoutMs)
    Seleciona o texto focado com Ctrl+C, extrai o primeiro número
    contíguo e retorna. Usado para copiar o número da remessa na
    tela de datas.
    @return String numérica ou "" em timeout.
*/
_CopyFocusedNumericText(timeoutMs := 600) {
    A_Clipboard := ""
    Send "^c"
    if !ClipWait(timeoutMs / 1000)
        return ""

    value := Trim(A_Clipboard)
    if RegExMatch(value, "\d+", &m)
        return m[0]
    return ""
}

/*
_EnsureWindowActive(winTitle, timeoutSecs := 3)
    Ativa a janela e aguarda que fique ativa.
    @return true se ativa em timeout, false caso contrário.
*/
_EnsureWindowActive(winTitle, timeoutSecs := 3) {
    if !WinExist(winTitle)
        return false
    WinActivate winTitle
    return MV_Poll(() => WinActive(winTitle), timeoutSecs)
}

/*
_TipoContaCodigo(tipoConta)
    Retorna o código Oracle Forms do tipo de conta.
    @return String "1", "2" ou "" conforme tipoConta.
*/
_TipoContaCodigo(tipoConta) {
    if (tipoConta = "Internamento")
        return "1"
    if (tipoConta = "Emergência")
        return "2"
    if (tipoConta = "Ambulatório")
        return "3"
    return ""
}
