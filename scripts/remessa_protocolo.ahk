#Requires AutoHotkey v2.0
#Include mv_session.ahk

; ============================================================================
; Projeto: Praxis
; Arquivo: remessa_protocolo.ahk
; Descrição: automação do fluxo de remessa por protocolo.
;
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
;
; Este arquivo integra o software proprietário Praxis.
; O acesso ao código-fonte não concede licença de uso, cópia, modificação,
; redistribuição, engenharia reversa, criação de obras derivadas ou
; exploração comercial sem autorização prévia e expressa por escrito.
;
; Consulte: LICENSE, COPYRIGHT, NOTICE.md, EULA.md, NDA.md,
; PRIVACY_LGPD.md e THIRD_PARTY_NOTICES.md.
; ============================================================================

; ════════════════════════════════════════════════════════════════
;  REMESSA POR PROTOCOLO
;  Substitua todos os valores marcados com ; << pelo Window Spy
; ════════════════════════════════════════════════════════════════

; ── Janelas ───────────────────────────────────────────────────
WIN_MOVDOC_POPUP   := "TÍTULO POPUP BAIXA PROTOCOLO"   ; <<
WIN_FFCV_POPUP     := "TÍTULO POPUP ENVIO DE CONTA"    ; <<
WIN_FFCV_DATAS     := "TÍTULO TELA DE DATAS"           ; <<
WIN_FFCV_DATAS_OK  := "TÍTULO POPUP CONFIRMA DATAS"    ; <<
WIN_CAPA_REMESSA   := "TÍTULO POPUP IMPRIMIR CAPA"     ; <<
WIN_XML            := "TÍTULO TELA XML"                ; <<
WIN_XML_PATH_FORM  := "TÍTULO FORM CAMINHO XML"        ; <<
WIN_XML_POPUP_SIMNAO := "TÍTULO POPUP SIM/NÃO XML"     ; <<

; ── Controles MOV DOC ─────────────────────────────────────────
MOVDOC_CAMPO_PROTOCOLO := "CLASSNN"  ; <<
MOVDOC_CAMPO_CONVENIO  := "CLASSNN"  ; <<
MOVDOC_GRID_CONTAS     := "CLASSNN"  ; <<
MOVDOC_BTN_BAIXA       := "CLASSNN"  ; <<
MOVDOC_POPUP_BTN_OK    := "CLASSNN"  ; <<

; ── Controles FFCV ────────────────────────────────────────────
FFCV_BTN_HABILITAR     := "CLASSNN"  ; << ou use: ControlSend "{F7}"
FFCV_CAMPO_CONVENIO    := "CLASSNN"  ; <<
FFCV_AREA_REMESSAS     := "CLASSNN"  ; << ou Tab x3
FFCV_BTN_BUSCAR_REM    := "CLASSNN"  ; << F7 na área de remessas
FFCV_CAMPO_NUM_REM     := "CLASSNN"  ; <<
FFCV_BTN_CONFIRMAR_REM := "CLASSNN"  ; << F8
FFCV_BTN_NOVA_REM      := "CLASSNN"  ; << F6
FFCV_CAMPO_DATA_REM    := "CLASSNN"  ; <<
FFCV_CAMPO_TIPO        := "CLASSNN"  ; <<
FFCV_BTN_SALVAR_REM    := "CLASSNN"  ; << F10
FFCV_BTN_ADICIONAR     := "CLASSNN"  ; << abre popup de contas
FFCV_BTN_FINALIZAR     := "CLASSNN"  ; << botão final sem datas
FFCV_BTN_ABRIR_DATAS   := "CLASSNN"  ; << botão que abre tela de datas

; ── Controles popup de envio de contas ────────────────────────
POPUP_DROPDOWN_1   := "CLASSNN"  ; <<
POPUP_DROPDOWN_2   := "CLASSNN"  ; <<
POPUP_CAMPO_CONTA  := "CLASSNN"  ; <<
POPUP_BTN_OK       := "CLASSNN"  ; << botão OK do popup de conta já digitada

