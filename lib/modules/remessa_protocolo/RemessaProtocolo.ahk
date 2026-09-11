; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug
#Include ..\..\..\lib\globals\mv\MVSession.ahk
#Include ..\..\..\lib\globals\mv\FFCV_ErrorTemplates.ahk
#Include ..\..\..\lib\globals\mv\components\Popups.ahk
#Include ..\..\..\lib\globals\mv\components\Dialogs.ahk
#Include ..\..\..\lib\globals\mv\screens\MovDocScreen.ahk
#Include ..\..\..\lib\globals\mv\screens\FfcvScreen.ahk
#Include ..\..\..\lib\globals\mv\screens\FfcvContaPopup.ahk
#Include ..\..\..\lib\globals\mv\screens\TissXmlScreen.ahk
#Include RPParsers.ahk

ListLines(false)
; SetKeyDelay/SetControlDelay ja sao configurados por MVSession.ahk (0,0 / 0).
; Nao redefinir aqui para nao reintroduzir delays na automacao do MV.
SetMouseDelay(-1)
SetDefaultMouseSpeed(0)

; ════════════════════════════════════════════════════════════════
;  REMESSA POR PROTOCOLO — orquestrador
; ════════════════════════════════════════════════════════════════
;
; Fluxo:
;   1. Abre MOV DOC Baixa — consulta cada protocolo, baixa, coleta linhas.
;   2. Identifica convenio majoritario; filtra contas.
;   3. Abre FFCV Manutencao de Remessa; insere contas via popup.
;   4. Fecha remessa (com datas → XML TISS; sem datas → imprime relatorio).
;
; Responsabilidades por screen:
;   MovDocScreen    — consulta/coleta/baixa de protocolos.
;   FfcvScreen   — abertura de remessa e FFCV em geral.
;   FfcvContaPopup — envio de contas em lote dentro de FFCV.
;   TissXmlScreen  — geracao do arquivo XML TISS.
;
; Nota sobre coordenadas:
;   WIN_FFCV_DATAS, FFCV_BTN_ABRIR_DATAS, DATAS_CHECKBOX, DATAS_BTN_CONFIRMAR,
;   XML_CAMPO_REMESSA, XML_BTN_FATURAMENTO, XML_FORM_* — movidos para
;   globals/mv/screens/FfcvScreen.ahk.

; ── Esperas da fase de fechamento/XML ─────────────────────────
; Definidas em globals/mv/screens/FfcvScreen.ahk.
RP_FINAL_STABLE_MS         := FFCV_FINAL_STABLE_MS
RP_FINAL_ACTION_TIMEOUT_MS  := FFCV_FINAL_ACTION_TIMEOUT_MS

