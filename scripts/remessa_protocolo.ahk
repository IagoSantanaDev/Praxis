#Requires AutoHotkey v2.0
#Include mv_session.ahk

; Configuração conservadora para computadores rápidos e lentos.
; Não usar prioridade alta: o Oracle Forms precisa reagir aos eventos de teclado/mouse.
ListLines(false)
SetKeyDelay(10, 10)
SetMouseDelay(-1)
SetDefaultMouseSpeed(0)
SetControlDelay(-1)

; ════════════════════════════════════════════════════════════════
;  REMESSA POR PROTOCOLO
; ════════════════════════════════════════════════════════════════

; ── Janelas ───────────────────────────────────────────────────
WIN_MOVDOC_BAIXA       := MV_WIN_MOVDOC_BAIXA
WIN_MOVDOC_POPUP       := "Forms ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"
; O popup "Informações da Conta" é embarcado na janela FFCV: o título não muda.
; Detectá-lo por controle sentinela dentro de MV_WIN_FFCV_ANY, não por WinTitle próprio.
WIN_FFCV_DATAS         := "Cadastro: Faturas e Remessas"
WIN_FFCV_DATAS_OK      := "Mensagem ao Usuário do MV 2000"
WIN_CAPA_REMESSA       := "Relatório de Atendimentos da Remessa"
WIN_XML                := "Monitoração de Faturamento - TISS"
WIN_XML_PATH_FORM      := "MV2000i - Faturamento - [WIN_PRINCIPAL]"
WIN_XML_POPUP_SIMNAO   := "Mensagem ao Usuário do MV 2000"

; ── Regiões MOV DOC em coordenadas Client ─────────────────────
; Não usar EditN como contrato: Oracle Forms renumera Edit1/Edit2/Edit15 conforme estado.
; A grid MOV DOC não expõe texto confiável via ControlGetText: usar clique físico,
; Home, Shift+End e Ctrl+C com validação semântica.
MOVDOC_PROTOCOLO_X := 21
MOVDOC_PROTOCOLO_Y := 106
MOVDOC_CONTA_X     := 252
MOVDOC_CONVENIO_X  := 491
MOVDOC_GRID_ROWS_Y := [222, 245, 268, 291]

; Confirmado previamente para primeira linha, mas manter validável por teste.
MOVDOC_CHECK_RECEBIDO_CLASS  := "Button1"
MOVDOC_CHECK_RECEBIDO_X      := 718
MOVDOC_CHECK_RECEBIDO_Y      := 359

; ── Controles FFCV ────────────────────────────────────────────
; Manutenção de Remessa usa teclado/atalhos de propósito.
; Os campos de remessa são Oracle Forms com EditN variável conforme quantidade de
; remessas do convênio e estado da tela. Preferir o fluxo validado no mini macro 03:
; F7/F8 para consulta, F6/F10 para nova remessa e Tab apenas onde foi testado.
FFCV_BTN_HABILITAR     := "CLASSNN"  ; preferir F7; não mapear campo variável sem nova validação
FFCV_CAMPO_CONVENIO    := "CLASSNN"  ; fluxo atual usa F7 + digitação por foco do Oracle Forms
FFCV_AREA_REMESSAS     := "CLASSNN"  ; fluxo atual usa Tab x3 validado no mini macro 03
FFCV_BTN_BUSCAR_REM    := "CLASSNN"  ; preferir F8; não mapear campo variável sem nova validação
FFCV_CAMPO_NUM_REM     := "CLASSNN"  ; EditN variável; manter teclado no fluxo atual
FFCV_BTN_CONFIRMAR_REM := "CLASSNN"  ; preferir F8; não mapear campo variável sem nova validação
FFCV_BTN_NOVA_REM      := "CLASSNN"  ; preferir F6; não mapear campo variável sem nova validação
FFCV_CAMPO_DATA_REM    := "CLASSNN"  ; EditN variável; manter teclado no fluxo atual
FFCV_CAMPO_TIPO        := "CLASSNN"  ; EditN variável; manter teclado no fluxo atual
FFCV_BTN_SALVAR_REM    := "CLASSNN"  ; preferir F10; não mapear campo variável sem nova validação
FFCV_BTN_ADICIONAR     := "Button10" ; 1 - Inserir Conta
FFCV_BTN_ABRIR_DATAS   := "Button6"  ; 5 - Entregar Rem.

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

; ── Controles tela de datas ───────────────────────────────────
; Spy em Fluxos/Fluxo_FecharRemessa: tela "Cadastro: Faturas e Remessas".
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
; preencha aqui, ex.: RP_ENTREGA_SAIR_ATALHO := "!x" ou "{F4}".
RP_ENTREGA_SAIR_ATALHO := "!{F4}"

; ── Controles tela XML ────────────────────────────────────────
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

; ── Fragmentos de texto dos erros no popup de envio ───────────
ERR_JA_DIGITADA        := "já digitada"
ERR_CONVENIO_DIFERENTE := "convênio diferente"
ERR_CONTA_ABERTA       := "conta aberta"
ERR_TIPO_DIFERENTE     := "tipo diferente"

; ── Entrada por teclado/campo Oracle Forms ─────────────────────
; Padrão: enviar atalhos em bloco único e usar settle curto padronizado.
RP_FIELD_FOCUS_SETTLE_MS := 20
RP_FIELD_CLEAR_SETTLE_MS := 20
RP_KEY_SETTLE_MS         := 20

; ── Performance FFCV Inserir Conta ─────────────────────────────
; Fast path: reduzir Sleeps fixos; a segurança fica na espera adaptativa pós-Enter.
FFCV_CONTA_FOCUS_SETTLE_MS      := RP_FIELD_FOCUS_SETTLE_MS
FFCV_CONTA_CLEAR_SETTLE_MS      := RP_FIELD_CLEAR_SETTLE_MS
FFCV_CONTA_READY_MIN_MS         := 180
FFCV_CONTA_FIELD_EMPTY_MIN_MS   := 80
FFCV_CONTA_STABLE_MS            := 60
FFCV_CONTA_SUBMIT_TIMEOUT_MS    := 650

