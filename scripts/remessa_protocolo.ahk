#Requires AutoHotkey v2.0
#Include mv_session.ahk

; ════════════════════════════════════════════════════════════════
;  REMESSA POR PROTOCOLO
; ════════════════════════════════════════════════════════════════

; ── Imagens do fluxo MOV DOC ──────────────────────────────────
RP_IMG_MENU_MANUTENCAO       := MV_IMG_DIR "\Menu_Manutenção.png"
RP_IMG_MENU_PROTOCOLACAO     := MV_IMG_DIR "\Menu_Protocolação.png"
RP_IMG_MENU_BAIXA            := MV_IMG_DIR "\Menu_Baixa.png"
RP_IMG_TELA_BAIXA            := MV_IMG_DIR "\Tittle_TelaBaixa.png"
RP_IMG_ERRO_ICONE            := MV_IMG_DIR "\Erro_Icone.png"
RP_IMG_RECEBIMENTO_CHECKADO  := MV_IMG_DIR "\Botão_RecebimentoCheckado.png"

; ── Janelas ───────────────────────────────────────────────────
WIN_MOVDOC_BAIXA       := MV_WIN_MOVDOC_BAIXA
WIN_MOVDOC_POPUP       := "Forms ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"
WIN_FFCV_POPUP         := "TÍTULO POPUP ENVIO DE CONTA"    ; pendente Window Spy
WIN_FFCV_DATAS         := "Cadastro: Faturas e Remessas"
WIN_FFCV_DATAS_OK      := "Mensagem ao Usuário do MV 2000"
WIN_CAPA_REMESSA       := "Relatório de Atendimentos da Remessa"
WIN_XML                := "Monitoração de Faturamento - TISS"
WIN_XML_PATH_FORM      := "MV2000i - Faturamento - [WIN_PRINCIPAL]"
WIN_XML_POPUP_SIMNAO   := "Mensagem ao Usuário do MV 2000"

; ── Controles MOV DOC — preencher com Window Spy ──────────────
; Use ClassNN + coordenada Client. Quando faltar mapeamento, o script aborta.
MOVDOC_CAMPO_PROTOCOLO_CLASS := "CLASSNN"  ; pendente Window Spy
MOVDOC_CAMPO_PROTOCOLO_X     := ""         ; pendente Window Spy
MOVDOC_CAMPO_PROTOCOLO_Y     := ""         ; pendente Window Spy

MOVDOC_CAMPO_CONVENIO_CLASS  := "CLASSNN"  ; pendente Window Spy
MOVDOC_CAMPO_CONVENIO_X      := ""         ; pendente Window Spy
MOVDOC_CAMPO_CONVENIO_Y      := ""         ; pendente Window Spy

MOVDOC_CAMPO_CONTA_CLASS     := "CLASSNN"  ; pendente Window Spy
MOVDOC_CAMPO_CONTA_X         := ""         ; pendente Window Spy
MOVDOC_CAMPO_CONTA_Y         := ""         ; pendente Window Spy

; Confirmado previamente para primeira linha, mas manter validável por teste.
MOVDOC_CHECK_RECEBIDO_CLASS  := "Button1"
MOVDOC_CHECK_RECEBIDO_X      := 718
MOVDOC_CHECK_RECEBIDO_Y      := 359

; ── Controles FFCV ────────────────────────────────────────────
FFCV_BTN_HABILITAR     := "CLASSNN"  ; preferir F7; pendente Window Spy
FFCV_CAMPO_CONVENIO    := "CLASSNN"  ; pendente Window Spy
FFCV_AREA_REMESSAS     := "CLASSNN"  ; alternativa Tab x3; pendente Window Spy
FFCV_BTN_BUSCAR_REM    := "CLASSNN"  ; preferir F7; pendente Window Spy
FFCV_CAMPO_NUM_REM     := "CLASSNN"  ; pendente Window Spy
FFCV_BTN_CONFIRMAR_REM := "CLASSNN"  ; preferir F8; pendente Window Spy
FFCV_BTN_NOVA_REM      := "CLASSNN"  ; preferir F6; pendente Window Spy
FFCV_CAMPO_DATA_REM    := "CLASSNN"  ; pendente Window Spy
FFCV_CAMPO_TIPO        := "CLASSNN"  ; pendente Window Spy
FFCV_BTN_SALVAR_REM    := "CLASSNN"  ; preferir F10; pendente Window Spy
FFCV_BTN_ADICIONAR     := "Button10" ; 1 - Inserir Conta
FFCV_BTN_FINALIZAR     := "Button3"  ; fechar contas sem imprimir faturas
FFCV_BTN_ABRIR_DATAS   := "Button6"  ; 5 - Entregar Rem.