RunRemessaProtocolo(params) {
    global gRunning

    protocolos   := ParseProtocolos(params["protocolos"])
    tipoConta    := params["tipo_conta"]
    dataEntrega  := params["data_entrega"]
    dataVenc     := params["data_vencimento"]
    numRemessa   := Trim(params["num_remessa"])
    imprimirAposInserir := RP_OptionEnabled(params, "imprimir_apos_inserir", true)
    umProtocoloUmaRemessa := RP_OptionEnabled(params, "um_protocolo_uma_remessa", false)
    temDatas     := (dataEntrega != "" && dataVenc != "")

    if (protocolos.Length = 0)
        return RP_Abort("Informe ao menos um protocolo.")

    linhas := [], erros := [], timings := [], mapeamentoRemessas := []
    totalStart := stageStart := A_TickCount

    ; ── FLUXO: UM PROTOCOLO = UMA REMESSA ─────────────────────────
    if umProtocoloUmaRemessa {
        Notify("Iniciando fluxo: Um Protocolo = Uma Remessa...")

        for idx, protocolo in protocolos {
            ThrowIfAppStopped()
            pStart := A_TickCount
            Notify("Processando protocolo " protocolo " (" idx "/" protocolos.Length ") no MOV DOC...")

            if !MV_EnsureMovDoc() || !MovDoc_AbrirTelaBaixa()
                return RP_Abort("Nao foi possivel acessar o MOV DOC / abrir a tela Baixa para o protocolo " protocolo ".")

            result := ProcessarProtocolo(protocolo)
            if !result["ok"]
                return RP_Abort(result["erro"])

            linhasProtocolo := result["linhas"]
            convenioNum := RP_ConvenioMajoritario(linhasProtocolo)
            if (convenioNum = "")
                return RP_Abort("Convenio nao identificado no MOV DOC para o protocolo " protocolo ".")

            protocolContas := RP_FiltrarContasPorConvenio(linhasProtocolo, convenioNum, erros)
            totalContasFFCV := ContarContas(protocolContas)

            Notify("Abrindo FFCV para protocolo " protocolo " (convenio " convenioNum ")...")
            if !MV_EnsureFFCV() || !Ffcv_AbrirManutencaoRemessa()
                return RP_Abort("Nao foi possivel acessar o FFCV / abrir Manutencao de Remessa.")

            if !Ffcv_CarregarConvenio(convenioNum)
                return RP_Abort("Nao consegui carregar o convenio " convenioNum " no FFCV.")
            Ffcv_PosicionarAreaRemessas()

            if !Ffcv_CriarNovaRemessa(tipoConta)
                return RP_Abort("Erro ao criar nova remessa para o protocolo " protocolo ".")

            if !InserirContasNaRemessa(protocolContas, tipoConta, erros)
                return false

            criadaRemessa := ""

            if temDatas {
                Notify("Fechando remessa com datas para o protocolo " protocolo "...")
                if !Ffcv_PrepararEntregaPorProtocolo()
                    return RP_Abort("Nao foi possivel sair da Manutencao e abrir Entrega de Remessas.")

                resEntrega := Ffcv_ConfirmarEntregaNaTela(dataEntrega, dataVenc, true)
                if !resEntrega["ok"]
                    return RP_Abort(resEntrega["erro"])

                criadaRemessa := resEntrega["remessa"]
                if !Ffcv_SairTelaEntregaPendente()
                    return RP_Abort("A tela Entrega de Remessas nao fechou apos o protocolo.")

                Notify("Gerando XML TISS da remessa " criadaRemessa "...")
                xml := TissXml_Gerar(criadaRemessa)
                if !xml["ok"]
                    return RP_Abort(xml["erro"])
            } else if imprimirAposInserir {
                Notify("Imprimindo relatorio e capturando remessa via OCR para o protocolo " protocolo "...")
                Ffcv_ImprimirRelatorioAtendimentos(&criadaRemessa)
            }

            if (criadaRemessa != "")
                mapeamentoRemessas.Push(Map("remessa", criadaRemessa, "protocolo", protocolo))
            else
                mapeamentoRemessas.Push(Map("remessa", "N/I", "protocolo", protocolo))

            Notify("Concluido ciclo do protocolo " protocolo ": Remessa " criadaRemessa)
            Ffcv_ReiniciarManutencaoRemessa()
            Progress((idx / protocolos.Length) * 100)
        }

        RP_RecordTiming(timings, "Um Protocolo = Uma Remessa Total", totalStart, protocolos.Length " protocolo(s) processado(s)")
        gRunning := false
        Done(ErrosMensagem(erros, timings, mapeamentoRemessas))
        return true
    }

    ; ── FLUXO LEGADO: VÁRIOS PROTOCOLOS = UMA REMESSA ─────────────
    Notify("Garantindo MOV DOC...")
    if !MV_EnsureMovDoc() || !MovDoc_AbrirTelaBaixa()
        return RP_Abort("Nao foi possivel acessar o MOV DOC / abrir a tela Baixa.")
    RP_RecordTiming(timings, "Abrir MOV DOC e tela Baixa", stageStart)
    Progress(5)

    stageStart := A_TickCount
    for idx, protocolo in protocolos {
        ThrowIfAppStopped()
        pStart := A_TickCount
        Notify("Processando protocolo " protocolo " (" idx "/" protocolos.Length ")")
        result := ProcessarProtocolo(protocolo)
        if !result["ok"]
            return RP_Abort(result["erro"])
        for _, linha in result["linhas"]
            linhas.Push(linha)
        Notify("⏱ MOV DOC " protocolo ": " RP_FormatDuration(A_TickCount - pStart) " | " result["linhas"].Length " linha(s)")
        Progress(5 + (idx / protocolos.Length) * 40)
    }
    RP_RecordTiming(timings, "MOV DOC", stageStart, protocolos.Length " protocolo(s), " linhas.Length " linha(s)")

    convenioNum := RP_ConvenioMajoritario(linhas)
    if (convenioNum = "")
        return RP_Abort("Convenio nao identificado no MOV DOC.")
    protocolContas := RP_FiltrarContasPorConvenio(linhas, convenioNum, erros)
    totalContasFFCV := ContarContas(protocolContas)

    ; ── FFCV ──────────────────────────────────────────────────
    stageStart := A_TickCount
    Notify("Garantindo FFCV...")
    if !MV_EnsureFFCV() || !Ffcv_AbrirManutencaoRemessa()
        return RP_Abort("Nao foi possivel acessar o FFCV / abrir Manutencao de Remessa.")
    RP_RecordTiming(timings, "Abrir FFCV", stageStart)
    Progress(50)

    stageStart := A_TickCount
    if !Ffcv_CarregarConvenio(convenioNum)
        return RP_Abort("Nao consegui carregar o convenio " convenioNum " no FFCV.")
    Ffcv_PosicionarAreaRemessas()
    if (numRemessa != "") {
        if !Ffcv_SelecionarRemessaExistente(numRemessa)
            return RP_Abort("Remessa " numRemessa " nao encontrada.")
    } else {
        if !Ffcv_CriarNovaRemessa(tipoConta)
            return RP_Abort("Erro ao criar nova remessa.")
    }
    RP_RecordTiming(timings, "Convenio + remessa", stageStart, "convenio " convenioNum)
    Progress(60)

    stageStart := A_TickCount
    if !InserirContasNaRemessa(protocolContas, tipoConta, erros)
        return false
    RP_RecordTiming(timings, "Inserir contas FFCV", stageStart, totalContasFFCV " conta(s)")
    Progress(87)

    ; ── Fechamento ────────────────────────────────────────────
    if temDatas {
        stageStart := A_TickCount
        Notify("Iniciando diretamente a ponte FecharEXMLOLD Parte 1 / Entrega de Remessas...")
        if !Ffcv_PrepararEntregaPorProtocolo()
            return RP_Abort("Nao foi possivel sair da Manutencao e abrir Entrega de Remessas.")
        result := Ffcv_ConfirmarEntregaNaTela(dataEntrega, dataVenc, true)
        if !result["ok"]
            return RP_Abort(result["erro"])
        if !Ffcv_SairTelaEntregaPendente()
            return RP_Abort("A tela Entrega de Remessas nao fechou apos o protocolo.")
        RP_RecordTiming(timings, "Fechar remessa + datas", stageStart, "remessa " result["remessa"])
        Progress(94)
        stageStart := A_TickCount
        Notify("Gerando XML...")
        xml := TissXml_Gerar(result["remessa"])
        if !xml["ok"]
            return RP_Abort(xml["erro"])
        RP_RecordTiming(timings, "Gerar XML", stageStart)
        mapeamentoRemessas.Push(Map("remessa", result["remessa"], "protocolo", RP_JoinArray(protocolos, ", ")))
    } else if imprimirAposInserir {
        stageStart := A_TickCount
        criadaRemessa := ""
        Ffcv_ImprimirRelatorioAtendimentos(&criadaRemessa)
        RP_RecordTiming(timings, "Imprimir relatorio", stageStart)
        mapeamentoRemessas.Push(Map("remessa", criadaRemessa != "" ? criadaRemessa : "N/I", "protocolo", RP_JoinArray(protocolos, ", ")))
    }

    Progress(100)
    RP_RecordTiming(timings, "Total", totalStart, protocolos.Length " protocolo(s), " totalContasFFCV " conta(s)")
    gRunning := false
    Done(ErrosMensagem(erros, timings, mapeamentoRemessas))
}