RunRemessaProtocolo(params) {
    global gRunning

    protocolos   := ParseProtocolos(params["protocolos"])
    tipoConta    := params["tipo_conta"]
    dataEntrega  := params["data_entrega"]
    dataVenc     := params["data_vencimento"]
    numRemessa   := Trim(params["num_remessa"])
    temDatas     := (dataEntrega != "" && dataVenc != "")

    if (protocolos.Length = 0)
        return RP_Abort("Informe ao menos um protocolo.")

    linhasMovDoc := []
    erros        := []
    convenioNum  := ""
    timings      := []
    totalStart   := A_TickCount
    stageStart   := A_TickCount

    Notify("Garantindo MOV DOC...")
    if !MV_EnsureMovDoc()
        return RP_Abort("Não foi possível acessar o MOV DOC.")

    if !RP_AbrirTelaBaixaMovDoc()
        return RP_Abort("Não consegui abrir a tela Baixa de Documentos no MOV DOC.")
    RP_RecordTiming(timings, "Abrir MOV DOC e tela Baixa", stageStart)

    Progress(5)

    stageStart := A_TickCount
    for idx, protocolo in protocolos {
        protocolStart := A_TickCount
        Notify("Processando protocolo " protocolo " (" idx "/" protocolos.Length ")")
        result := ProcessarProtocolo(protocolo)

        if !result["ok"]
            return RP_Abort(result["erro"])

        for _, linha in result["linhas"]
            linhasMovDoc.Push(linha)

        Notify("⏱ MOV DOC protocolo " protocolo ": " RP_FormatDuration(A_TickCount - protocolStart) " | " result["linhas"].Length " linha(s)")
        Progress(5 + (idx / protocolos.Length) * 40)
    }
    RP_RecordTiming(timings, "MOV DOC consultar, coletar e baixar", stageStart, protocolos.Length " protocolo(s), " linhasMovDoc.Length " linha(s)")

    convenioNum := RP_ConvenioMajoritario(linhasMovDoc)
    if (convenioNum = "")
        return RP_Abort("Convênio não identificado no MOV DOC.")

    protocolContas := RP_FiltrarContasPorConvenio(linhasMovDoc, convenioNum, erros)
    totalContasFFCV := ContarContas(protocolContas)

    stageStart := A_TickCount
    Notify("Garantindo FFCV...")
    if !MV_EnsureFFCV()
        return RP_Abort("Não foi possível acessar o FFCV.")

    if !RP_AbrirManutencaoRemessaFFCV()
        return RP_Abort("Não consegui abrir Manutenção de Remessa no FFCV.")
    RP_RecordTiming(timings, "Abrir FFCV e Manutenção de Remessa", stageStart)

    Progress(50)

    stageStart := A_TickCount
    if !CarregarConvenioFFCV(convenioNum)
        return RP_Abort("Não consegui carregar o convênio " convenioNum " no FFCV.")

    PosicionarAreaRemessas()

    if (numRemessa != "") {
        if !SelecionarRemessaExistente(numRemessa)
            return RP_Abort("Remessa " numRemessa " não encontrada.")
    } else {
        if !CriarNovaRemessa(tipoConta)
            return RP_Abort("Erro ao criar nova remessa.")
    }
    RP_RecordTiming(timings, "Carregar convênio e posicionar remessa", stageStart, "convênio " convenioNum)

    Progress(60)
    stageStart := A_TickCount
    if !InserirContasNaRemessa(protocolContas, tipoConta, erros)
        return false
    RP_RecordTiming(timings, "Inserir contas FFCV", stageStart, totalContasFFCV " conta(s)")

    Progress(87)

    if temDatas {
        stageStart := A_TickCount
        Notify("Preenchendo datas...")
        result := FinalizarComDatas(dataEntrega, dataVenc)
        if !result["ok"]
            return RP_Abort(result["erro"])
        RP_RecordTiming(timings, "Fechar remessa e preencher datas", stageStart, "remessa " result["remessa"])
        Progress(94)
        stageStart := A_TickCount
        Notify("Gerando XML...")
        GerarXML(result["remessa"])
        RP_RecordTiming(timings, "Gerar XML", stageStart)
    } else {
        stageStart := A_TickCount
        FinalizarSemDatas()
        RP_RecordTiming(timings, "Finalização sem datas", stageStart)
    }

    Progress(100)
    RP_RecordTiming(timings, "Total do fluxo", totalStart, protocolos.Length " protocolo(s), " totalContasFFCV " conta(s)")
    timingReport := RP_FormatTimingReport(timings)
    gRunning := false

    if (erros.Length > 0) {
        linhas := "Concluído com " erros.Length " pendência(s):`n"
        for _, e in erros
            linhas .= "  Prot. " e["protocolo"] " | Conta " e["conta"] " | " e["descricao"] "`n"
        Done(linhas "`n" timingReport)
    } else {
        Done("Remessa concluída com sucesso!`n`n" timingReport)
    }
}

; ════════════════════════════════════════════════════════════════
;  FASE MOV DOC
; ════════════════════════════════════════════════════════════════

RP_AbrirTelaBaixaMovDoc() {
    ; Sempre abre uma nova instância da tela funcional. Não reutilizar Baixa já aberta.
    MV_ActivateModule(MV_WIN_MOVDOC_ANY)
    Sleep MV_DELAY_INPUT

    ; Atalho validado no macro 02: Manutenção → Protocolação → Baixa.
    Send "{Alt down}mpb{Alt up}"

    return MV_Poll(() => WinExist(WIN_MOVDOC_BAIXA), MV_TIMEOUT_LOAD)
}

ProcessarProtocolo(protocolo) {
    WinActivate WIN_MOVDOC_BAIXA
    if !RP_SetTextByClickNoClear(WIN_MOVDOC_BAIXA, MOVDOC_PROTOCOLO_X, MOVDOC_PROTOCOLO_Y, protocolo)
        return Map("ok", false, "erro", "Não consegui focar/preencher o campo Protocolo.")

    Sleep MV_DELAY_INPUT
    Send "{F8}"
    if !RP_WaitMovDocFirstGridLineReady(protocolo)
        return Map("ok", false, "erro", "A primeira linha da grid não ficou legível após F8 para o protocolo " protocolo ".")

    linhas := RP_ColetarLinhasMovDoc(protocolo)
    if (linhas.Length = 0)
        return Map("ok", false, "erro", "Nenhuma conta/convênio foi coletado para o protocolo " protocolo ".")

    if !RP_FinalizarBaixaProtocolo()
        return Map("ok", false, "erro", "Falha ao salvar/baixar o protocolo " protocolo ".")

    return Map("ok", true, "linhas", linhas)
}

