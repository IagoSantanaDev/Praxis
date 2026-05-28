#Requires AutoHotkey v2.0
#Include mv_session.ahk

; ════════════════════════════════════════════════════════════════
;  REMESSA POR PROTOCOLO
; ════════════════════════════════════════════════════════════════

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

; ── Regiões MOV DOC em coordenadas Client ─────────────────────
; Não usar EditN como contrato: Oracle Forms renumera Edit1/Edit2/Edit15 conforme estado.
; A automação localiza qualquer Edit* nessas regiões e valida texto numérico.
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
FFCV_BTN_FINALIZAR     := "Button3"  ; fechar contas sem imprimir faturas
FFCV_BTN_FINALIZAR_X   := 541        ; Window Spy: client x do Button3
FFCV_BTN_FINALIZAR_Y   := 242        ; Window Spy: client y do Button3
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

    linhasMovDoc := []
    erros        := []
    convenioNum  := ""

    Notify("Garantindo MOV DOC...")
    if !MV_EnsureMovDoc()
        return RP_Abort("Não foi possível acessar o MOV DOC.")

    if !RP_AbrirTelaBaixaMovDoc()
        return RP_Abort("Não consegui abrir a tela Baixa de Documentos no MOV DOC.")

    Progress(5)

    for idx, protocolo in protocolos {
        Notify("Processando protocolo " protocolo " (" idx "/" protocolos.Length ")")
        result := ProcessarProtocolo(protocolo)

        if !result["ok"]
            return RP_Abort(result["erro"])

        for _, linha in result["linhas"]
            linhasMovDoc.Push(linha)

        Progress(5 + (idx / protocolos.Length) * 40)
    }

    convenioNum := RP_ConvenioMajoritario(linhasMovDoc)
    if (convenioNum = "")
        return RP_Abort("Convênio não identificado no MOV DOC.")

    protocolContas := RP_FiltrarContasPorConvenio(linhasMovDoc, convenioNum, erros)

    Notify("Garantindo FFCV...")
    if !MV_EnsureFFCV()
        return RP_Abort("Não foi possível acessar o FFCV.")

    if !RP_AbrirManutencaoRemessaFFCV()
        return RP_Abort("Não consegui abrir Manutenção de Remessa no FFCV.")

    Progress(50)

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
    ; Sempre abre uma nova instância da tela funcional. Não reutilizar Baixa já aberta.
    MV_ActivateModule(MV_WIN_MOVDOC_ANY)
    Sleep MV_DELAY_INPUT

    ; Atalho validado no macro 02: Manutenção → Protocolação → Baixa.
    Send "{Alt down}"
    Send "m"
    Send "p"
    Send "b"
    Send "{Alt up}"

    return MV_Poll(() => WinExist(WIN_MOVDOC_BAIXA), MV_TIMEOUT_LOAD)
}

ProcessarProtocolo(protocolo) {
    WinActivate WIN_MOVDOC_BAIXA
    if !MV_SetTextEditAtPoint(WIN_MOVDOC_BAIXA, MOVDOC_PROTOCOLO_X, MOVDOC_PROTOCOLO_Y, protocolo)
        return Map("ok", false, "erro", "Não consegui focar/preencher o campo Protocolo.")

    Sleep MV_DELAY_INPUT
    Send "{F8}"
    RP_WaitLoadingAfterF8()

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
    Loop 4 {
        Send "{Down}"
        Sleep MV_DELAY_INPUT

        if MV_Poll(() => RP_MovDocPopupWindowVisible(), 0.25) {
            RP_DismissMovDocPopup()
            return Map("popup", true)
        }
    }

    return Map("popup", false)
}