; ── Controles popup de envio de contas ────────────────────────
POPUP_DROPDOWN_1   := "CLASSNN"  ; pendente Window Spy
POPUP_DROPDOWN_2   := "CLASSNN"  ; pendente Window Spy
POPUP_CAMPO_CONTA  := "CLASSNN"  ; pendente Window Spy
POPUP_BTN_OK       := "CLASSNN"  ; pendente botão OK do popup de conta já digitada

; ── Controles tela de datas ───────────────────────────────────
DATAS_CAMPO_REMESSA    := "Edit1"    ; pendente confirmar
DATAS_CAMPO_ENTREGA    := "CLASSNN"  ; pendente Window Spy
DATAS_CAMPO_VENCIMENTO := "CLASSNN"  ; pendente Window Spy
DATAS_CHECKBOX         := "Button3"
DATAS_BTN_CONFIRMAR    := "Button10"
DATAS_BTN_VOLTAR       := "Button7"

; ── Controles tela XML ────────────────────────────────────────
XML_CAMPO_REMESSA   := "CLASSNN"  ; pendente Window Spy
XML_BTN_BUSCAR      := "CLASSNN"  ; preferir F8; pendente Window Spy
XML_BTN_FATURAMENTO := "Button7"  ; 1 Faturamento
XML_FORM_CAMPO_PATH := "Edit1"
XML_FORM_BTN_ENVIAR := "Button4"
XML_BTN_NAO         := "Button2"
XML_BTN_SAIR_FORM   := "Button7"
XML_BTN_SAIR_TELA   := ""         ; pendente

; ── Fragmentos de texto dos erros no popup de envio ───────────
ERR_JA_DIGITADA        := "já digitada"
ERR_CONVENIO_DIFERENTE := "convênio diferente"
ERR_CONTA_ABERTA       := "conta aberta"
ERR_TIPO_DIFERENTE     := "tipo diferente"

TIPO_CODIGO := Map("Emergência", "1", "Internamento", "2", "Ambulatório", "3")

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

    protocolContas := Map()
    erros          := []
    convenioNum    := ""

    Notify("Garantindo MOV DOC...")
    if !MV_EnsureMovDoc()
        return RP_Abort("Não foi possível acessar o MOV DOC.")

    if !RP_AbrirTelaBaixaMovDoc()
        return RP_Abort("Não consegui abrir a tela Baixa de Documentos no MOV DOC.")

    Progress(5)

    for idx, protocolo in protocolos {
        Notify("Processando protocolo " protocolo " (" idx "/" protocolos.Length ")")
        result := ProcessarProtocolo(protocolo, convenioNum = "")

        if !result["ok"]
            return RP_Abort(result["erro"])

        if (convenioNum = "" && result["convenio"] != "")
            convenioNum := result["convenio"]

        protocolContas[protocolo] := result["contas"]
        Progress(5 + (idx / protocolos.Length) * 40)
    }

    if (convenioNum = "")
        return RP_Abort("Convênio não identificado. Falta mapear/validar o textfield de convênio.")

    Notify("Garantindo FFCV...")
    if !MV_EnsureFFCV()
        return RP_Abort("Não foi possível acessar o FFCV.")

    Progress(50)
    HabilitarEdicaoFFCV()

    if !RP_SetControlText(MV_WIN_FFCV, FFCV_CAMPO_CONVENIO, convenioNum, "campo Convênio do FFCV")
        return false

    PosicionarAreaRemessas()

    if (numRemessa != "") {
        if !SelecionarRemessaExistente(numRemessa)
            return RP_Abort("Remessa " numRemessa " não encontrada.")
    } else {
        if !CriarNovaRemessa(tipoConta)
            return RP_Abort("Erro ao criar nova remessa.")
    }

    Progress(60)
    if !InserirContasNaRemessa(protocolContas, tipoConta, erros)
        return false

    Progress(87)

    if temDatas {
        Notify("Preenchendo datas...")
        result := FinalizarComDatas(dataEntrega, dataVenc)
        if !result["ok"]
            return RP_Abort(result["erro"])
        Progress(94)
        Notify("Gerando XML...")
        GerarXML(result["remessa"])
    } else {
        FinalizarSemDatas()
    }

    Progress(100)
    gRunning := false

    if (erros.Length > 0) {
        linhas := "Concluído com " erros.Length " pendência(s):`n"
        for _, e in erros
            linhas .= "  Prot. " e["protocolo"] " | Conta " e["conta"] " | " e["descricao"] "`n"
        Done(linhas)
    } else {
        Done("Remessa concluída com sucesso!")
    }
}