RP_ColetarLinhasMovDoc(protocolo) {
    linhas := []
    vistos := Map()

    RP_ColetarLinhasVisiveisMovDoc(protocolo, linhas, vistos)

    Loop 80 {
        result := RP_AvancarGridMovDocQuatroLinhas()
        added := RP_ColetarLinhasVisiveisMovDoc(protocolo, linhas, vistos)

        if result["popup"]
            break
        if (added = 0)
            break
    }

    return linhas
}

RP_AvancarGridMovDocQuatroLinhas() {
    CoordMode("Mouse", "Client")
    ultimoY := MOVDOC_GRID_ROWS_Y[MOVDOC_GRID_ROWS_Y.Length]
    Click(MOVDOC_CONTA_X + 15, ultimoY + 8, 1)
    Sleep MV_DELAY_INPUT

    Loop 4 {
        Send "{Down}"
        Sleep 90

        if MV_Poll(() => RP_MovDocPopupWindowVisible(), 0.25) {
            RP_DismissMovDocPopup()
            return Map("popup", true)
        }
    }

    primeiroY := MOVDOC_GRID_ROWS_Y[1]
    Click(MOVDOC_CONTA_X + 15, primeiroY + 8, 1)
    Sleep MV_DELAY_INPUT
    return Map("popup", false)
}

RP_ColetarLinhasVisiveisMovDoc(protocolo, linhas, vistos) {
    added := 0

    for _, rowY in MOVDOC_GRID_ROWS_Y {
        conta := RP_ReadMovDocGridField(MOVDOC_CONTA_X, rowY, "conta")
        convenio := RP_ReadMovDocGridField(MOVDOC_CONVENIO_X, rowY, "convenio")

        if (conta = protocolo || convenio = protocolo || conta = "" || convenio = "")
            continue

        if (conta = convenio)
            conta := RP_ReadMovDocGridField(MOVDOC_CONTA_X, rowY, "conta")

        if (conta = "" || convenio = "")
            continue

        key := protocolo "|" conta "|" convenio
        if vistos.Has(key)
            continue

        vistos[key] := true
        linhas.Push(Map("protocolo", protocolo, "conta", conta, "convenio", convenio))
        added++
    }

    return added
}

RP_ConvenioMajoritario(linhas) {
    counts := Map()
    ordem := []

    for _, linha in linhas {
        convenio := linha["convenio"]
        if !counts.Has(convenio) {
            counts[convenio] := 0
            ordem.Push(convenio)
        }
        counts[convenio] += 1
    }

    escolhido := ""
    maior := 0
    for _, convenio in ordem {
        if (counts[convenio] > maior) {
            maior := counts[convenio]
            escolhido := convenio
        }
    }
    return escolhido
}

RP_FiltrarContasPorConvenio(linhas, convenioEscolhido, erros) {
    protocolContas := Map()

    for _, linha in linhas {
        protocolo := linha["protocolo"]
        conta := linha["conta"]
        convenio := linha["convenio"]

        if (convenio != convenioEscolhido) {
            erros.Push(Map("protocolo", protocolo, "conta", conta, "descricao", "Convênio diferente: " convenio))
            continue
        }

        if !protocolContas.Has(protocolo)
            protocolContas[protocolo] := []
        protocolContas[protocolo].Push(Map("conta", conta, "convenio", convenio))
    }

    return protocolContas
}

RP_MovDocPopupVisible() {
    return WinExist(WIN_MOVDOC_POPUP)
}

RP_MovDocPopupWindowVisible() {
    return WinExist(WIN_MOVDOC_POPUP)
}

RP_DismissMovDocPopup() {
    try {
        if WinExist(WIN_MOVDOC_POPUP) {
            WinActivate WIN_MOVDOC_POPUP
            Sleep MV_DELAY_INPUT
            if !MV_ClickFirstControl(WIN_MOVDOC_POPUP, MV_MODAL_OK_CLASS)
                return false
            return MV_Poll(() => !WinExist(WIN_MOVDOC_POPUP), MV_TIMEOUT_ACOE)
        }
    }
    return false
}

RP_FinalizarBaixaProtocolo() {
    ; Checkbox Recebido: estado vem do controle Button1.
    ; Regra validada pelo usuário: 0 → click simples; 1 → double click.
    checked := MV_ControlCheckedAt(WIN_MOVDOC_BAIXA, MOVDOC_CHECK_RECEBIDO_CLASS, MOVDOC_CHECK_RECEBIDO_X, MOVDOC_CHECK_RECEBIDO_Y)

    if (checked = 0) {
        if !MV_ClickControlAt(WIN_MOVDOC_BAIXA, MOVDOC_CHECK_RECEBIDO_CLASS, MOVDOC_CHECK_RECEBIDO_X, MOVDOC_CHECK_RECEBIDO_Y)
            return false
    } else if (checked = 1) {
        if !MV_DoubleClickControlAt(WIN_MOVDOC_BAIXA, MOVDOC_CHECK_RECEBIDO_CLASS, MOVDOC_CHECK_RECEBIDO_X, MOVDOC_CHECK_RECEBIDO_Y)
            return false
    } else {
        return false
    }

    Sleep RP_KEY_SETTLE_MS

    ; Fluxo validado: checkbox → F10 → clicar campo Protocolo → F7.
    ; Não há popup de confirmação aqui; o próximo F8 valida a consulta pela grid legível.
    Send "{F10}"
    Sleep RP_KEY_SETTLE_MS

    if !MV_FocusEditAtPoint(WIN_MOVDOC_BAIXA, MOVDOC_PROTOCOLO_X, MOVDOC_PROTOCOLO_Y)
        return false

    Sleep RP_KEY_SETTLE_MS
    Send "{F7}"
    Sleep RP_KEY_SETTLE_MS
    return true
}

RP_WaitMovDocFirstGridLineReady(protocolo) {
    startedAt := A_TickCount
    deadline := startedAt + 12000

    Loop {
        conta := RP_ReadMovDocGridField(MOVDOC_CONTA_X, MOVDOC_GRID_ROWS_Y[1], "conta", 100, 200)
        convenio := RP_ReadMovDocGridField(MOVDOC_CONVENIO_X, MOVDOC_GRID_ROWS_Y[1], "convenio", 100, 200)

        if (conta != "" && convenio != "" && conta != protocolo && convenio != protocolo) {
            Notify("MOV DOC: primeira linha legível após F8 em " (A_TickCount - startedAt) "ms.")
            return true
        }

        if (A_TickCount >= deadline)
            return false

        Sleep 80
    }
}