RP_ColetarLinhasVisiveisMovDoc(protocolo, linhas, vistos) {
    added := 0

    for _, rowY in MOVDOC_GRID_ROWS_Y {
        conta := MV_ReadEditAtPoint(WIN_MOVDOC_BAIXA, MOVDOC_CONTA_X, rowY, "^\d+$")
        convenio := MV_ReadEditAtPoint(WIN_MOVDOC_BAIXA, MOVDOC_CONVENIO_X, rowY, "^\d+$")

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

    Sleep MV_DELAY_INPUT

    ; Volta para o campo inicial do protocolo, salva com F10, espera loading e prepara nova consulta com F7.
    if !MV_FocusEditAtPoint(WIN_MOVDOC_BAIXA, MOVDOC_PROTOCOLO_X, MOVDOC_PROTOCOLO_Y)
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
    MV_Poll(() => WinExist(WIN_MOVDOC_BAIXA), MV_TIMEOUT_LOAD)
    Sleep 250
}

RP_WaitLoadingAfterSave() {
    Sleep 400
    MV_Poll(() => WinExist(WIN_MOVDOC_BAIXA), MV_TIMEOUT_LOAD)
}

; ════════════════════════════════════════════════════════════════
;  FASE FFCV
; ════════════════════════════════════════════════════════════════

RP_AbrirManutencaoRemessaFFCV() {
    ; Sempre abre uma nova instância da tela funcional. Não reutilizar Manutenção já aberta.
    MV_ActivateModule(MV_WIN_FFCV_ANY)
    Sleep MV_DELAY_INPUT

    ; Atalho validado no macro 03: Lançamentos → Manutenção de Remessa.
    Send "{Alt down}"
    Send "l"
    Send "m"
    Send "{Alt up}"
    Send "{Enter}"

    return MV_Poll(() => WinExist(MV_WIN_FFCV_REMESSA), MV_TIMEOUT_LOAD)
}

CarregarConvenioFFCV(convenioNum) {
    MV_ActivateModule(MV_WIN_FFCV_ANY)
    Send "{F7}"
    Sleep MV_DELAY_INPUT
    SendText convenioNum
    Sleep MV_DELAY_INPUT
    Send "{F8}"
    return RP_WaitFFCVLoad()
}

PosicionarAreaRemessas() {
    Send "{Tab 3}"
    Sleep MV_DELAY_INPUT
}

SelecionarRemessaExistente(numRemessa) {
    Send "{F7}"
    Sleep MV_DELAY_INPUT
    SendText numRemessa
    Sleep MV_DELAY_INPUT
    Send "{F8}"
    return RP_WaitFFCVLoad()
}

CriarNovaRemessa(tipoConta) {
    Send "{F6}"
    Sleep MV_DELAY_INPUT

    hoje := FormatTime(, "dd/MM/yyyy")
    SendText hoje
    Sleep MV_DELAY_INPUT
    Send "{Tab 3}"
    Sleep MV_DELAY_INPUT
    SendText TIPO_CODIGO[tipoConta]
    Sleep MV_DELAY_INPUT
    Send "{F10}"
    return RP_WaitFFCVLoad()
}

InserirContasNaRemessa(protocolContas, tipoConta, erros) {
    Send "!1"
    if !RP_WaitAnyModalOrDelay(5)
        Sleep 300

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
                if InStr(StrLower(erro), StrLower(ERR_JA_DIGITADA)) {
                    RP_DismissActiveModal()
                } else {
                    erros.Push(Map("protocolo", protocolo, "conta", numConta, "descricao", ClassificarErro(erro)))
                    RP_DismissActiveModal()
                }
            }

            Progress(60 + (contaIdx / totalContas) * 25)
        }
    }

    Send "!2"
    Sleep MV_DELAY_INPUT
    return true
}

ConfigurarDropdownsPopup(tipoConta) {
    ; Foco inicial do popup nem sempre é confiável. A regra validada pelo usuário:
    ; Tab x3 → dropdown 1 → Down x2 → Tab → dropdown 2 → se Emergência/Ambulatório Up x2 → Tab.
    Sleep 250
    Send "{Tab 3}"
    Sleep MV_DELAY_INPUT
    Send "{Down 2}"
    Sleep MV_DELAY_INPUT
    Send "{Tab}"
    Sleep MV_DELAY_INPUT

    if (tipoConta != "Internamento") {
        Send "{Up 2}"
        Sleep MV_DELAY_INPUT
    }

    Send "{Tab}"
    Sleep MV_DELAY_INPUT
}