; ════════════════════════════════════════════════════════════════
;  FASE MOV DOC
; ════════════════════════════════════════════════════════════════

RP_AbrirTelaBaixaMovDoc() {
    MV_ActivateModule(MV_WIN_MOVDOC_ANY)
    Sleep MV_DELAY_INPUT

    if !MV_ClickImage(RP_IMG_MENU_MANUTENCAO)
        return false
    Sleep 180

    if !MV_ClickImage(RP_IMG_MENU_PROTOCOLACAO)
        return false
    Sleep 180

    if !MV_ClickImage(RP_IMG_MENU_BAIXA)
        return false

    return MV_Poll(() => WinExist(WIN_MOVDOC_BAIXA) || MV_ImageVisible(RP_IMG_TELA_BAIXA), MV_TIMEOUT_LOAD)
}

ProcessarProtocolo(protocolo, coletarConvenio := true) {
    if !RP_RequireClientControl(MOVDOC_CAMPO_PROTOCOLO_CLASS, MOVDOC_CAMPO_PROTOCOLO_X, MOVDOC_CAMPO_PROTOCOLO_Y, "campo Protocolo do MOV DOC")
        return Map("ok", false, "erro", "Falta mapear ClassNN/coordenada do campo Protocolo do MOV DOC.")
    if coletarConvenio && !RP_RequireClientControl(MOVDOC_CAMPO_CONVENIO_CLASS, MOVDOC_CAMPO_CONVENIO_X, MOVDOC_CAMPO_CONVENIO_Y, "campo Convênio do MOV DOC")
        return Map("ok", false, "erro", "Falta mapear ClassNN/coordenada do campo Convênio do MOV DOC.")
    if !RP_RequireClientControl(MOVDOC_CAMPO_CONTA_CLASS, MOVDOC_CAMPO_CONTA_X, MOVDOC_CAMPO_CONTA_Y, "primeiro campo Conta do MOV DOC")
        return Map("ok", false, "erro", "Falta mapear ClassNN/coordenada do primeiro campo Conta do MOV DOC.")

    WinActivate WIN_MOVDOC_BAIXA
    if !MV_SetTextControlAt(WIN_MOVDOC_BAIXA, MOVDOC_CAMPO_PROTOCOLO_CLASS, MOVDOC_CAMPO_PROTOCOLO_X, MOVDOC_CAMPO_PROTOCOLO_Y, protocolo)
        return Map("ok", false, "erro", "Não consegui focar/preencher o campo Protocolo.")

    Sleep MV_DELAY_INPUT
    Send "{F8}"
    RP_WaitLoadingAfterF8()

    convenio := ""
    if coletarConvenio
        convenio := MV_ReadTextControlAt(WIN_MOVDOC_BAIXA, MOVDOC_CAMPO_CONVENIO_CLASS, MOVDOC_CAMPO_CONVENIO_X, MOVDOC_CAMPO_CONVENIO_Y)

    contas := RP_ColetarContasPorClipboard()
    if (contas.Length = 0)
        return Map("ok", false, "erro", "Nenhuma conta foi coletada para o protocolo " protocolo ".")

    if !RP_FinalizarBaixaProtocolo()
        return Map("ok", false, "erro", "Falha ao salvar/baixar o protocolo " protocolo ".")

    return Map("ok", true, "contas", contas, "convenio", convenio)
}

RP_ColetarContasPorClipboard() {
    contas := []

    Loop {
        A_Clipboard := ""
        if !MV_DoubleClickControlAt(WIN_MOVDOC_BAIXA, MOVDOC_CAMPO_CONTA_CLASS, MOVDOC_CAMPO_CONTA_X, MOVDOC_CAMPO_CONTA_Y)
            break
        Sleep MV_DELAY_INPUT
        Send "^c"
        MV_Poll(() => A_Clipboard != "" || RP_MovDocPopupVisible(), 3)

        if RP_MovDocPopupVisible()
            break

        numConta := Trim(A_Clipboard)
        if (numConta != "")
            contas.Push(Map("conta", numConta))

        Send "{Down}"
        Sleep MV_DELAY_INPUT

        if MV_Poll(() => RP_MovDocPopupVisible(), 0.25)
            break
    }

    if RP_MovDocPopupVisible()
        RP_DismissMovDocPopup()

    return contas
}