RP_ReadMovDocGridField(x, y, campo := "", fastTimeoutMs := 150, fallbackTimeoutMs := 300) {
    if !WinExist(WIN_MOVDOC_BAIXA)
        return ""

    WinActivate WIN_MOVDOC_BAIXA
    MV_Poll(() => WinActive(WIN_MOVDOC_BAIXA), 2)
    CoordMode("Mouse", "Client")

    Click(x + 15, y + 8, 1)
    Sleep RP_KEY_SETTLE_MS
    Send("{Home}{Shift down}{End}{Shift up}")

    valor := RP_CopySelectedText(fastTimeoutMs)
    if RP_GridValueValid(valor, campo)
        return valor

    valor := RP_CopySelectedText(fallbackTimeoutMs)
    if RP_GridValueValid(valor, campo)
        return valor

    return ""
}

RP_CopySelectedText(timeoutMs := 500) {
    A_Clipboard := ""
    Send("^c")
    if !ClipWait(timeoutMs / 1000)
        return ""
    return Trim(A_Clipboard)
}

RP_GridValueValid(valor, campo := "") {
    valor := Trim(valor)
    if (valor = "")
        return false
    if !RegExMatch(valor, "^\d+$")
        return false
    if (campo = "convenio" && StrLen(valor) >= 4)
        return false
    if (campo = "conta" && StrLen(valor) < 5)
        return false
    return true
}

RP_WaitLoadingAfterF8() {
    ; Mantida para compatibilidade; o fluxo principal usa RP_WaitMovDocFirstGridLineReady.
    return MV_Poll(() => WinExist(WIN_MOVDOC_BAIXA), MV_TIMEOUT_LOAD)
}

RP_WaitLoadingAfterSave() {
    ; Mantida para compatibilidade. O fluxo validado não espera popup após F10;
    ; prepara nova consulta com clique no protocolo + F7.
    return WinExist(WIN_MOVDOC_BAIXA)
}

; ════════════════════════════════════════════════════════════════
;  FASE FFCV
; ════════════════════════════════════════════════════════════════

RP_AbrirManutencaoRemessaFFCV() {
    ; Sempre abre uma nova instância da tela funcional. Não reutilizar Manutenção já aberta.
    MV_ActivateModule(MV_WIN_FFCV_ANY)
    Sleep MV_DELAY_INPUT

    ; Atalho validado no macro 03: Lançamentos → Manutenção de Remessa.
    Send "{Alt down}lm{Alt up}{Enter}"

    return MV_Poll(() => WinExist(MV_WIN_FFCV_REMESSA), MV_TIMEOUT_LOAD)
}

CarregarConvenioFFCV(convenioNum) {
    MV_ActivateModule(MV_WIN_FFCV_ANY)
    Send "{F7}"
    Sleep RP_KEY_SETTLE_MS
    SendText convenioNum
    Sleep RP_KEY_SETTLE_MS
    Send "{F8}"
    return RP_WaitFFCVLoad()
}

PosicionarAreaRemessas() {
    Send "{Tab 3}"
    Sleep RP_KEY_SETTLE_MS
}

SelecionarRemessaExistente(numRemessa) {
    Send "{F7}"
    Sleep RP_KEY_SETTLE_MS
    SendText numRemessa
    Sleep RP_KEY_SETTLE_MS
    Send "{F8}"
    return RP_WaitFFCVLoad()
}

CriarNovaRemessa(tipoConta) {
    Send "{F6}"
    Sleep RP_KEY_SETTLE_MS

    hoje := FormatTime(, "dd/MM/yyyy")
    SendText hoje
    Sleep RP_KEY_SETTLE_MS
    Send "{Tab 3}"
    Sleep RP_KEY_SETTLE_MS
    SendText TIPO_CODIGO[tipoConta]
    Sleep RP_KEY_SETTLE_MS
    Send "{F10}"
    return RP_WaitFFCVLoad()
}

InserirContasNaRemessa(protocolContas, tipoConta, erros) {
    totalContas := ContarContas(protocolContas)
    contaIdx := 0

    if !RP_AbrirConfigurarPopupContas(tipoConta)
        return false

    for protocolo, contas in protocolContas {
        for _, contaObj in contas {
            contaIdx++
            numConta := contaObj["conta"]
            Notify("Enviando conta " numConta " [prot. " protocolo "]")

            outcome := EnviarConta(numConta)
            if (outcome["status"] = "modal") {
                erroTexto := outcome["texto"]
                if InStr(StrLower(erroTexto), StrLower(ERR_JA_DIGITADA)) {
                    RP_DismissActiveModal()
                } else {
                    erros.Push(Map("protocolo", protocolo, "conta", numConta, "descricao", ClassificarErro(erroTexto)))
                    RP_DismissActiveModal()
                }

                if !MV_Poll(() => RP_FFCVContaPopupVisible(), MV_TIMEOUT_ACOE)
                    return RP_Abort("Modal foi fechado, mas o popup de conta não voltou/estabilizou após a conta " numConta ".")
            } else if (outcome["status"] = "ready") {
                ; Popup permanece aberto para a próxima conta.
            } else {
                return RP_Abort("Estado incerto após enviar conta " numConta ": " outcome["erro"])
            }

            Progress(60 + (contaIdx / totalContas) * 25)
        }
    }

    if !RP_CloseContaPopupAndWait(5000)
        return RP_Abort("Lote de contas terminou, mas não consegui fechar o popup de conta com Alt+2.")

    return true
}

RP_AbrirConfigurarPopupContas(tipoConta) {
    if !RP_EnsureFFCVActive()
        return RP_Abort("FFCV não ficou ativa antes de clicar em Inserir Conta.")

    if !MV_ClickControlAt(MV_WIN_FFCV_ANY, FFCV_BTN_ADICIONAR, 24, 458, 20)
        return RP_Abort("Não consegui clicar em Inserir Conta no FFCV.")

    popupReady := RP_WaitContaPopupReady(5000)
    if !popupReady["ok"]
        return RP_Abort(popupReady["erro"])
    Notify("Popup Informações da Conta detectado em " popupReady["elapsed"] "ms.")

    if RP_ActiveModalTitle() != "" && !RP_FFCVContaPopupVisible()
        return RP_Abort("Modal apareceu antes do popup de conta: " RP_SafeWinGetText(RP_ActiveModalTitle()))

    if !RP_EnsureFFCVActive()
        return RP_Abort("FFCV não ficou ativa antes dos atalhos do popup de conta.")

    stable := RP_WaitContaPopupStable(300)
    if !stable["ok"]
        return RP_Abort(stable["erro"])

    if !ConfigurarDropdownsPopup(tipoConta)
        return RP_Abort("Não consegui configurar o popup de conta por atalhos.")

    Notify("Popup de conta configurado e mantido aberto para o lote.")
    return true
}