; ── Controles tela de datas ───────────────────────────────────
DATAS_CAMPO_REMESSA    := "CLASSNN"  ; << textfield com nº da remessa gerada
DATAS_CAMPO_ENTREGA    := "CLASSNN"  ; <<
DATAS_CAMPO_VENCIMENTO := "CLASSNN"  ; <<
DATAS_CHECKBOX         := "CLASSNN"  ; <<
DATAS_BTN_CONFIRMAR    := "CLASSNN"  ; <<
DATAS_BTN_VOLTAR       := "CLASSNN"  ; <<

; ── Controles tela XML ────────────────────────────────────────
XML_CAMPO_REMESSA   := "CLASSNN"  ; <<
XML_BTN_BUSCAR      := "CLASSNN"  ; << F8
XML_BTN_FATURAMENTO := "CLASSNN"  ; <<
XML_FORM_CAMPO_PATH := "CLASSNN"  ; <<
XML_FORM_BTN_ENVIAR := "CLASSNN"  ; <<
XML_BTN_NAO         := "CLASSNN"  ; << botão Não no popup sim/não
XML_BTN_SAIR_FORM   := "CLASSNN"  ; <<
XML_BTN_SAIR_TELA   := "CLASSNN"  ; <<

; ── Fragmentos de texto dos erros no popup de envio ───────────
; Não precisa ser o texto completo — só um trecho único o suficiente
ERR_JA_DIGITADA        := "já digitada"       ; <<
ERR_CONVENIO_DIFERENTE := "convênio diferente" ; <<
ERR_CONTA_ABERTA       := "conta aberta"      ; <<
ERR_TIPO_DIFERENTE     := "tipo diferente"    ; <<

; ── Mapa tipo de conta → código MV ───────────────────────────
TIPO_CODIGO := Map("Emergência","1", "Internamento","2", "Ambulatório","3")