RP_MovDocPopupVisible() {
    return WinExist(WIN_MOVDOC_POPUP) || MV_ImageVisible(RP_IMG_ERRO_ICONE)
}

RP_DismissMovDocPopup() {
    try {
        if WinExist(WIN_MOVDOC_POPUP) {
            WinActivate WIN_MOVDOC_POPUP
            Sleep MV_DELAY_INPUT
            ControlClick "Button1", WIN_MOVDOC_POPUP,,,, "NA"
            MV_Poll(() => !WinExist(WIN_MOVDOC_POPUP), MV_TIMEOUT_ACOE)
            return true
        }
    }
    Send "{Enter}"
    Sleep MV_DELAY_INPUT
    return true
}

RP_FinalizarBaixaProtocolo() {
    ; Checkbox Recebido: se a imagem de checkado já existe, double-click; se não, click simples.
    checked := MV_ImageVisible(RP_IMG_RECEBIMENTO_CHECKADO)
    if checked
        MV_DoubleClickControlAt(WIN_MOVDOC_BAIXA, MOVDOC_CHECK_RECEBIDO_CLASS, MOVDOC_CHECK_RECEBIDO_X, MOVDOC_CHECK_RECEBIDO_Y)
    else
        MV_ClickControlAt(WIN_MOVDOC_BAIXA, MOVDOC_CHECK_RECEBIDO_CLASS, MOVDOC_CHECK_RECEBIDO_X, MOVDOC_CHECK_RECEBIDO_Y)

    Sleep MV_DELAY_INPUT

    ; Volta para o campo inicial do protocolo, salva com F10, espera loading e prepara nova consulta com F7.
    if !MV_FocusControlAt(WIN_MOVDOC_BAIXA, MOVDOC_CAMPO_PROTOCOLO_CLASS, MOVDOC_CAMPO_PROTOCOLO_X, MOVDOC_CAMPO_PROTOCOLO_Y)
        return false

    Sleep MV_DELAY_INPUT
    Send "{F10}"
    RP_WaitLoadingAfterSave()
    Send "{F7}"
    Sleep MV_DELAY_INPUT
    return true
}

RP_WaitLoadingAfterF8() {
    ; O MV não expõe loading confiável ainda; esta espera curta é só estabilização pós-F8.
    MV_Poll(() => WinExist(WIN_MOVDOC_BAIXA) || MV_ImageVisible(RP_IMG_TELA_BAIXA), MV_TIMEOUT_LOAD)
    Sleep 250
}

RP_WaitLoadingAfterSave() {
    Sleep 400
    MV_Poll(() => WinExist(WIN_MOVDOC_BAIXA) || MV_ImageVisible(RP_IMG_TELA_BAIXA), MV_TIMEOUT_LOAD)
}

; ════════════════════════════════════════════════════════════════
;  FASE FFCV
; ════════════════════════════════════════════════════════════════

HabilitarEdicaoFFCV() {
    Send "{F7}"
    Sleep MV_DELAY_INPUT
}

PosicionarAreaRemessas() {
    Send "{Tab}{Tab}{Tab}"
    Sleep MV_DELAY_INPUT
}

SelecionarRemessaExistente(numRemessa) {
    Send "{F7}"
    Sleep MV_DELAY_INPUT
    if !RP_SetControlText(MV_WIN_FFCV, FFCV_CAMPO_NUM_REM, numRemessa, "campo Número da Remessa")
        return false
    Send "{F8}"
    return MV_Poll(() => WinExist(MV_WIN_FFCV), MV_TIMEOUT_LOAD)
}

CriarNovaRemessa(tipoConta) {
    Send "{F6}"
    Sleep MV_DELAY_INPUT

    hoje := FormatTime(, "dd/MM/yyyy")
    if !RP_SetControlText(MV_WIN_FFCV, FFCV_CAMPO_DATA_REM, hoje, "campo Data da Remessa")
        return false

    Send "{Enter}{Enter}{Enter}"
    Sleep MV_DELAY_INPUT

    if !RP_SetControlText(MV_WIN_FFCV, FFCV_CAMPO_TIPO, TIPO_CODIGO[tipoConta], "campo Tipo da Remessa")
        return false

    Send "{F10}"
    return MV_Poll(() => WinExist(MV_WIN_FFCV), MV_TIMEOUT_LOAD)
}