RP_WaitContaPopupAfterOpen(timeoutSecs := 5) {
    ready := RP_WaitContaPopupReady(timeoutSecs * 1000)
    return ready["ok"]
}

RP_FFCVContaPopupVisible() {
    sentinel := RP_FindControlByClassPrefixAtPoint(MV_WIN_FFCV_ANY, "ui60Drawn", FFCV_POPUP_CONTA_SENTINEL_X, FFCV_POPUP_CONTA_SENTINEL_Y, 35)
    if !sentinel
        return false

    campoConta := MV_FindControlByClientPoint(MV_WIN_FFCV_ANY, POPUP_CAMPO_CONTA, POPUP_CAMPO_CONTA_X, POPUP_CAMPO_CONTA_Y, 35)
    if !campoConta
        campoConta := RP_FindControlByClassPrefixAtPoint(MV_WIN_FFCV_ANY, "Edit", POPUP_CAMPO_CONTA_X, POPUP_CAMPO_CONTA_Y, 35)

    return campoConta != 0
}

RP_EnsureFFCVActive(timeoutSecs := 3) {
    if !WinExist(MV_WIN_FFCV_ANY)
        return false
    WinActivate MV_WIN_FFCV_ANY
    return MV_Poll(() => WinActive(MV_WIN_FFCV_ANY), timeoutSecs)
}

RP_WaitContaPopupReady(timeoutMs) {
    startedAt := A_TickCount
    Loop {
        if RP_ActiveModalTitle() != ""
            return Map("ok", true, "modal", true, "elapsed", A_TickCount - startedAt, "erro", "")

        if RP_FFCVContaPopupVisible()
            return Map("ok", true, "modal", false, "elapsed", A_TickCount - startedAt, "erro", "")

        if (A_TickCount - startedAt >= timeoutMs)
            return Map("ok", false, "modal", false, "elapsed", A_TickCount - startedAt, "erro", "Popup Informações da Conta não apareceu após Inserir Conta em " timeoutMs "ms. Verifique sentinela ui60Drawn no ponto Client " FFCV_POPUP_CONTA_SENTINEL_X "," FFCV_POPUP_CONTA_SENTINEL_Y " e campo da conta em " POPUP_CAMPO_CONTA_X "," POPUP_CAMPO_CONTA_Y ".")

        Sleep 20
    }
}

RP_WaitContaPopupStable(stableMs := 300, timeoutMs := 1200) {
    startedAt := A_TickCount
    stableSince := 0
    Loop {
        if RP_ActiveModalTitle() != ""
            return Map("ok", false, "erro", "Modal apareceu enquanto aguardava estabilidade do popup de conta.")

        if RP_FFCVContaPopupVisible() {
            if (stableSince = 0)
                stableSince := A_TickCount
            if (A_TickCount - stableSince >= stableMs)
                return Map("ok", true, "erro", "")
        } else {
            stableSince := 0
        }

        if (A_TickCount - startedAt >= timeoutMs)
            return Map("ok", false, "erro", "Popup de conta não estabilizou por " stableMs "ms dentro de " timeoutMs "ms.")

        Sleep 20
    }
}

RP_WaitReadyForNextAccount(timeoutMs) {
    if RP_ActiveModalTitle() != ""
        return RP_DismissActiveModal()

    ; Regra nova: o popup de conta pode permanecer aberto durante todo o lote.
    return true
}

RP_CloseContaPopupAndWait(timeoutMs := 5000) {
    ; Regra: manter o popup aberto durante o lote e fechar com Alt+2 somente ao final.
    if !RP_FFCVContaPopupVisible()
        return true

    if !RP_EnsureFFCVActive()
        return false

    Send "!2"
    startedAt := A_TickCount
    Loop {
        if (!RP_FFCVContaPopupVisible() && (RP_ActiveModalTitle() = ""))
            return true
        if (A_TickCount - startedAt >= timeoutMs)
            return false
        Sleep 20
    }
}

RP_FindControlByClassPrefixAtPoint(winTitle, classPrefix, targetX, targetY, tolerance := 35) {
    try hwnds := WinGetControlsHwnd(winTitle)
    catch
        return 0

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

    return (bestHwnd && bestDist <= tolerance) ? bestHwnd : 0
}

ConfigurarDropdownsPopup(tipoConta) {
    ; Foco inicial do popup nem sempre é confiável. A regra validada pelo usuário:
    ; Tab x3 → dropdown 1 → Down x2 → Tab → dropdown 2 → se Emergência/Ambulatório Up x2 → Tab.
    if !RP_EnsureFFCVActive()
        return false

    if (tipoConta = "Internamento")
        Send "{Tab 3}{Down 2}{Tab}{Tab}"
    else
        Send "{Tab 3}{Down 2}{Tab}{Up 2}{Tab}"

    Sleep RP_KEY_SETTLE_MS
    return true
}

EnviarConta(numConta) {
    if !RP_LimparCampoContaEnviar(numConta)
        return Map("status", "blocker", "erro", "Não consegui limpar/digitar a conta " numConta ".", "texto", "")

    return RP_WaitContaSubmitOutcome(FFCV_CONTA_SUBMIT_TIMEOUT_MS, numConta)
}

RP_LimparCampoContaEnviar(numConta) {
    if !RP_FFCVContaPopupVisible()
        return false
    if !RP_EnsureFFCVActive()
        return false

    CoordMode("Mouse", "Client")
    Click(POPUP_CAMPO_CONTA_X + 15, POPUP_CAMPO_CONTA_Y + 8, 1)
    Sleep RP_FIELD_FOCUS_SETTLE_MS
    Send("{Home}{Shift down}{End}{Shift up}{Backspace}")
    Sleep RP_FIELD_CLEAR_SETTLE_MS
    SendText numConta
    Send "{Enter}"
    return true
}