RP_JoinArray(arr, sep := ", ") {
    res := ""
    for _, item in arr
        res .= (res = "" ? "" : sep) item
    return res
}

RP_OptionEnabled(params, key, defaultValue := false) {
    if !params.Has(key) || Trim(String(params[key])) = ""
        return defaultValue
    value := StrLower(Trim(String(params[key])))
    return !(value = "false" || value = "0" || value = "nao" || value = "não")
}

ErrosMensagem(erros, timings, mapeamentoRemessas := []) {
    report := "Remessa concluida com sucesso!`n`n" RP_FormatTimingReport(timings)
    if (mapeamentoRemessas.Length > 0) {
        report .= "`n`nRELAÇÃO DE REMESSAS CRIADAS:`n"
        for _, item in mapeamentoRemessas
            report .= "  • Remessa: " item["remessa"] " -> Protocolo: " item["protocolo"] "`n"
    }
    if (erros.Length > 0) {
        report .= "`nConcluido com " erros.Length " pendencia(s):`nPROTOCOLO | CONTA | ERRO`n"
        for _, e in erros
            report .= "  [[red]]" e["protocolo"] " | " e["conta"] " | " e["descricao"] "[[/red]]`n"
    }
    return report
}



ProcessarProtocolo(protocolo) {
    if !MV_EnsureWindowActive(MV_WIN_MOVDOC_BAIXA)
        return Map("ok", false, "erro", "MOV DOC Baixa nao ficou ativa.")
    if !MovDoc_SetProtocoloByClick(protocolo)
        return Map("ok", false, "erro", "Nao consegui focar/preencher o campo Protocolo.")
    if !MV_SendFunctionAndWait(MV_WIN_MOVDOC_BAIXA, "F8", MV_TIMEOUT_LOAD * 1000,
        , "consulta do protocolo " protocolo)
        return Map("ok", false, "F8 nao produziu transicao observavel para o protocolo " protocolo ".")
    if !MovDoc_WaitFirstGridLineReady(protocolo, &primeiraLinhaValida)
        return Map("ok", false, "erro", "Grid nao ficou legivel apos F8 para o protocolo " protocolo ".")
    linhas := MovDoc_LerGrid(protocolo, primeiraLinhaValida)
    if (linhas.Length = 0)
        return Map("ok", false, "erro", "Nenhuma conta/convenio coletada para o protocolo " protocolo ".")
    if !MovDoc_FinalizarBaixa()
        return Map("ok", false, "erro", "Falha ao salvar/baxar o protocolo " protocolo ".")
    return Map("ok", true, "linhas", linhas)
}