; ════════════════════════════════════════════════════════════════
;  ENTRY POINT
; ════════════════════════════════════════════════════════════════
RunRemessaProtocolo(params) {
    global gRunning, gWorkDir

    protocolos   := ParseProtocolos(params["protocolos"])
    tipoConta    := params["tipo_conta"]
    dataEntrega  := params["data_entrega"]
    dataVenc     := params["data_vencimento"]
    numRemessa   := Trim(params["num_remessa"])
    temDatas     := (dataEntrega != "" && dataVenc != "")

    protocolContas := Map()   ; Map<protocolo → Array<Map<conta>>>
    erros          := []      ; Array<Map<protocolo, conta, descricao>>
    convenioNum    := ""

    ; ════════════════════════════════════════════════════════
    ;  FASE 1 — MOV DOC
    ; ════════════════════════════════════════════════════════
    Notify("Abrindo MOV DOC...")

    if !MV_EnsureMovDoc()
        return RP_Abort("Não foi possível acessar o MOV DOC.")

    Progress(5)

    for idx, protocolo in protocolos {
        Notify("Protocolo " . protocolo . " (" . idx . "/" . protocolos.Length . ")")

        result := ProcessarProtocolo(protocolo)

        if (convenioNum = "" && result["convenio"] != "")
            convenioNum := result["convenio"]

        protocolContas[protocolo] := result["contas"]
        Progress(5 + (idx / protocolos.Length) * 40)
    }

    if (convenioNum = "")
        return RP_Abort("Convênio não identificado nos protocolos.")

    ; ════════════════════════════════════════════════════════
    ;  FASE 2 — FFCV
    ; ════════════════════════════════════════════════════════
    Notify("Abrindo FFCV...")

    if !MV_EnsureFFCV()
        return RP_Abort("Não foi possível acessar o FFCV.")

    Progress(50)

    HabilitarEdicaoFFCV()

    ; Convênio → polling até o campo aceitar o texto
    ControlSetText convenioNum, FFCV_CAMPO_CONVENIO, MV_WIN_FFCV
    Sleep MV_DELAY_INPUT
    ControlSend "{Enter}", FFCV_CAMPO_CONVENIO, MV_WIN_FFCV
    MV_Poll(() => ControlGetText(FFCV_CAMPO_CONVENIO, MV_WIN_FFCV) != "", MV_TIMEOUT_LOAD)

    PosicionarAreaRemessas()

    if (numRemessa != "") {
        if !SelecionarRemessaExistente(numRemessa)
            return RP_Abort("Remessa " . numRemessa . " não encontrada.")
    } else {
        if !CriarNovaRemessa(tipoConta)
            return RP_Abort("Erro ao criar nova remessa.")
    }

    Progress(60)

    ; ── Popup de envio de contas ──────────────────────────────
    ControlClick FFCV_BTN_ADICIONAR, MV_WIN_FFCV,,,, "NA"
    if !MV_Poll(() => WinExist(WIN_FFCV_POPUP), MV_TIMEOUT_ACOE)
        return RP_Abort("Popup de envio de contas não abriu.")

    WinActivate WIN_FFCV_POPUP
    ConfigurarDropdownsPopup(tipoConta)
    Sleep MV_DELAY_INPUT

    totalContas := ContarContas(protocolContas)
    contaIdx    := 0

    for protocolo, contas in protocolContas {
        for _, contaObj in contas {
            contaIdx++
            numConta := contaObj["conta"]
            Notify("Enviando conta " . numConta . " [prot. " . protocolo . "]")

            erro := EnviarConta(numConta)

            if (erro != "") {
                if InStr(erro, ERR_JA_DIGITADA) {
                    ControlClick POPUP_BTN_OK, WIN_FFCV_POPUP,,,, "NA"
                } else {
                    erros.Push(Map(
                        "protocolo", protocolo,
                        "conta",     numConta,
                        "descricao", ClassificarErro(erro)
                    ))
                    DismissErroPopup()
                }
            }

            Progress(60 + (contaIdx / totalContas) * 25)
        }
    }

    WinClose WIN_FFCV_POPUP
    MV_Poll(() => !WinExist(WIN_FFCV_POPUP), MV_TIMEOUT_ACOE)
    Progress(87)

    ; ════════════════════════════════════════════════════════
    ;  FASE 3 — Finalização
    ; ════════════════════════════════════════════════════════
    numRemessaGerada := ""

    if temDatas {
        Notify("Preenchendo datas...")
        result := FinalizarComDatas(dataEntrega, dataVenc)
        if !result["ok"]
            return RP_Abort(result["erro"])
        numRemessaGerada := result["remessa"]
        Progress(94)
        Notify("Gerando XML...")
        GerarXML(numRemessaGerada)
    } else {
        FinalizarSemDatas()
    }

    Progress(100)

    if (erros.Length > 0) {
        linhas := "Concluído com " . erros.Length . " pendência(s):`n"
        for _, e in erros
            linhas .= "  Prot. " . e["protocolo"] . "  |  Cta " . e["conta"]
                    . "  |  " . e["descricao"] . "`n"
        Done(linhas)
    } else {
        Done("Remessa concluída com sucesso!")
    }

    gRunning := false
}

; ════════════════════════════════════════════════════════════════
;  FASE 1 — MOV DOC (sem captura de erros por protocolo)
; ════════════════════════════════════════════════════════════════

ProcessarProtocolo(protocolo) {
    WinActivate MV_WIN_MOVDOC

    ; Informa o protocolo
    ControlSetText protocolo, MOVDOC_CAMPO_PROTOCOLO, MV_WIN_MOVDOC
    Sleep MV_DELAY_INPUT
    ControlSend "{Enter}", MOVDOC_CAMPO_PROTOCOLO, MV_WIN_MOVDOC

    ; Polling até o grid carregar (checa se o conteúdo mudou / não está vazio)
    ; << Ajuste a condição conforme o comportamento visual do grid no MV
    MV_Poll(() => ControlGetText(MOVDOC_GRID_CONTAS, MV_WIN_MOVDOC) != "", MV_TIMEOUT_LOAD)

    convenio := ControlGetText(MOVDOC_CAMPO_CONVENIO, MV_WIN_MOVDOC)
    contas   := ColetarContasDoGrid()

    ; Baixa no protocolo
    ControlClick MOVDOC_BTN_BAIXA, MV_WIN_MOVDOC,,,, "NA"

    ; Polling até o popup de confirmação aparecer
    MV_Poll(() => WinExist(WIN_MOVDOC_POPUP), MV_TIMEOUT_ACOE)
    ControlClick MOVDOC_POPUP_BTN_OK, WIN_MOVDOC_POPUP,,,, "NA"

    ; Polling até o popup fechar — confirma que a baixa foi registrada
    MV_Poll(() => !WinExist(WIN_MOVDOC_POPUP), MV_TIMEOUT_ACOE)

    return Map("contas", contas, "convenio", Trim(convenio))
}