RP_GetContaFieldText() {
    hwnd := RP_FindControlByClassPrefixAtPoint(MV_WIN_FFCV_ANY, "Edit", POPUP_CAMPO_CONTA_X, POPUP_CAMPO_CONTA_Y, 35)
    if !hwnd
        return ""
    try return Trim(ControlGetText(hwnd))
    catch
        return ""
}

RP_WaitContaSubmitOutcome(timeoutMs, submittedConta := "") {
    startTick := A_TickCount
    deadline := startTick + timeoutMs
    stableSince := 0
    emptySince := 0

    Loop {
        popup := RP_ActiveModalTitle()
        if (popup != "")
            return Map("status", "modal", "erro", "", "texto", RP_SafeWinGetText(popup))

        fieldText := RP_GetContaFieldText()
        if (submittedConta != "" && fieldText != submittedConta && fieldText = "") {
            if (emptySince = 0)
                emptySince := A_TickCount
            if (A_TickCount - emptySince >= FFCV_CONTA_FIELD_EMPTY_MIN_MS)
                return Map("status", "ready", "erro", "", "texto", "")
        } else {
            emptySince := 0
        }

        if RP_FFCVContaPopupVisible() {
            if (stableSince = 0)
                stableSince := A_TickCount
            if (A_TickCount - startTick >= FFCV_CONTA_READY_MIN_MS && A_TickCount - stableSince >= FFCV_CONTA_STABLE_MS)
                return Map("status", "ready", "erro", "", "texto", "")
        } else {
            stableSince := 0
        }

        if (A_TickCount > deadline) {
            if (stableSince != 0 && A_TickCount - stableSince >= FFCV_CONTA_STABLE_MS)
                return Map("status", "ready", "erro", "", "texto", "")
            return Map("status", "timeout", "erro", "Timeout aguardando modal ou popup estável após Enter.", "texto", "")
        }

        Sleep 15
    }
}

RP_WaitErrorModalAfterConta(timeoutSecs) {
    deadline := A_TickCount + timeoutSecs * 1000
    Loop {
        popup := RP_ActiveModalTitle()
        if (popup != "")
            return popup
        if (A_TickCount > deadline)
            return ""
        Sleep MV_POLL_MS
    }
}

RP_ActiveModalTitle() {
    if WinExist("ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE")
        return "ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"
    return ""
}

RP_DismissActiveModal() {
    try {
        popup := RP_ActiveModalTitle()
        if (popup != "") {
            WinActivate popup
            Sleep MV_DELAY_INPUT
            if MV_ClickFirstControl(popup, MV_MODAL_OK_CLASS) {
                MV_Poll(() => !WinExist(popup), MV_TIMEOUT_ACOE)
                return true
            }
        }
    }
    return false
}

RP_SafeWinGetText(winTitle) {
    try text := WinGetText(winTitle)
    catch as e
        return "<erro WinGetText: " e.Message ">"

    text := Trim(text)
    if (text = "" || text = "&OK" || text = "&Sim`r`n&Não" || text = "&Não`r`n&Sim")
        return text "`n<observação: Oracle Forms pode desenhar a mensagem em ui60Drawn; WinGetText pode expor só botões.>"
    return text
}

ClassificarErro(textoPopup) {
    lower := StrLower(textoPopup)
    if InStr(lower, StrLower(ERR_CONVENIO_DIFERENTE))
        return "Conta de outro convênio"
    if InStr(lower, StrLower(ERR_CONTA_ABERTA))
        return "Conta aberta"
    if InStr(lower, StrLower(ERR_TIPO_DIFERENTE))
        return "Conta de outro tipo"
    return Trim(textoPopup)
}

RP_WaitFFCVLoad() {
    ; Não há popup de confirmação no FFCV nesses passos. Esta função é só um micro-settle
    ; para o Oracle Forms consumir F8/F10; a validação real acontece na próxima ação observável
    ; (popup de conta, tela de datas, XML gerado etc.).
    Sleep RP_KEY_SETTLE_MS
    return WinExist(MV_WIN_FFCV_ANY)
}

RP_WaitAnyModalOrDelay(timeoutSecs) {
    return MV_Poll(() => WinExist("ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"), timeoutSecs)
}

; ════════════════════════════════════════════════════════════════
;  FASE FINALIZAÇÃO / XML
; ════════════════════════════════════════════════════════════════

FinalizarSemDatas() {
    Send "!6"
    if !MV_Poll(() => WinExist(WIN_CAPA_REMESSA), MV_TIMEOUT_LOAD)
        return
    Send "{Enter}"
    MV_Poll(() => !WinExist(WIN_CAPA_REMESSA), MV_TIMEOUT_LOAD)
}

FinalizarComDatas(dataEntrega, dataVenc) {
    if !RP_EnsureFFCVActive()
        return Map("ok", false, "erro", "FFCV não ficou ativa antes de abrir a tela de fechar remessa/datas.")

    startedAt := A_TickCount
    if !MV_ClickControlAt(MV_WIN_FFCV_ANY, FFCV_BTN_ABRIR_DATAS, 464, 458, 20)
        return Map("ok", false, "erro", "Não consegui clicar em Entregar Remessa.")

    if !MV_Poll(() => WinExist(WIN_FFCV_DATAS), MV_TIMEOUT_LOAD)
        return Map("ok", false, "erro", "Tela de fechar remessa/datas não abriu.")
    Notify("Tela de datas detectada em " (A_TickCount - startedAt) "ms.")

    datas := RP_PreencherDatasEntregaPorTeclado(dataEntrega, dataVenc)
    if !datas["ok"]
        return Map("ok", false, "erro", datas["erro"])
    numRemessa := datas["remessa"]

    checkedFecharContas := MV_ControlCheckedAt(WIN_FFCV_DATAS, DATAS_CHECKBOX, DATAS_CHECKBOX_X, DATAS_CHECKBOX_Y)
    if (checkedFecharContas = 0) {
        if !MV_ClickControlAt(WIN_FFCV_DATAS, DATAS_CHECKBOX, DATAS_CHECKBOX_X, DATAS_CHECKBOX_Y)
            return Map("ok", false, "erro", "Não consegui marcar 'Fechar contas sem imprimir faturas'.")
    } else if (checkedFecharContas = "") {
        return Map("ok", false, "erro", "Não consegui ler o estado de 'Fechar contas sem imprimir faturas'.")
    }
    Sleep MV_DELAY_INPUT

    if !MV_ClickControlAt(WIN_FFCV_DATAS, DATAS_BTN_CONFIRMAR, DATAS_BTN_CONFIRMAR_X, DATAS_BTN_CONFIRMAR_Y)
        return Map("ok", false, "erro", "Não consegui confirmar a entrega da remessa.")
    if !RP_WaitAnyModalOrDelay(MV_TIMEOUT_ACOE)
        return Map("ok", false, "erro", "Popup de confirmação não apareceu.")
    if !RP_ClickNaoModal()
        return Map("ok", false, "erro", "Não consegui clicar Não no popup de confirmação.")

    if !MV_Poll(() => WinExist(WIN_CAPA_REMESSA), MV_TIMEOUT_LOAD)
        return Map("ok", false, "erro", "Tela de impressão não apareceu.")

    Send "{Enter}"
    MV_Poll(() => !WinExist(WIN_CAPA_REMESSA), MV_TIMEOUT_LOAD)

    if !RP_SairTelaEntregaPendente()
        return Map("ok", false, "erro", "Atalho para sair da tela Entrega de Remessas ainda não mapeado. Preencha RP_ENTREGA_SAIR_ATALHO para continuar até XML.")
    return Map("ok", true, "remessa", Trim(numRemessa))
}

