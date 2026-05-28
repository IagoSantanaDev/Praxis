; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Include mv_session.ahk
#Include ..\lib\FFCV_ErrorTemplates.ahk

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
RP_ENTREGA_SAIR_ATALHO := "^q"

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

; ── Fragmentos/classificação de erros no popup de envio ───────
; Modais Oracle Forms não expõem a mensagem pelo Window Spy/WinGetText de forma confiável.
; A classificação confiável deve vir de templates visuais; texto acessível é apenas fallback.
ERR_JA_DIGITADA        := "já digitada"
ERR_CONVENIO_DIFERENTE := "convênio diferente"
ERR_CONTA_ABERTA       := "conta aberta"
ERR_CONTA_JA_EM_REMESSA := "já em remessa"
ERR_TIPO_DIFERENTE     := "tipo diferente"
ERROR_TEMPLATES := FFCV_ErrorTemplates()

; ── Entrada por teclado/campo Oracle Forms ─────────────────────
; Padrão validado no macro 11: micro-settle suficiente para estabilidade sem sleeps longos.
RP_FIELD_FOCUS_SETTLE_MS := 100
RP_FIELD_CLEAR_SETTLE_MS := 100
RP_KEY_SETTLE_MS         := 100

; ── Performance FFCV Inserir Conta ─────────────────────────────
; Contrato do macro 11: manter popup aberto, reagir ao modal e liberar próxima conta por estado.
FFCV_CONTA_FOCUS_SETTLE_MS      := RP_FIELD_FOCUS_SETTLE_MS
FFCV_CONTA_CLEAR_SETTLE_MS      := RP_FIELD_CLEAR_SETTLE_MS
FFCV_CONTA_READY_MIN_MS         := 180
FFCV_CONTA_FIELD_EMPTY_MIN_MS   := 100
FFCV_CONTA_STABLE_MS            := 100
FFCV_CONTA_SUBMIT_TIMEOUT_MS    := 650

; ── Esperas da fase de fechamento/XML ─────────────────────────
; Esta fase dispara processamentos pesados no Oracle Forms. Evitar avançar apenas
; porque o clique foi aceito; aguardar janela/modal/cursor estabilizarem.
RP_FINAL_STABLE_MS             := 800
RP_FINAL_ACTION_TIMEOUT_MS     := 30000
RP_XML_QUERY_MIN_WAIT_MS       := 1200

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
        if !GerarXML(result["remessa"])
            return false
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
        linhas := "Remessa concluída com sucesso!`n`n" timingReport
        linhas .= "`nConcluído com " erros.Length " pendência(s):`n"
        linhas .= "PROTOCOLO | CONTA | ERRO`n"
        for _, e in erros
            linhas .= "  [[red]]" e["protocolo"] " | " e["conta"] " | " e["descricao"] "[[/red]]`n"
        Done(linhas)
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
    if !MV_WaitWindowStable(MV_WIN_MOVDOC_ANY, MV_MODULE_STABLE_MS, MV_TIMEOUT_LOAD)
        return false

    ; Atalho validado no macro 02: Manutenção → Protocolação → Baixa.
    Send "{Alt down}mpb{Alt up}"

    if !MV_Poll(() => WinExist(WIN_MOVDOC_BAIXA), MV_TIMEOUT_LOAD)
        return false

    return MV_WaitWindowStable(WIN_MOVDOC_BAIXA, MV_TARGET_STABLE_MS, MV_TIMEOUT_LOAD)
}

ProcessarProtocolo(protocolo) {
    WinActivate WIN_MOVDOC_BAIXA
    if !RP_SetProtocoloMovDocByClick(protocolo)
        return Map("ok", false, "erro", "Não consegui focar/preencher o campo Protocolo.")

    Sleep MV_DELAY_INPUT
    Send "{F8}"
    if !RP_WaitMovDocFirstGridLineReady(protocolo, &primeiraLinhaValida)
        return Map("ok", false, "erro", "A primeira linha da grid não ficou legível após F8 para o protocolo " protocolo ".")

    linhas := RP_ColetarLinhasMovDoc(protocolo, primeiraLinhaValida)
    if (linhas.Length = 0)
        return Map("ok", false, "erro", "Nenhuma conta/convênio foi coletado para o protocolo " protocolo ".")

    if !RP_FinalizarBaixaProtocolo()
        return Map("ok", false, "erro", "Falha ao salvar/baixar o protocolo " protocolo ".")

    return Map("ok", true, "linhas", linhas)
}

RP_SetProtocoloMovDocByClick(protocolo) {
    if !WinExist(WIN_MOVDOC_BAIXA)
        return false

    WinActivate WIN_MOVDOC_BAIXA
    if !MV_Poll(() => WinActive(WIN_MOVDOC_BAIXA), 2)
        return false

    CoordMode("Mouse", "Client")
    Click(MOVDOC_PROTOCOLO_X + 40, MOVDOC_PROTOCOLO_Y + 10, 1)
    Sleep RP_KEY_SETTLE_MS
    SendText protocolo
    Sleep RP_KEY_SETTLE_MS
    return true
}