EnviarConta(numConta) {
    SendText numConta
    Sleep MV_DELAY_INPUT
    Send "{Enter}"

    popupErro := RP_WaitErrorModalAfterConta(1.5)
    return (popupErro != "") ? WinGetText(popupErro) : ""
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
            Send "{Enter}"
            MV_Poll(() => !WinExist(popup), MV_TIMEOUT_ACOE)
            return true
        }
    }
    Send "{Enter}"
    Sleep MV_DELAY_INPUT
    return true
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
    Sleep 300
    return MV_Poll(() => WinExist(MV_WIN_FFCV_ANY), MV_TIMEOUT_LOAD)
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
    Send "!5"
    if !MV_Poll(() => WinExist(WIN_FFCV_DATAS), MV_TIMEOUT_LOAD)
        return Map("ok", false, "erro", "Tela de fechar remessa/datas não abriu.")

    Sleep MV_DELAY_INPUT
    Send "+{Tab}"
    Sleep MV_DELAY_INPUT
    numRemessa := RP_CopyFocusedText()

    Send "{Tab}"
    Sleep MV_DELAY_INPUT
    SendText dataEntrega
    Sleep MV_DELAY_INPUT
    Send "{Enter}"
    Sleep MV_DELAY_INPUT
    SendText dataVenc
    Sleep MV_DELAY_INPUT

    if !MV_ClickControlAt(WIN_FFCV_DATAS, FFCV_BTN_FINALIZAR, FFCV_BTN_FINALIZAR_X, FFCV_BTN_FINALIZAR_Y)
        Send "{Tab}"
    Sleep MV_DELAY_INPUT

    Send "!1"
    if !RP_WaitAnyModalOrDelay(MV_TIMEOUT_ACOE)
        return Map("ok", false, "erro", "Popup de confirmação não apareceu.")
    if !RP_ClickNaoModal()
        return Map("ok", false, "erro", "Não consegui clicar Não no popup de confirmação.")

    if !MV_Poll(() => WinExist(WIN_CAPA_REMESSA), MV_TIMEOUT_LOAD)
        return Map("ok", false, "erro", "Tela de impressão não apareceu.")

    Send "{Enter}"
    MV_Poll(() => !WinExist(WIN_CAPA_REMESSA), MV_TIMEOUT_LOAD)

    RP_SairTelaAtual()
    return Map("ok", true, "remessa", Trim(numRemessa))
}

GerarXML(numRemessa) {
    global gWorkDir

    if !RP_AbrirTelaTISS()
        return Notify("Erro: tela XML/TISS não abriu.")

    Send "{Tab 5}"
    Sleep MV_DELAY_INPUT
    SendText numRemessa
    Sleep MV_DELAY_INPUT
    Send "{F8}"
    RP_WaitFFCVLoad()

    Send "!1"
    if !MV_Poll(() => WinExist(WIN_XML_PATH_FORM), MV_TIMEOUT_LOAD)
        return Notify("Erro: tela de XML gerado não abriu.")

    xmlDir := gWorkDir "\XML"
    if !DirExist(xmlDir)
        DirCreate xmlDir

    xmlPath := xmlDir "\" numRemessa ".xml"

    if !MV_FocusControlAt(WIN_XML_PATH_FORM, XML_FORM_CAMPO_PATH, XML_FORM_CAMPO_PATH_X, XML_FORM_CAMPO_PATH_Y)
        return RP_Abort("Não consegui focar o campo de caminho do XML.")
    Sleep MV_DELAY_INPUT
    Send "^a"
    Sleep MV_DELAY_INPUT
    SendText xmlPath
    Sleep MV_DELAY_INPUT

    if !MV_ClickControlAt(WIN_XML_PATH_FORM, XML_FORM_BTN_SALVAR, XML_FORM_BTN_SALVAR_X, XML_FORM_BTN_SALVAR_Y)
        return RP_Abort("Não consegui acionar o botão Salvar_XML.")

    if !RP_WaitAnyModalOrDelay(MV_TIMEOUT_ACOE)
        return RP_Abort("Popup de confirmação do XML não apareceu.")
    if !RP_ClickNaoModal()
        return RP_Abort("Não consegui clicar Não no popup de confirmação do XML.")
    MV_Poll(() => !WinExist("ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"), MV_TIMEOUT_ACOE)

    if !MV_ClickControlAt(WIN_XML_PATH_FORM, XML_FORM_BTN_VOLTAR, XML_FORM_BTN_VOLTAR_X, XML_FORM_BTN_VOLTAR_Y)
        return RP_Abort("Não consegui voltar da tela de XML gerado.")
    Sleep 500

    RP_SairTelaAtual()
}

RP_AbrirTelaTISS() {
    ; Sempre abre uma nova instância da tela funcional. Não reutilizar TISS já aberta.
    MV_ActivateModule(MV_WIN_FFCV_ANY)
    Sleep MV_DELAY_INPUT

    ; Atalho esperado: Lançamentos → Monitoração de Faturamento - TISS.
    Send "{Alt down}"
    Send "l"
    Send "t"
    Send "{Alt up}"
    Send "{Enter}"

    return MV_Poll(() => WinExist(WIN_XML), MV_TIMEOUT_LOAD)
}

RP_CopyFocusedText() {
    A_Clipboard := ""
    Send "^c"
    MV_Poll(() => A_Clipboard != "", 3)
    return Trim(A_Clipboard)
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

RP_Abort(msg) {
    global gRunning
    SendToUI(Map("type", "error", "message", msg))
    gRunning := false
    return false
}

Notify(msg) => SendToUI(Map("type", "log", "message", msg))
Progress(v)  => SendToUI(Map("type", "progress", "value", v))
Done(msg)    => SendToUI(Map("type", "done", "message", msg))