InserirContasNaRemessa(protocolContas, tipoConta, erros) {
    totalContas := ContarContas(protocolContas)
    contaIdx := okCount := erroCount := blockerCount := 0

    if !FfcvContaPopup_AbrirEConfigurar(tipoConta)
        return RP_Abort("Nao consegui abrir/configurar o popup de conta no FFCV.")

    for protocolo, contas in protocolContas {
        ThrowIfAppStopped()
        for _, contaObj in contas {
            ThrowIfAppStopped()
            contaIdx++
            Notify("Enviando conta " contaObj["conta"] " [prot. " protocolo "]")
            outcome := FfcvContaPopup_EnviarConta(contaObj["conta"])

            if (outcome["status"] = "modal") {
                err := outcome["erro"]
                if (err.Get("tipo", "") != "conta_ja_digitada") {
                    erros.Push(Map("protocolo", protocolo, "conta", contaObj["conta"], "descricao", err.Get("descricao", "?")))
                    erroCount++
                } else {
                    okCount++
                }

                if !Popup_DismissActiveModal()["ok"] || !MV_Poll(() => Popup_ContaVisible(), MV_TIMEOUT_ACOE)
                    return RP_Abort("Popup de erro nao fechado ou nao voltou apos conta " contaObj["conta"] ".")
            } else if (outcome["status"] = "ready") {
                okCount++
            } else {
                return RP_Abort("Estado incerto apos enviar conta " contaObj["conta"] ": " outcome["erro"])
            }
            Progress(60 + (contaIdx / totalContas) * 25)
        }
    }

    Notify("Resumo FFCV: ok=" okCount " erro=" erroCount " bloqueio=" blockerCount " total=" totalContas)
    if !FfcvContaPopup_Close(5000)
        return RP_Abort("Nao consegui fechar o popup de conta.")
    return true
}


; ════════════════════════════════════════════════════════════════
;  SHARED UI HELPERS
; ════════════════════════════════════════════════════════════════

RP_Abort(msg) {
    ; Delega para a canônica MV_Abort (MVSession.ahk).
    return MV_Abort(msg)
}