RP_SairTelaEntregaPendente() {
    if (Trim(RP_ENTREGA_SAIR_ATALHO) = "") {
        Notify("Pendente: atalho para sair da tela Entrega de Remessas ainda não mapeado. Esc foi removido porque não funciona.")
        return false
    }

    if !RP_EnsureWindowActive(WIN_FFCV_DATAS) {
        Notify("Não consegui ativar a tela Entrega de Remessas para enviar o atalho de saída.")
        return false
    }

    Send RP_ENTREGA_SAIR_ATALHO
    return MV_Poll(() => !WinExist(WIN_FFCV_DATAS), MV_TIMEOUT_ACOE)
}

RP_PreencherDatasEntregaPorTeclado(dataEntrega, dataVenc) {
    if !RP_EnsureWindowActive(WIN_FFCV_DATAS)
        return Map("ok", false, "erro", "Tela de datas não ficou ativa para preencher entrega/vencimento.", "remessa", "")

    CoordMode("Mouse", "Client")
    Click(DATAS_CAMPO_ENTREGA_X + 15, DATAS_CAMPO_ENTREGA_Y + 8, 1)
    Sleep RP_KEY_SETTLE_MS

    Send("+{Tab}")
    Sleep RP_KEY_SETTLE_MS
    numRemessa := RP_CopyFocusedNumericText(600)
    if (numRemessa = "")
        return Map("ok", false, "erro", "Não consegui copiar o número da remessa via Shift+Tab na tela de datas.", "remessa", "")

    Send("{Tab}")
    Sleep RP_KEY_SETTLE_MS
    SendText dataEntrega
    Sleep RP_KEY_SETTLE_MS
    Send("{Enter}")
    Sleep RP_KEY_SETTLE_MS
    SendText dataVenc
    Sleep RP_KEY_SETTLE_MS
    Notify("Datas enviadas por teclado. Remessa " numRemessa ", entrega " dataEntrega ", vencimento " dataVenc ".")

    return Map("ok", true, "erro", "", "remessa", numRemessa)
}

GerarXML(numRemessa) {
    global gWorkDir

    if !RP_AbrirTelaTISS()
        return Notify("Erro: tela XML/TISS não abriu.")

    if !RP_SetTextByClickNoClear(WIN_XML, XML_CAMPO_REMESSA_X, XML_CAMPO_REMESSA_Y, numRemessa)
        return RP_Abort("Não consegui preencher a remessa na tela XML/TISS.")
    Sleep RP_KEY_SETTLE_MS
    Send "{F8}"
    RP_WaitFFCVLoad()

    if !MV_ClickControlAt(WIN_XML, XML_BTN_FATURAMENTO, XML_BTN_FATURAMENTO_X, XML_BTN_FATURAMENTO_Y)
        return RP_Abort("Não consegui acionar o botão Faturamento na tela XML/TISS.")

    faturamento := RP_WaitXmlFormOrModal(MV_TIMEOUT_LOAD)
    if !faturamento["ok"]
        return RP_Abort(faturamento["erro"])

    xmlDir := gWorkDir "\XML"
    if !DirExist(xmlDir)
        DirCreate xmlDir

    xmlPath := xmlDir "\" numRemessa ".xml"

    if !RP_SetTextByClickAt(WIN_XML_PATH_FORM, XML_FORM_CAMPO_PATH_X, XML_FORM_CAMPO_PATH_Y, xmlPath)
        return RP_Abort("Não consegui preencher o campo de caminho do XML.")

    if !MV_ClickControlAt(WIN_XML_PATH_FORM, XML_FORM_BTN_SALVAR, XML_FORM_BTN_SALVAR_X, XML_FORM_BTN_SALVAR_Y)
        return RP_Abort("Não consegui acionar o botão Salvar_XML.")

    RP_HandleXmlSaveModals()

    if !MV_ClickControlAt(WIN_XML_PATH_FORM, XML_FORM_BTN_VOLTAR, XML_FORM_BTN_VOLTAR_X, XML_FORM_BTN_VOLTAR_Y)
        return RP_Abort("Não consegui voltar da tela de XML gerado.")
    Sleep 500

    RP_SairTelaAtual()
}

RP_AbrirTelaTISS() {
    ; Sempre abre uma nova instância da tela funcional. Não reutilizar TISS já aberta.
    if !RP_EnsureFFCVActive()
        return false

    startedAt := A_TickCount

    ; Atalho esperado: Lançamentos → Monitoração de Faturamento - TISS.
    Send "{Alt down}lt{Alt up}{Enter}"

    ok := MV_Poll(() => WinExist(WIN_XML), MV_TIMEOUT_LOAD)
    if ok
        Notify("Tela XML/TISS detectada em " (A_TickCount - startedAt) "ms.")
    return ok
}

RP_CopyFocusedText() {
    A_Clipboard := ""
    Send "^c"
    MV_Poll(() => A_Clipboard != "", 3)
    return Trim(A_Clipboard)
}

RP_CopyFocusedNumericText(timeoutMs := 600) {
    A_Clipboard := ""
    Send("^c")
    if !ClipWait(timeoutMs / 1000)
        return ""

    value := Trim(A_Clipboard)
    if RegExMatch(value, "\d+", &m)
        return m[0]
    return ""
}