; << Adapte conforme o formato real do grid no Window Spy
ColetarContasDoGrid() {
    contas   := []
    gridText := ControlGetText(MOVDOC_GRID_CONTAS, MV_WIN_MOVDOC)

    for _, linha in StrSplit(gridText, "`n") {
        linha := Trim(linha)
        if (linha = "")
            continue
        numConta := ExtrairNumeroConta(linha)
        if (numConta != "")
            contas.Push(Map("conta", numConta))
    }

    return contas
}

; << Ajuste conforme o formato das linhas do grid
ExtrairNumeroConta(linha) {
    ; Exemplo: conta é o primeiro campo separado por tab
    ; return StrSplit(linha, "`t")[1]
    return linha
}

; ════════════════════════════════════════════════════════════════
;  FASE 2 — FFCV
; ════════════════════════════════════════════════════════════════

HabilitarEdicaoFFCV() {
    ControlClick FFCV_BTN_HABILITAR, MV_WIN_FFCV,,,, "NA"
    ; Alternativa: ControlSend "{F7}",, MV_WIN_FFCV
    Sleep MV_DELAY_INPUT
}

PosicionarAreaRemessas() {
    ControlClick FFCV_AREA_REMESSAS, MV_WIN_FFCV,,,, "NA"
    ; Alternativa: ControlSend "{Tab}{Tab}{Tab}",, MV_WIN_FFCV
    Sleep MV_DELAY_INPUT
}

SelecionarRemessaExistente(numRemessa) {
    ControlClick FFCV_BTN_BUSCAR_REM, MV_WIN_FFCV,,,, "NA"
    ; Alternativa: ControlSend "{F7}", FFCV_AREA_REMESSAS, MV_WIN_FFCV
    Sleep MV_DELAY_INPUT

    ControlSetText numRemessa, FFCV_CAMPO_NUM_REM, MV_WIN_FFCV
    Sleep MV_DELAY_INPUT
    ControlClick FFCV_BTN_CONFIRMAR_REM, MV_WIN_FFCV,,,, "NA"
    ; Alternativa: ControlSend "{F8}", FFCV_CAMPO_NUM_REM, MV_WIN_FFCV

    ; << Adapte a condição: aguarda o campo de remessa ficar preenchido/confirmado
    return MV_Poll(() => ControlGetText(FFCV_CAMPO_NUM_REM, MV_WIN_FFCV) = numRemessa, MV_TIMEOUT_LOAD)
}

CriarNovaRemessa(tipoConta) {
    ControlClick FFCV_BTN_NOVA_REM, MV_WIN_FFCV,,,, "NA"
    ; Alternativa: ControlSend "{F6}", FFCV_AREA_REMESSAS, MV_WIN_FFCV
    Sleep MV_DELAY_INPUT

    hoje := FormatTime(, "dd/MM/yyyy")
    ControlSetText hoje, FFCV_CAMPO_DATA_REM, MV_WIN_FFCV
    Sleep MV_DELAY_INPUT
    ControlSend "{Enter}{Enter}{Enter}", FFCV_CAMPO_DATA_REM, MV_WIN_FFCV
    Sleep MV_DELAY_INPUT

    ControlSetText TIPO_CODIGO[tipoConta], FFCV_CAMPO_TIPO, MV_WIN_FFCV
    Sleep MV_DELAY_INPUT

    ControlClick FFCV_BTN_SALVAR_REM, MV_WIN_FFCV,,,, "NA"
    ; Alternativa: ControlSend "{F10}", FFCV_CAMPO_TIPO, MV_WIN_FFCV

    ; << Ajuste: aguarda indicação de que a remessa foi criada
    ; Ex: campo de número de remessa ficar preenchido
    return MV_Poll(() => ControlGetText(FFCV_CAMPO_NUM_REM, MV_WIN_FFCV) != "", MV_TIMEOUT_LOAD)
}