InserirContasNaRemessa(protocolContas, tipoConta, erros) {
    global gRunning

    ControlClick FFCV_BTN_ADICIONAR, MV_WIN_FFCV,,,, "NA"
    if !MV_Poll(() => WinExist(WIN_FFCV_POPUP), MV_TIMEOUT_ACOE)
        return RP_Abort("Popup de envio de contas não abriu.")

    WinActivate WIN_FFCV_POPUP
    ConfigurarDropdownsPopup(tipoConta)

    totalContas := ContarContas(protocolContas)
    contaIdx := 0

    for protocolo, contas in protocolContas {
        for _, contaObj in contas {
            contaIdx++
            numConta := contaObj["conta"]
            Notify("Enviando conta " numConta " [prot. " protocolo "]")
            erro := EnviarConta(numConta)

            if (erro != "") {
                if InStr(erro, ERR_JA_DIGITADA) {
                    ControlClick POPUP_BTN_OK, WIN_FFCV_POPUP,,,, "NA"
                } else {
                    erros.Push(Map("protocolo", protocolo, "conta", numConta, "descricao", ClassificarErro(erro)))
                    DismissErroPopup()
                }
            }

            Progress(60 + (contaIdx / totalContas) * 25)
        }
    }

    WinClose WIN_FFCV_POPUP
    MV_Poll(() => !WinExist(WIN_FFCV_POPUP), MV_TIMEOUT_ACOE)
    return true
}

ConfigurarDropdownsPopup(tipoConta) {
    ControlChooseIndex 2, POPUP_DROPDOWN_1, WIN_FFCV_POPUP
    Sleep MV_DELAY_INPUT
    opcaoDrop2 := (tipoConta = "Internamento") ? 1 : 2
    ControlChooseIndex opcaoDrop2, POPUP_DROPDOWN_2, WIN_FFCV_POPUP
    Sleep MV_DELAY_INPUT
}

EnviarConta(numConta) {
    ControlSetText numConta, POPUP_CAMPO_CONTA, WIN_FFCV_POPUP
    Sleep MV_DELAY_INPUT
    ControlSend "{Enter}", POPUP_CAMPO_CONTA, WIN_FFCV_POPUP

    popupErro := MV_WaitAnyWindow(["TÍTULO POPUP ERRO CONTA", "Atenção", "Aviso"], MV_TIMEOUT_ACOE)
    return (popupErro != "") ? WinGetText(popupErro) : ""
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
    try ControlClick "Button1",,,,, "NA"
    Sleep MV_DELAY_INPUT
}

; ════════════════════════════════════════════════════════════════
;  FASE FINALIZAÇÃO / XML
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
    ControlSetText dataEntrega, DATAS_CAMPO_ENTREGA, WIN_FFCV_DATAS
    Sleep MV_DELAY_INPUT
    ControlSetText dataVenc, DATAS_CAMPO_VENCIMENTO, WIN_FFCV_DATAS
    Sleep MV_DELAY_INPUT

    ControlClick DATAS_CHECKBOX, WIN_FFCV_DATAS,,,, "NA"
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

    if !MV_Poll(() => WinExist(WIN_XML), MV_TIMEOUT_LOAD)
        return Notify("Erro: tela de XML não encontrada.")

    WinActivate WIN_XML
    Sleep MV_DELAY_INPUT
    ControlSetText numRemessa, XML_CAMPO_REMESSA, WIN_XML
    Sleep MV_DELAY_INPUT
    ControlSend "{F8}", XML_CAMPO_REMESSA, WIN_XML

    ControlClick XML_BTN_FATURAMENTO, WIN_XML,,,, "NA"
    if !MV_Poll(() => WinExist(WIN_XML_PATH_FORM), MV_TIMEOUT_LOAD)
        return Notify("Erro: tela de XML gerado não abriu.")

    xmlDir := gWorkDir "\XML"
    if !DirExist(xmlDir)
        DirCreate xmlDir

    xmlPath := xmlDir "\" numRemessa ".xml"
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

RP_Abort(msg) {
    global gRunning
    SendToUI(Map("type", "error", "message", msg))
    gRunning := false
    return false
}

Notify(msg) => SendToUI(Map("type", "log", "message", msg))
Progress(v)  => SendToUI(Map("type", "progress", "value", v))
Done(msg)    => SendToUI(Map("type", "done", "message", msg))