RP_EnsureWindowActive(winTitle, timeoutSecs := 3) {
    if !WinExist(winTitle)
        return false
    WinActivate winTitle
    return MV_Poll(() => WinActive(winTitle), timeoutSecs)
}

RP_SetTextByClickAt(winTitle, x, y, value) {
    if !RP_EnsureWindowActive(winTitle)
        return false

    CoordMode("Mouse", "Client")
    Click(x + 15, y + 8, 1)
    Sleep RP_FIELD_FOCUS_SETTLE_MS
    Send("{Home}{Shift down}{End}{Shift up}{Backspace}")
    Sleep RP_FIELD_CLEAR_SETTLE_MS
    SendText value
    Sleep RP_KEY_SETTLE_MS
    return true
}

RP_SetTextByClickNoClear(winTitle, x, y, value) {
    if !RP_EnsureWindowActive(winTitle)
        return false

    CoordMode("Mouse", "Client")
    Click(x + 15, y + 8, 1)
    Sleep RP_FIELD_FOCUS_SETTLE_MS
    SendText value
    Sleep RP_KEY_SETTLE_MS
    return true
}

RP_WaitXmlFormOrModal(timeoutSecs := 20) {
    startedAt := A_TickCount
    deadline := startedAt + timeoutSecs * 1000

    Loop {
        if WinExist(WIN_XML_PATH_FORM)
            return Map("ok", true, "erro", "")

        popup := RP_ActiveModalTitle()
        if (popup != "") {
            if RP_ClickModalButtonByText(popup, "&OK") {
                ; Modal pós-1 Faturamento é continuável. Não depender do texto desenhado.
                MV_Poll(() => !WinExist("ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"), MV_TIMEOUT_ACOE)
            } else {
                return Map("ok", false, "erro", "Modal após 1 Faturamento apareceu, mas não encontrei botão &OK acessível.")
            }
        }

        if (A_TickCount >= deadline)
            return Map("ok", false, "erro", "Tela de XML gerado não apareceu após tratar possíveis modais em " timeoutSecs "s.")

        Sleep MV_POLL_MS
    }
}

RP_HandleXmlSaveModals() {
    Loop 3 {
        if !MV_Poll(() => WinExist("ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"), 2) {
            if (A_Index = 1)
                Notify("Nenhum modal apareceu após salvar XML.")
            return true
        }

        popup := RP_ActiveModalTitle()

        ; Modal de sobrescrita: tem Sim e Não. Regra atual: não sobrescrever.
        if RP_ModalHasButton(popup, "&Sim") && RP_ModalHasButton(popup, "&Não") {
            if RP_ClickModalButtonByText(popup, "&Não")
                Notify("Modal com Sim/Não respondido com Não.")
            else
                return RP_Abort("Modal com Sim/Não apareceu, mas não consegui clicar Não.")
        } else if RP_ModalHasButton(popup, "&OK") {
            if RP_ClickModalButtonByText(popup, "&OK")
                Notify("Modal informativo do XML fechado com OK.")
            else
                return RP_Abort("Modal com OK apareceu, mas não consegui clicar OK.")
        } else {
            return RP_Abort("Modal do XML apareceu, mas não encontrei botão seguro (&Não ou &OK).")
        }

        MV_Poll(() => !WinExist("ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"), MV_TIMEOUT_ACOE)
    }
    return true
}

RP_ClickModalButtonByText(winTitle, buttonText) {
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

RP_ModalHasButton(winTitle, buttonText) {
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

RP_ClickNaoModal() {
    if WinExist(WIN_XML_POPUP_SIMNAO)
        return MV_ClickFirstControl(WIN_XML_POPUP_SIMNAO, XML_BTN_NAO)
    popup := RP_ActiveModalTitle()
    if (popup != "")
        return MV_ClickFirstControl(popup, XML_BTN_NAO)
    return false
}

RP_SairTelaAtual() {
    Send "{Esc}"
    Sleep MV_DELAY_INPUT
    return true
}

; ════════════════════════════════════════════════════════════════
;  UTILITÁRIOS
; ════════════════════════════════════════════════════════════════

RP_RequireClientControl(classNN, x, y, label) {
    return !(classNN = "" || classNN = "CLASSNN" || x = "" || y = "")
}

RP_SetControlText(winTitle, classNN, value, label) {
    if (classNN = "" || classNN = "CLASSNN")
        return RP_Abort("Falta mapear " label ".")
    try {
        ControlSetText value, classNN, winTitle
        Sleep MV_DELAY_INPUT
        return true
    } catch as e {
        return RP_Abort("Falha ao preencher " label ": " e.Message)
    }
}

ParseProtocolos(str) {
    result := []
    for _, p in StrSplit(str, ",") {
        p := Trim(p)
        if (p != "")
            result.Push(p)
    }
    return result
}

ContarContas(protocolContas) {
    total := 0
    for _, contas in protocolContas
        total += contas.Length
    return total
}

RP_RecordTiming(timings, label, startedAt, extra := "") {
    elapsedMs := A_TickCount - startedAt
    timings.Push(Map("label", label, "ms", elapsedMs, "extra", extra))
    Notify("⏱ " label ": " RP_FormatDuration(elapsedMs) (extra != "" ? " | " extra : ""))
    return elapsedMs
}

RP_FormatDuration(ms) {
    if (ms < 1000)
        return ms "ms"

    totalSecs := Round(ms / 1000, 1)
    if (totalSecs < 60)
        return totalSecs "s"

    mins := Floor(totalSecs / 60)
    secs := Round(Mod(totalSecs, 60), 1)
    return mins "min " secs "s"
}

RP_FormatTimingReport(timings) {
    report := "⏱ Tempos da execução:`n"
    for _, item in timings {
        extra := item["extra"] != "" ? " | " item["extra"] : ""
        report .= "  - " item["label"] ": " RP_FormatDuration(item["ms"]) extra "`n"
    }
    return report
}

RP_Abort(msg) {
    global gRunning
    SendToUI(Map("type", "error", "message", msg))
    gRunning := false
    return false
}

Notify(msg) => SendToUI(Map("type", "log", "message", msg))
Progress(v)  => SendToUI(Map("type", "progress", "value", v))
Done(msg)    => SendToUI(Map("type", "done", "message", msg))