ConfigurarDropdownsPopup(tipoConta) {
    ControlChooseIndex 2, POPUP_DROPDOWN_1, WIN_FFCV_POPUP
    Sleep MV_DELAY_INPUT
    opcaoDrop2 := (tipoConta = "Internamento") ? 1 : 2
    ControlChooseIndex opcaoDrop2, POPUP_DROPDOWN_2, WIN_FFCV_POPUP
    Sleep MV_DELAY_INPUT
}

; Envia uma conta. Retorna texto do erro ou "" se aceita.
EnviarConta(numConta) {
    ControlSetText numConta, POPUP_CAMPO_CONTA, WIN_FFCV_POPUP
    Sleep MV_DELAY_INPUT
    ControlSend "{Enter}", POPUP_CAMPO_CONTA, WIN_FFCV_POPUP

    ; Popups possíveis após enviar a conta:
    ; << Ajuste os títulos conforme o Window Spy
    popupErro := MV_WaitAnyWindow(
        ["TÍTULO POPUP ERRO CONTA", "Atenção", "Aviso"],   ; <<
        MV_TIMEOUT_ACOE
    )

    if (popupErro != "")
        return WinGetText(popupErro)

    return ""
}

ClassificarErro(textoPopup) {
    if InStr(textoPopup, ERR_CONVENIO_DIFERENTE)
        return "Convênio diferente"
    if InStr(textoPopup, ERR_CONTA_ABERTA)
        return "Conta aberta"
    if InStr(textoPopup, ERR_TIPO_DIFERENTE)
        return "Tipo de conta diferente"
    return Trim(textoPopup)
}

DismissErroPopup() {
    ; << ClassNN do botão OK/Fechar do popup de erro de conta
    ControlClick "CLASSNN_BTN_FECHAR_ERRO",,,, "NA"   ; <<
    MV_Poll(() => !WinExist("TÍTULO POPUP ERRO CONTA"), MV_TIMEOUT_ACOE)
}

; ════════════════════════════════════════════════════════════════
;  FASE 3
; ════════════════════════════════════════════════════════════════

FinalizarSemDatas() {
    ControlClick FFCV_BTN_FINALIZAR, MV_WIN_FFCV,,,, "NA"
    if !MV_Poll(() => WinExist(WIN_CAPA_REMESSA), MV_TIMEOUT_ACOE)
        return
    ControlSend "{Enter}",, WIN_CAPA_REMESSA
    MV_Poll(() => !WinExist(WIN_CAPA_REMESSA), MV_TIMEOUT_LOAD)
}