RP_ColetarLinhasMovDoc(protocolo, primeiraLinha := "") {
    linhas := []
    vistos := Map()

    if (primeiraLinha is Map) {
        keyInicial := primeiraLinha["protocolo"] "|" primeiraLinha["conta"] "|" primeiraLinha["convenio"]
        vistos[keyInicial] := true
        linhas.Push(primeiraLinha)
    }

    RP_ColetarLinhasVisiveisMovDoc(protocolo, linhas, vistos)

    maxIteracoes := 100
    semNovasConsecutivas := 0

    Loop maxIteracoes {
        result := RP_AvancarGridMovDocQuatroLinhas()
        added := RP_ColetarLinhasVisiveisMovDoc(protocolo, linhas, vistos)

        ; Popup de último registro é o sinal mais confiável: parar imediatamente.
        if result["popup"]
            break

        ; Oracle Forms pode atrasar atualização da grid; exigir dois blocos vazios seguidos
        ; evita parar cedo por uma leitura repetida/transitória.
        if (added = 0) {
            semNovasConsecutivas++
            if (semNovasConsecutivas >= 2)
                break
        } else {
            semNovasConsecutivas := 0
        }
    }

    return linhas
}

RP_AvancarGridMovDocQuatroLinhas() {
    CoordMode("Mouse", "Client")
    ultimoY := MOVDOC_GRID_ROWS_Y[MOVDOC_GRID_ROWS_Y.Length]
    Click(MOVDOC_CONTA_X + 15, ultimoY + 8, 1)
    Sleep RP_KEY_SETTLE_MS

    Loop MOVDOC_GRID_ROWS_Y.Length {
        if RP_MovDocPopupWindowVisible() {
            RP_DismissMovDocPopup()
            return Map("popup", true)
        }

        Send "{Down}"
        Sleep RP_KEY_SETTLE_MS
    }

    if RP_MovDocPopupWindowVisible() {
        RP_DismissMovDocPopup()
        return Map("popup", true)
    }

    primeiroY := MOVDOC_GRID_ROWS_Y[1]
    Click(MOVDOC_CONTA_X + 15, primeiroY + 8, 1)
    Sleep RP_KEY_SETTLE_MS
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
            Sleep RP_KEY_SETTLE_MS
            if !MV_ClickFirstControl(WIN_MOVDOC_POPUP, MV_MODAL_OK_CLASS)
                Send "{Enter}"
            return MV_Poll(() => !WinExist(WIN_MOVDOC_POPUP), 3)
        }
    }
    return false
}