FinalizarComDatas(dataEntrega, dataVenc) {
    ControlClick FFCV_BTN_ABRIR_DATAS, MV_WIN_FFCV,,,, "NA"
    if !MV_Poll(() => WinExist(WIN_FFCV_DATAS), MV_TIMEOUT_LOAD)
        return Map("ok", false, "erro", "Tela de datas não abriu.")

    WinActivate WIN_FFCV_DATAS
    Sleep MV_DELAY_INPUT

    numRemessa := ControlGetText(DATAS_CAMPO_REMESSA, WIN_FFCV_DATAS)

    ControlSetText dataEntrega, DATAS_CAMPO_ENTREGA,    WIN_FFCV_DATAS
    Sleep MV_DELAY_INPUT
    ControlSetText dataVenc,    DATAS_CAMPO_VENCIMENTO, WIN_FFCV_DATAS
    Sleep MV_DELAY_INPUT

    ControlClick DATAS_CHECKBOX,     WIN_FFCV_DATAS,,,, "NA"
    Sleep MV_DELAY_INPUT
    ControlClick DATAS_BTN_CONFIRMAR, WIN_FFCV_DATAS,,,, "NA"

    if !MV_Poll(() => WinExist(WIN_FFCV_DATAS_OK), MV_TIMEOUT_ACOE)
        return Map("ok", false, "erro", "Popup de confirmação não apareceu.")

    ControlSend "{Enter}",, WIN_FFCV_DATAS_OK
    MV_Poll(() => !WinExist(WIN_FFCV_DATAS_OK), MV_TIMEOUT_ACOE)

    if !MV_Poll(() => WinExist(WIN_CAPA_REMESSA), MV_TIMEOUT_LOAD)
        return Map("ok", false, "erro", "Popup de impressão não apareceu.")

    ControlSend "{Enter}",, WIN_CAPA_REMESSA
    MV_Poll(() => !WinExist(WIN_CAPA_REMESSA), MV_TIMEOUT_LOAD)

    ControlClick DATAS_BTN_VOLTAR, WIN_FFCV_DATAS,,,, "NA"
    MV_Poll(() => !WinExist(WIN_FFCV_DATAS), MV_TIMEOUT_LOAD)

    return Map("ok", true, "remessa", Trim(numRemessa))
}

GerarXML(numRemessa) {
    global gWorkDir

    ; << Navegue até a tela XML a partir do FFCV
    if !MV_Poll(() => WinExist(WIN_XML), MV_TIMEOUT_LOAD)
        return Notify("Erro: tela de XML não encontrada.")

    WinActivate WIN_XML
    Sleep MV_DELAY_INPUT

    ControlSetText numRemessa, XML_CAMPO_REMESSA, WIN_XML
    Sleep MV_DELAY_INPUT
    ControlClick XML_BTN_BUSCAR, WIN_XML,,,, "NA"
    ; Alternativa: ControlSend "{F8}", XML_CAMPO_REMESSA, WIN_XML

    MV_Poll(() => ControlGetText(XML_CAMPO_REMESSA, WIN_XML) = numRemessa, MV_TIMEOUT_LOAD)

    ControlClick XML_BTN_FATURAMENTO, WIN_XML,,,, "NA"
    if !MV_Poll(() => WinExist(WIN_XML_PATH_FORM), MV_TIMEOUT_LOAD)
        return Notify("Erro: form de caminho do XML não abriu.")

    WinActivate WIN_XML_PATH_FORM
    Sleep MV_DELAY_INPUT

    xmlPath := gWorkDir . "\XML\" . numRemessa . ".xml"
    ControlSetText xmlPath, XML_FORM_CAMPO_PATH, WIN_XML_PATH_FORM
    Sleep MV_DELAY_INPUT
    ControlClick XML_FORM_BTN_ENVIAR, WIN_XML_PATH_FORM,,,, "NA"

    popup := MV_WaitAnyWindow([WIN_XML_POPUP_SIMNAO], MV_TIMEOUT_ACOE)
    if (popup != "") {
        ControlClick XML_BTN_NAO, popup,,,, "NA"
        MV_Poll(() => !WinExist(popup), MV_TIMEOUT_ACOE)
    }

    ControlClick XML_BTN_SAIR_FORM, WIN_XML_PATH_FORM,,,, "NA"
    MV_Poll(() => !WinExist(WIN_XML_PATH_FORM), MV_TIMEOUT_LOAD)

    ControlClick XML_BTN_SAIR_TELA, WIN_XML,,,, "NA"
    MV_Poll(() => !WinExist(WIN_XML), MV_TIMEOUT_LOAD)
}

; ════════════════════════════════════════════════════════════════
;  UTILITÁRIOS
; ════════════════════════════════════════════════════════════════

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

RP_Abort(msg) {
    global gRunning
    SendToUI(Map("type","error","message",msg))
    gRunning := false
    return false
}

Notify(msg) => SendToUI(Map("type","log",     "message",msg))
Progress(v)  => SendToUI(Map("type","progress","value",  v))
Done(msg)    => SendToUI(Map("type","done",    "message",msg))