RP_FinalizarBaixaProtocolo() {
    ; Checkbox Recebido: estado vem do controle Button1.
    ; Regra validada pelo usuário: 0 → click simples; 1 → double click.
    checked := MV_ControlCheckedAt(WIN_MOVDOC_BAIXA, MOVDOC_CHECK_RECEBIDO_CLASS, MOVDOC_CHECK_RECEBIDO_X, MOVDOC_CHECK_RECEBIDO_Y)

    if (checked = 0 || checked = "") {
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

    if !RP_FocusProtocoloMovDocByClick()
        return false

    Sleep RP_KEY_SETTLE_MS
    Send "{F7}"
    Sleep RP_KEY_SETTLE_MS
    return true
}

RP_FocusProtocoloMovDocByClick() {
    if !WinExist(WIN_MOVDOC_BAIXA)
        return false

    WinActivate WIN_MOVDOC_BAIXA
    if !MV_Poll(() => WinActive(WIN_MOVDOC_BAIXA), 2)
        return false

    CoordMode("Mouse", "Client")
    Click(MOVDOC_PROTOCOLO_X + 40, MOVDOC_PROTOCOLO_Y + 10, 1)
    return true
}

RP_WaitMovDocFirstGridLineReady(protocolo, &primeiraLinhaValida) {
    startedAt := A_TickCount
    deadline := startedAt + 12000

    Loop {
        conta := RP_ReadMovDocGridField(MOVDOC_CONTA_X, MOVDOC_GRID_ROWS_Y[1], "conta", 150, 300)
        convenio := RP_ReadMovDocGridField(MOVDOC_CONVENIO_X, MOVDOC_GRID_ROWS_Y[1], "convenio", 150, 300)

        if (conta != "" && convenio != "" && conta != protocolo && convenio != protocolo) {
            Notify("MOV DOC: primeira linha legível após F8 em " (A_TickCount - startedAt) "ms.")
            primeiraLinhaValida := Map("protocolo", protocolo, "conta", conta, "convenio", convenio)
            return true
        }

        if (A_TickCount >= deadline)
            return false

        Sleep 100
    }
}

RP_ReadMovDocGridField(x, y, campo := "", fastTimeoutMs := 150, fallbackTimeoutMs := 300) {
    if !WinExist(WIN_MOVDOC_BAIXA)
        return ""

    WinActivate WIN_MOVDOC_BAIXA
    if !MV_Poll(() => WinActive(WIN_MOVDOC_BAIXA), 2)
        return ""
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
    ; Sempre abre um novo Manutenção de Remessa via atalho, mesmo que já exista um aberto.
    MV_ActivateModule(MV_WIN_FFCV_ANY)
    if !MV_WaitWindowStable(MV_WIN_FFCV_ANY, MV_MODULE_STABLE_MS, MV_TIMEOUT_LOAD)
        return false

    ; Atalho validado no macro 03: Lançamentos → Manutenção de Remessa.
    Send "{Alt down}lm{Alt up}{Enter}"

    if !MV_Poll(() => WinExist(MV_WIN_FFCV_REMESSA), MV_TIMEOUT_LOAD)
        return false

    return MV_WaitWindowStable(MV_WIN_FFCV_REMESSA, MV_TARGET_STABLE_MS, MV_TIMEOUT_LOAD)
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
    SendText RP_TipoContaCodigo(tipoConta)
    Sleep RP_KEY_SETTLE_MS
    Send "{F10}"
    return RP_WaitFFCVLoad()
}

RP_TipoContaCodigo(tipoConta) {
    switch tipoConta {
        case "Emergência": return "1"
        case "Internamento": return "2"
        case "Ambulatório": return "3"
        default: return ""
    }
}

InserirContasNaRemessa(protocolContas, tipoConta, erros) {
    totalContas := ContarContas(protocolContas)
    contaIdx := 0
    okCount := 0
    erroCount := 0
    blockerCount := 0

    if !RP_AbrirConfigurarPopupContas(tipoConta)
        return false

    for protocolo, contas in protocolContas {
        for _, contaObj in contas {
            contaIdx++
            numConta := contaObj["conta"]
            Notify("Enviando conta " numConta " [prot. " protocolo "]")

            outcome := EnviarConta(numConta)
            if (outcome["status"] = "modal") {
                ; RP_WaitContaSubmitOutcome já classificou o modal. Não repetir ImageSearch aqui.
                erroConta := outcome["erro"]

                ; Regra validada: conta já digitada é continuável; fecha só o modal Forms e segue no mesmo popup.
                if (erroConta["tipo"] != "conta_ja_digitada") {
                    erros.Push(Map("protocolo", protocolo, "conta", numConta, "descricao", erroConta["descricao"]))
                    erroCount++
                } else {
                    okCount++
                }

                dismissResult := RP_DismissActiveModal()
                if !dismissResult["ok"] {
                    blockerCount++
                    return RP_Abort("Modal de erro apareceu após a conta " numConta ", mas não consegui fechar o popup de erro.")
                }

                if !MV_Poll(() => RP_FFCVContaPopupVisible(), MV_TIMEOUT_ACOE) {
                    blockerCount++
                    return RP_Abort("Modal foi fechado, mas o popup de conta não voltou/estabilizou após a conta " numConta ".")
                }
            } else if (outcome["status"] = "ready") {
                okCount++
                ; Popup permanece aberto para a próxima conta.
            } else {
                blockerCount++
                return RP_Abort("Estado incerto após enviar conta " numConta ": " outcome["erro"])
            }

            Progress(60 + (contaIdx / totalContas) * 25)
        }
    }

    Notify("Resumo inserção FFCV: ok=" okCount " erro/modal=" erroCount " bloqueio=" blockerCount " total=" totalContas)

    if !RP_CloseContaPopupAndWait(5000)
        return RP_Abort("Lote de contas terminou, mas não consegui fechar o popup de conta com Alt+2.")

    return true
}

RP_AbrirConfigurarPopupContas(tipoConta) {
    if !RP_EnsureFFCVActive()
        return RP_Abort("FFCV não ficou ativa antes de clicar em Inserir Conta.")

    if !RP_ClickBySpec(MV_WIN_FFCV_ANY, FFCV_BTN_ADICIONAR, 24, 458)
        return RP_Abort("Não consegui clicar em Inserir Conta no FFCV.")

    popupReady := RP_WaitContaPopupReady(5000)
    if !popupReady["ok"]
        return RP_Abort(popupReady["erro"])
    Notify("Popup Informações da Conta detectado em " popupReady["elapsed"] "ms.")

    if RP_ActiveModalTitle() != "" && !RP_FFCVContaPopupVisible() {
        if !RP_PollMs(() => RP_ActiveModalTitle() = "" || RP_FFCVContaPopupVisible(), 1200)
            return RP_Abort("Modal apareceu antes do popup de conta e não foi resolvido: " RP_SafeWinGetText(RP_ActiveModalTitle()))
    }

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

RP_PollMs(condFn, timeoutMs, intervalMs := 20) {
    startedAt := A_TickCount
    Loop {
        if condFn()
            return true

        if (A_TickCount - startedAt >= timeoutMs)
            return false

        Sleep intervalMs
    }
}

RP_FFCVContaPopupVisible() {
    sentinel := RP_FindControlByClassPrefixAtPoint(MV_WIN_FFCV_ANY, "ui60Drawn", FFCV_POPUP_CONTA_SENTINEL_X, FFCV_POPUP_CONTA_SENTINEL_Y, 35)
    if !sentinel
        return false

    campoConta := MV_FindControlByClientPoint(MV_WIN_FFCV_ANY, POPUP_CAMPO_CONTA, POPUP_CAMPO_CONTA_X, POPUP_CAMPO_CONTA_Y, 35)
    if !campoConta
        campoConta := RP_FindControlByClassPrefixAtPoint(MV_WIN_FFCV_ANY, "Edit", POPUP_CAMPO_CONTA_X, POPUP_CAMPO_CONTA_Y, 50)

    if !campoConta
        campoConta := RP_FindControlByClassPrefixAtPoint(MV_WIN_FFCV_ANY, "ComboBox", POPUP_DROPDOWN_1_X, POPUP_DROPDOWN_1_Y, 40)

    if !campoConta
        campoConta := RP_FindControlByClassPrefixAtPoint(MV_WIN_FFCV_ANY, "ComboBox", POPUP_DROPDOWN_2_X, POPUP_DROPDOWN_2_Y, 40)

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
        if RP_FFCVContaPopupVisible()
            return Map("ok", true, "modal", false, "elapsed", A_TickCount - startedAt, "erro", "")

        if RP_ActiveModalTitle() != "" {
            if RP_PollMs(() => RP_ActiveModalTitle() = "" || RP_FFCVContaPopupVisible(), Min(800, timeoutMs))
                continue
            return Map("ok", true, "modal", true, "elapsed", A_TickCount - startedAt, "erro", "")
        }

        if (A_TickCount - startedAt >= timeoutMs)
            return Map("ok", false, "modal", false, "elapsed", A_TickCount - startedAt, "erro", "Popup Informações da Conta não apareceu após Inserir Conta em " timeoutMs "ms. Verifique sentinela ui60Drawn no ponto Client " FFCV_POPUP_CONTA_SENTINEL_X "," FFCV_POPUP_CONTA_SENTINEL_Y " e campo da conta em " POPUP_CAMPO_CONTA_X "," POPUP_CAMPO_CONTA_Y ".")

        Sleep 20
    }
}

RP_WaitContaPopupStable(stableMs := 300, timeoutMs := 1200) {
    startedAt := A_TickCount
    stableSince := 0
    Loop {
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

RP_WaitReadyForNextAccount(timeoutMs := 1000) {
    startedAt := A_TickCount

    Loop {
        if RP_ActiveModalTitle() != "" {
            result := RP_DismissActiveModal()
            if !result["ok"]
                return false
        }

        if RP_FFCVContaPopupVisible()
            return true

        if (A_TickCount - startedAt >= timeoutMs)
            return false

        Sleep 20
    }
}

RP_CloseContaPopupAndWait(timeoutMs := 5000) {
    ; Regra: manter o popup aberto durante o lote e fechar com Alt+2 somente ao final.
    if !RP_FFCVContaPopupVisible()
        return true

    if !RP_EnsureFFCVActive()
        return false

    Send "!2"
    Sleep RP_KEY_SETTLE_MS
    Send "{Enter}"

    startedAt := A_TickCount
    Loop {
        if (!RP_FFCVContaPopupVisible() && (RP_ActiveModalTitle() = "")) {
            Sleep FFCV_CONTA_STABLE_MS
            return true
        }
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
    ; Fonte de verdade: macro 11.
    ; Popup aberto uma única vez; Tab x3 → dropdown 1 → Down x2 → sequência do tipo → campo conta.
    if !RP_EnsureFFCVActive()
        return false

    if (tipoConta = "Internamento") {
        Send "{Tab 3}"
        Sleep RP_KEY_SETTLE_MS
        Send "{Down 2}"
        Sleep RP_KEY_SETTLE_MS
        Send "{Tab}"
        Sleep RP_KEY_SETTLE_MS
        Send "{Tab 2}"
        Sleep RP_KEY_SETTLE_MS
    } else if (tipoConta = "Emergência" || tipoConta = "Ambulatório") {
        Send "{Tab 3}"
        Sleep RP_KEY_SETTLE_MS
        Send "{Down 2}"
        Sleep RP_KEY_SETTLE_MS
        Send "{Tab 2}"
        Sleep RP_KEY_SETTLE_MS
        Send "{Up 2}"
        Sleep RP_KEY_SETTLE_MS
        Send "{Tab}"
        Sleep RP_KEY_SETTLE_MS
    } else {
        return false
    }

    return true
}

EnviarConta(numConta) {
    envio := RP_LimparCampoContaEnviar(numConta)
    if !envio["ok"]
        return envio

    outcome := RP_WaitContaSubmitOutcome(FFCV_CONTA_SUBMIT_TIMEOUT_MS, numConta)
    if (outcome["status"] = "modal")
        return outcome

    if !RP_WaitReadyForNextAccount(FFCV_CONTA_SUBMIT_TIMEOUT_MS)
        return Map("status", "blocker", "erro", "Não consegui estabilizar o popup de conta após inserir " numConta ".", "texto", "", "report", "❌ Falha ao aguardar popup ou modal após a conta " numConta ".`n")

    return outcome
}

RP_LimparCampoContaEnviar(numConta) {
    if !RP_FFCVContaPopupVisible()
        return Map("ok", false, "erro", "Popup de conta não está visível antes de limpar/enviar a conta " numConta ".", "texto", "", "report", "❌ Popup de conta não está visível antes de limpar/enviar a conta " numConta ".`n")
    if !RP_EnsureFFCVActive()
        return Map("ok", false, "erro", "FFCV não ficou ativa antes de limpar/enviar a conta " numConta ".", "texto", "", "report", "❌ FFCV não ficou ativa antes de limpar/enviar a conta " numConta ".`n")

    CoordMode("Mouse", "Client")
    Click(POPUP_CAMPO_CONTA_X + 15, POPUP_CAMPO_CONTA_Y + 8, 1)
    Sleep RP_FIELD_FOCUS_SETTLE_MS
    Send("{Home}{Shift down}{End}{Shift up}{Backspace}")
    Sleep RP_FIELD_CLEAR_SETTLE_MS
    SendText numConta
    Send "{Enter}"
    return Map("ok", true, "erro", "", "texto", "", "report", "✅ Campo da conta clicado, limpo, conta digitada e Enter enviado: " numConta "`n")
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
        popup := RP_ActiveContaErrorModalTitle()
        if (popup != "") {
            erro := ClassificarErroContaModal()
            return Map("status", "modal", "erro", erro, "texto", "", "report", "ℹ️ Modal Forms detectado após Enter: " erro["descricao"] " [" erro["fonte"] "]`n")
        }

        fieldText := RP_GetContaFieldText()
        if (submittedConta != "" && fieldText != submittedConta && fieldText = "") {
            if (emptySince = 0)
                emptySince := A_TickCount
            if (A_TickCount - emptySince >= FFCV_CONTA_FIELD_EMPTY_MIN_MS)
                return Map("status", "ready", "erro", "", "texto", "", "report", "✅ Campo esvaziou após " Round((A_TickCount - startTick) / 1000, 2) "s; liberado para próxima conta.`n")
        } else {
            emptySince := 0
        }

        if RP_FFCVContaPopupVisible() {
            if (stableSince = 0)
                stableSince := A_TickCount
            if (A_TickCount - startTick >= FFCV_CONTA_READY_MIN_MS && A_TickCount - stableSince >= FFCV_CONTA_STABLE_MS)
                return Map("status", "ready", "erro", "", "texto", "", "report", "✅ Nenhum modal após " Round((A_TickCount - startTick) / 1000, 2) "s; popup está estável para próxima conta.`n")
        } else {
            stableSince := 0
        }

        if (A_TickCount > deadline) {
            if (stableSince != 0 && A_TickCount - stableSince >= FFCV_CONTA_STABLE_MS)
                return Map("status", "ready", "erro", "", "texto", "", "report", "✅ Nenhum modal após " Round((A_TickCount - startTick) / 1000, 2) "s; popup está estável para próxima conta.`n")
            return Map("status", "timeout", "erro", "Timeout aguardando modal ou popup estável após Enter.", "texto", "", "report", "❌ Timeout aguardando modal ou popup estável após Enter.`n")
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
    return WinExist("Forms ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE")
        ? "Forms ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"
        : ""
}

RP_ActiveContaErrorModalTitle() {
    return WinExist("Forms ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE")
        ? "Forms ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"
        : ""
}

RP_DismissActiveModal() {
    popup := RP_ActiveModalTitle()
    if (popup = "")
        return Map("ok", true, "report", "")

    try {
        WinActivate popup
        Sleep RP_KEY_SETTLE_MS

        if !MV_Poll(() => RP_FirstControlByClass(popup, MV_MODAL_OK_CLASS) != 0, 5)
            return Map("ok", false, "report", "❌ Modal existe, mas o botão OK não ficou disponível em tempo.")

        if !MV_ClickFirstControl(popup, MV_MODAL_OK_CLASS)
            return Map("ok", false, "report", "❌ Não consegui clicar OK do modal.")

        if !MV_Poll(() => !WinExist(popup), MV_TIMEOUT_ACOE)
            return Map("ok", false, "report", "❌ Cliquei OK, mas o modal não fechou em tempo.")

        Sleep FFCV_CONTA_STABLE_MS
        return Map("ok", true, "report", "✅ OK do modal clicado e janela fechada/estabilizada.`n")
    }
    return Map("ok", false, "report", "❌ Exceção ao tentar fechar o modal.")
}

RP_FirstControlByClass(winTitle, classNN) {
    try hwnds := WinGetControlsHwnd(winTitle)
    catch
        return 0

    for hwnd in hwnds {
        try ctrlClass := ControlGetClassNN(hwnd)
        catch
            continue
        if (ctrlClass = classNN)
            return hwnd
    }
    return 0
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

ClassificarErroContaModal() {
    popup := RP_ActiveContaErrorModalTitle()
    if (popup != "")
        return FFCV_ClassifyErrorModal(popup)

    return Map("tipo", "erro_desconhecido", "descricao", "Erro modal não classificado", "fonte", "sem modal Forms", "texto", "", "img", "")
}

RP_ErrorTemplateVisible(imagePath, variation := 35) {
    popup := RP_ActiveModalTitle()
    return FFCV_ErrorTemplateVisible(imagePath, popup, variation)
}

ClassificarErro(textoPopup) {
    global ERR_CONVENIO_DIFERENTE, ERR_CONTA_ABERTA, ERR_CONTA_JA_EM_REMESSA, ERR_TIPO_DIFERENTE

    lower := StrLower(textoPopup)
    if InStr(lower, StrLower(ERR_CONVENIO_DIFERENTE))
        return "Conta de outro convênio"
    if InStr(lower, StrLower(ERR_CONTA_ABERTA))
        return "Conta aberta"
    if InStr(lower, StrLower(ERR_CONTA_JA_EM_REMESSA))
        return "Conta já em remessa"
    if InStr(lower, StrLower(ERR_TIPO_DIFERENTE))
        return "Conta de tipo diferente"

    texto := Trim(textoPopup)
    if (texto = "" || texto = "&OK" || InStr(texto, "<observação: Oracle Forms"))
        return "Erro ao inserir conta: modal Forms sem texto acessível"

    return texto
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
    ImprimirRelatorioAtendimentos()
}

ImprimirRelatorioAtendimentos() {
    if !RP_EnsureFFCVActive() {
        Notify("Erro: FFCV não ficou ativa antes de imprimir relatório de atendimentos.")
        return false
    }

    if !MV_ClickControlAt(MV_WIN_FFCV_ANY, FFCV_BTN_IMPRIMIR, FFCV_BTN_IMPRIMIR_X, FFCV_BTN_IMPRIMIR_Y) {
        Notify("Erro: não consegui clicar em Relatório Atendimentos.")
        return false
    }

    if !MV_Poll(() => WinExist(WIN_CAPA_REMESSA), MV_TIMEOUT_LOAD) {
        Notify("Erro: janela Relatório de Atendimentos da Remessa não apareceu.")
        return false
    }

    WinActivate WIN_CAPA_REMESSA
    Sleep RP_KEY_SETTLE_MS
    Send "{Enter}"
    MV_Poll(() => !WinExist(WIN_CAPA_REMESSA), MV_TIMEOUT_LOAD)
    Notify("Relatório de atendimentos confirmado para impressão.")
    return true
}

FinalizarComDatas(dataEntrega, dataVenc) {
    if !RP_EnsureFFCVActive()
        return Map("ok", false, "erro", "FFCV não ficou ativa antes de abrir a tela de fechar remessa/datas.")

    startedAt := A_TickCount
    ; Mesmo contrato do teste 12: botão por ClassNN + ponto Client validado.
    if !RP_ClickBySpec(MV_WIN_FFCV_ANY, FFCV_BTN_ABRIR_DATAS, 464, 458)
        return Map("ok", false, "erro", "Não consegui clicar em Entregar Remessa.")

    if !MV_Poll(() => WinExist(WIN_FFCV_DATAS), MV_TIMEOUT_LOAD)
        return Map("ok", false, "erro", "Tela de fechar remessa/datas não abriu.")
    Notify("Tela de datas detectada em " (A_TickCount - startedAt) "ms.")

    datas := RP_PreencherDatasEntregaPorTeclado(dataEntrega, dataVenc)
    if !datas["ok"]
        return Map("ok", false, "erro", datas["erro"])
    numRemessa := datas["remessa"]

    checkedFecharContas := MV_ControlCheckedAt(WIN_FFCV_DATAS, DATAS_CHECKBOX, DATAS_CHECKBOX_X, DATAS_CHECKBOX_Y, 20)
    if (checkedFecharContas = 0) {
        if !RP_ClickBySpec(WIN_FFCV_DATAS, DATAS_CHECKBOX, DATAS_CHECKBOX_X, DATAS_CHECKBOX_Y)
            return Map("ok", false, "erro", "Não consegui marcar 'Fechar contas sem imprimir faturas'.")
    } else if (checkedFecharContas = "") {
        return Map("ok", false, "erro", "Não consegui ler o estado de 'Fechar contas sem imprimir faturas'.")
    }
    Sleep MV_DELAY_INPUT

    if !RP_ClickBySpec(WIN_FFCV_DATAS, DATAS_BTN_CONFIRMAR, DATAS_BTN_CONFIRMAR_X, DATAS_BTN_CONFIRMAR_Y)
        return Map("ok", false, "erro", "Não consegui confirmar a entrega da remessa.")

    if !RP_WaitAnyModalOrDelay(MV_TIMEOUT_ACOE)
        return Map("ok", false, "erro", "Popup de confirmação não apareceu.")
    if !RP_ClickNaoModal()
        return Map("ok", false, "erro", "Não consegui clicar Não no popup de confirmação.")
    if !RP_WaitModalGone(RP_FINAL_ACTION_TIMEOUT_MS)
        return Map("ok", false, "erro", "Popup de confirmação foi acionado, mas não fechou/estabilizou em tempo.")

    if !MV_Poll(() => WinExist(WIN_CAPA_REMESSA), MV_TIMEOUT_LOAD)
        return Map("ok", false, "erro", "Tela de impressão não apareceu.")
    if !RP_EnsureWindowActive(WIN_CAPA_REMESSA)
        return Map("ok", false, "erro", "Tela de impressão apareceu, mas não ficou ativa para confirmar.")
    if !RP_WaitOracleSettled(WIN_CAPA_REMESSA, RP_FINAL_STABLE_MS, RP_FINAL_ACTION_TIMEOUT_MS)
        return Map("ok", false, "erro", "Tela de impressão apareceu, mas não estabilizou antes do Enter.")

    Send "{Enter}"
    if !RP_WaitWindowGone(WIN_CAPA_REMESSA, RP_FINAL_ACTION_TIMEOUT_MS)
        return Map("ok", false, "erro", "Enter enviado na tela de impressão, mas ela não fechou em tempo.")

    if !RP_WaitOracleSettled(WIN_FFCV_DATAS, RP_FINAL_STABLE_MS, RP_FINAL_ACTION_TIMEOUT_MS)
        return Map("ok", false, "erro", "Após a impressão, a tela de Entrega de Remessas não estabilizou para sair.")

    if !RP_SairTelaEntregaPendente()
        return Map("ok", false, "erro", "Atalho para sair da tela Entrega de Remessas ainda não mapeado. Preencha RP_ENTREGA_SAIR_ATALHO para continuar até XML.")
    if !RP_WaitOracleSettled(MV_WIN_FFCV_ANY, RP_FINAL_STABLE_MS, RP_FINAL_ACTION_TIMEOUT_MS)
        return Map("ok", false, "erro", "FFCV não estabilizou após sair da tela Entrega de Remessas.")

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

    ; Contrato validado no teste 12:
    ; ancorar foco em Data de Entrega, Shift+Tab seleciona Remessa, Tab volta
    ; para Data de Entrega, Enter avança para Data Prevista. Não usar Ctrl+A.
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
        return RP_Abort("Erro: tela XML/TISS não abriu.")

    if !RP_SetTextByClickNoClear(WIN_XML, XML_CAMPO_REMESSA_X, XML_CAMPO_REMESSA_Y, numRemessa)
        return RP_Abort("Não consegui preencher a remessa na tela XML/TISS.")
    Sleep RP_KEY_SETTLE_MS
    Send "{F8}"

    queryReady := RP_WaitXmlQueryReady(RP_FINAL_ACTION_TIMEOUT_MS)
    if !queryReady["ok"]
        return RP_Abort(queryReady["erro"])
    Notify("Consulta XML/TISS estabilizada em " queryReady["elapsed"] "ms.")

    if !RP_ClickBySpec(WIN_XML, XML_BTN_FATURAMENTO, XML_BTN_FATURAMENTO_X, XML_BTN_FATURAMENTO_Y)
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

    if !RP_WaitOracleSettled(WIN_XML_PATH_FORM, RP_FINAL_STABLE_MS, RP_FINAL_ACTION_TIMEOUT_MS)
        return RP_Abort("Tela de caminho do XML não estabilizou antes de salvar.")

    if !RP_ClickBySpec(WIN_XML_PATH_FORM, XML_FORM_BTN_SALVAR, XML_FORM_BTN_SALVAR_X, XML_FORM_BTN_SALVAR_Y)
        return RP_Abort("Não consegui acionar o botão Salvar_XML.")

    if !RP_HandleXmlSaveModals()
        return false

    if !RP_WaitOracleSettled(WIN_XML_PATH_FORM, RP_FINAL_STABLE_MS, RP_FINAL_ACTION_TIMEOUT_MS)
        return RP_Abort("Após salvar o XML, a tela não estabilizou para voltar.")

    if !RP_ClickBySpec(WIN_XML_PATH_FORM, XML_FORM_BTN_VOLTAR, XML_FORM_BTN_VOLTAR_X, XML_FORM_BTN_VOLTAR_Y)
        return RP_Abort("Não consegui voltar da tela de XML gerado.")
    if !RP_WaitOracleSettled(WIN_XML_PATH_FORM, RP_FINAL_STABLE_MS, RP_FINAL_ACTION_TIMEOUT_MS)
        Notify("Aviso: a tela de XML não confirmou estabilidade após Voltar; tentando sair mesmo assim.")

    RP_SairTelaAtual()
    return true
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

RP_WaitModalGone(timeoutMs := 30000) {
    startedAt := A_TickCount
    Loop {
        if (RP_ActiveModalTitle() = "")
            return true
        if (A_TickCount - startedAt >= timeoutMs)
            return false
        Sleep MV_POLL_MS
    }
}

RP_WaitWindowGone(winTitle, timeoutMs := 30000) {
    startedAt := A_TickCount
    Loop {
        if !WinExist(winTitle) {
            Sleep RP_KEY_SETTLE_MS
            return true
        }
        if (A_TickCount - startedAt >= timeoutMs)
            return false
        Sleep MV_POLL_MS
    }
}

RP_WaitOracleSettled(winTitle, stableMs := 800, timeoutMs := 30000) {
    startedAt := A_TickCount
    stableSince := 0
    lastCount := -1

    Loop {
        modalClear := (RP_ActiveModalTitle() = "")
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

RP_ControlAtReady(winTitle, classNN, clientX, clientY, tolerance := 14) {
    hwnd := MV_FindControlByClientPoint(winTitle, classNN, clientX, clientY, tolerance)
    if !hwnd
        return false
    try return ControlGetEnabled(hwnd)
    catch
        return true
}

RP_WaitXmlQueryReady(timeoutMs := 30000) {
    startedAt := A_TickCount
    stableSince := 0

    Loop {
        modal := RP_ActiveModalTitle()
        if (modal != "")
            return Map("ok", false, "elapsed", A_TickCount - startedAt, "erro", "Modal apareceu após consultar a remessa no XML/TISS: " RP_SafeWinGetText(modal))

        minWaitDone := (A_TickCount - startedAt >= RP_XML_QUERY_MIN_WAIT_MS)
        if (minWaitDone
            && RP_ControlAtReady(WIN_XML, XML_BTN_FATURAMENTO, XML_BTN_FATURAMENTO_X, XML_BTN_FATURAMENTO_Y, 20)
            && A_Cursor != "Wait" && A_Cursor != "AppStarting") {
            if (stableSince = 0)
                stableSince := A_TickCount
            if (A_TickCount - stableSince >= RP_FINAL_STABLE_MS)
                return Map("ok", true, "elapsed", A_TickCount - startedAt, "erro", "")
        } else {
            stableSince := 0
        }

        if (A_TickCount - startedAt >= timeoutMs)
            return Map("ok", false, "elapsed", A_TickCount - startedAt, "erro", "Consulta da remessa no XML/TISS não estabilizou em " timeoutMs "ms.")

        Sleep MV_POLL_MS
    }
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
    Loop 5 {
        if !MV_Poll(() => WinExist("ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"), 2) {
            if (A_Index = 1)
                Notify("Nenhum modal apareceu imediatamente após salvar XML; aguardando estabilização da tela.")
            if RP_WaitOracleSettled(WIN_XML_PATH_FORM, RP_FINAL_STABLE_MS, 5000)
                return true
            continue
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

        if !MV_Poll(() => !WinExist("ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"), MV_TIMEOUT_ACOE)
            return RP_Abort("Modal do XML foi acionado, mas não fechou em tempo.")
    }
    return RP_Abort("XML não estabilizou após salvar e tratar modais.")
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

RP_ClickBySpec(winTitle, classNN, x, y) {
    if !RP_RequireClientControl(classNN, x, y, "botão")
        return false

    ; Igual ao teste 12: localizar controle por ClassNN + ponto Client com tolerância 20.
    if MV_ClickControlAt(winTitle, classNN, x, y, 20)
        return true

    if !WinExist(winTitle)
        return false

    try {
        WinActivate winTitle
        if !MV_Poll(() => WinActive(winTitle), 3)
            return false
        CoordMode("Mouse", "Client")
        Click(x, y, 1)
        return true
    } catch {
        return false
    }
}
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
Progress(v) {
    static lastProgress := ""
    normalized := Max(0, Min(100, Round(v)))
    if (lastProgress != "" && normalized = lastProgress)
        return
    lastProgress := normalized
    SendToUI(Map("type", "progress", "value", normalized))
}
Done(msg)    => SendToUI(Map("type", "done", "message", msg))
