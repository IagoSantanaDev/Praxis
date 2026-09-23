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

RunRemessaProtocolo(params) {
    global gRunning

    protocolos   := ParseListaCsv(params["protocolos"])
    tipoConta    := params["tipo_conta"]
    dataEntrega  := params["data_entrega"]
    dataVenc     := params["data_vencimento"]
    numRemessa   := Trim(params["num_remessa"])
    imprimirAposInserir := MV_OptionEnabled(params, "imprimir_apos_inserir", true)
    umProtocoloUmaRemessa := MV_OptionEnabled(params, "um_protocolo_uma_remessa", false)
    temDatas     := (dataEntrega != "" && dataVenc != "")

    if (protocolos.Length = 0)
        return MV_Abort("Informe ao menos um protocolo.")
    if (umProtocoloUmaRemessa && numRemessa != "")
        return MV_Abort("No fluxo 'Um Protocolo = Uma Remessa' a remessa existente deve ficar vazia.")

    linhas := [], erros := [], timings := [], mapeamentoRemessas := [], remessasParaEntrega := []
    totalStart := stageStart := A_TickCount

    ; ── FLUXO: UM PROTOCOLO = UMA REMESSA ─────────────────────────
    if umProtocoloUmaRemessa {
        Notify("Iniciando fluxo: Um Protocolo = Uma Remessa...")

        for idx, protocolo in protocolos {
            ThrowIfAppStopped()
            pStart := A_TickCount
            Notify("Processando protocolo " protocolo " (" idx "/" protocolos.Length ") no MOV DOC...")

            if !MV_EnsureMovDoc() || !MovDoc_AbrirTelaBaixa()
                return MV_Abort("Nao foi possivel acessar o MOV DOC / abrir a tela Baixa para o protocolo " protocolo ".")

            result := ProcessarProtocolo(protocolo)
            if !result["ok"]
                return MV_Abort(result["erro"])

            linhasProtocolo := result["linhas"]
            convenioNum := RP_ConvenioMajoritario(linhasProtocolo)
            if (convenioNum = "")
                return MV_Abort("Convenio nao identificado no MOV DOC para o protocolo " protocolo ".")

            protocolContas := RP_FiltrarContasPorConvenio(linhasProtocolo, convenioNum, erros)
            totalContasFFCV := ContarContas(protocolContas)

            Notify("Abrindo FFCV para protocolo " protocolo " (convenio " convenioNum ")...")
            if !MV_EnsureFFCV() || !Ffcv_AbrirManutencaoRemessa()
                return MV_Abort("Nao foi possivel acessar o FFCV / abrir Manutencao de Remessa.")

            if !Ffcv_CarregarConvenio(convenioNum)
                return MV_Abort("Nao consegui carregar o convenio " convenioNum " no FFCV.")
            Ffcv_PosicionarAreaRemessas()

            if !Ffcv_CriarNovaRemessa(tipoConta)
                return MV_Abort("Erro ao criar nova remessa para o protocolo " protocolo ".")

            if !InserirContasNaRemessa(protocolContas, tipoConta, erros)
                return false

            criadaRemessa := ""

            if temDatas {
                ; No modo um-para-um, o relatório só identifica a remessa criada.
                Notify("Abrindo relatório apenas para capturar a remessa do protocolo " protocolo "...")
                if !Ffcv_ImprimirRelatorioAtendimentos(&criadaRemessa, false)
                    return MV_Abort("Nao foi possivel abrir o relatorio para OCR da remessa do protocolo " protocolo ".")
                if (criadaRemessa = "")
                    return MV_Abort("Nao foi possivel capturar o numero da remessa do protocolo " protocolo ".")
                remessasParaEntrega.Push(criadaRemessa)
            } else if imprimirAposInserir {
                ; Sem datas, imprime o relatório sem OCR para capturar a remessa.
                Notify("Imprimindo relatorio de atendimentos do protocolo " protocolo "...")
                if !Ffcv_ImprimirRelatorioAtendimentos()
                    return MV_Abort("Nao foi possivel imprimir o relatorio do protocolo " protocolo ".")
            }

            if (criadaRemessa != "")
                mapeamentoRemessas.Push(Map("remessa", criadaRemessa, "protocolo", protocolo))
            else
                mapeamentoRemessas.Push(Map("remessa", "N/I", "protocolo", protocolo))

            Notify("Concluido ciclo do protocolo " protocolo ": Remessa " criadaRemessa)
            Ffcv_ReiniciarManutencaoRemessa()
            Progress((idx / protocolos.Length) * 100)
        }

        if temDatas {
            Notify("Abrindo Entrega de Remessas via Alt+LE para fechar as remessas...")
            for _, remessa in remessasParaEntrega {
                ThrowIfAppStopped()
                if !Ffcv_AbrirTelaEntregaRemessas()
                    return MV_Abort("Nao foi possivel abrir Entrega de Remessas para a remessa " remessa ".")

                entrega := Ffcv_ConfirmarEntregaNaTela(dataEntrega, dataVenc, false, true, remessa)
                if !entrega["ok"]
                    return MV_Abort(entrega["erro"])
                if !Ffcv_SairTelaEntregaPendente()
                    return MV_Abort("A tela Entrega de Remessas nao fechou apos a remessa " remessa ".")
            }

            for _, remessa in remessasParaEntrega {
                Notify("Gerando XML TISS da remessa " remessa "...")
                xml := TissXml_Gerar(remessa)
                if !xml["ok"]
                    return MV_Abort(xml["erro"])
            }
        }

        RP_RecordTiming(timings, "Um Protocolo = Uma Remessa Total", totalStart, protocolos.Length " protocolo(s) processado(s)")
        gRunning := false
        Done(ErrosMensagem(erros, timings, mapeamentoRemessas))
        return true
    }

    ; ── FLUXO LEGADO: VÁRIOS PROTOCOLOS = UMA REMESSA ─────────────
    Notify("Garantindo MOV DOC...")
    if !MV_EnsureMovDoc() || !MovDoc_AbrirTelaBaixa()
        return MV_Abort("Nao foi possivel acessar o MOV DOC / abrir a tela Baixa.")
    RP_RecordTiming(timings, "Abrir MOV DOC e tela Baixa", stageStart)
    Progress(5)

    stageStart := A_TickCount
    for idx, protocolo in protocolos {
        ThrowIfAppStopped()
        pStart := A_TickCount
        Notify("Processando protocolo " protocolo " (" idx "/" protocolos.Length ")")
        result := ProcessarProtocolo(protocolo)
        if !result["ok"]
            return MV_Abort(result["erro"])
        for _, linha in result["linhas"]
            linhas.Push(linha)
        Notify("⏱ MOV DOC " protocolo ": " RP_FormatDuration(A_TickCount - pStart) " | " result["linhas"].Length " linha(s)")
        Progress(5 + (idx / protocolos.Length) * 40)
    }
    RP_RecordTiming(timings, "MOV DOC", stageStart, protocolos.Length " protocolo(s), " linhas.Length " linha(s)")

    convenioNum := RP_ConvenioMajoritario(linhas)
    if (convenioNum = "")
        return MV_Abort("Convenio nao identificado no MOV DOC.")
    protocolContas := RP_FiltrarContasPorConvenio(linhas, convenioNum, erros)
    totalContasFFCV := ContarContas(protocolContas)

    ; ── FFCV ──────────────────────────────────────────────────
    stageStart := A_TickCount
    Notify("Garantindo FFCV...")
    if !MV_EnsureFFCV() || !Ffcv_AbrirManutencaoRemessa()
        return MV_Abort("Nao foi possivel acessar o FFCV / abrir Manutencao de Remessa.")
    RP_RecordTiming(timings, "Abrir FFCV", stageStart)
    Progress(50)

    stageStart := A_TickCount
    if !Ffcv_CarregarConvenio(convenioNum)
        return MV_Abort("Nao consegui carregar o convenio " convenioNum " no FFCV.")
    Ffcv_PosicionarAreaRemessas()
    if (numRemessa != "") {
        if !Ffcv_SelecionarRemessaExistente(numRemessa)
            return MV_Abort("Remessa " numRemessa " nao encontrada.")
    } else {
        if !Ffcv_CriarNovaRemessa(tipoConta)
            return MV_Abort("Erro ao criar nova remessa.")
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
            return MV_Abort("Nao foi possivel sair da Manutencao e abrir Entrega de Remessas.")

        if (numRemessa != "") {
            result := Ffcv_ConfirmarEntregaNaTela(dataEntrega, dataVenc, false, false, numRemessa)
        } else {
            result := Ffcv_ConfirmarEntregaNaTela(dataEntrega, dataVenc, true, false)
        }

        if !result["ok"]
            return MV_Abort(result["erro"])
        if !Ffcv_SairTelaEntregaPendente()
            return MV_Abort("A tela Entrega de Remessas nao fechou apos o protocolo.")
        RP_RecordTiming(timings, "Fechar remessa + datas", stageStart, "remessa " result["remessa"])
        Progress(94)
        stageStart := A_TickCount
        Notify("Gerando XML...")
        xml := TissXml_Gerar(result["remessa"])
        if !xml["ok"]
            return MV_Abort(xml["erro"])
        RP_RecordTiming(timings, "Gerar XML", stageStart)
        mapeamentoRemessas.Push(Map("remessa", result["remessa"], "protocolo", MV_JoinArray(protocolos, ", ")))
    } else if imprimirAposInserir {
        stageStart := A_TickCount
        Ffcv_ImprimirRelatorioAtendimentos()
        RP_RecordTiming(timings, "Imprimir relatorio", stageStart)
        mapeamentoRemessas.Push(Map("remessa", "N/I", "protocolo", MV_JoinArray(protocolos, ", ")))
    }

    Progress(100)
    RP_RecordTiming(timings, "Total", totalStart, protocolos.Length " protocolo(s), " totalContasFFCV " conta(s)")
    gRunning := false
    Done(ErrosMensagem(erros, timings, mapeamentoRemessas))
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



; Fina, chama a canônica compartilhada MovDoc_BaixarProtocolo
; (globals/mv/screens/MovDocScreen.ahk — também usada por Protocolar.ahk
; para baixar protocolos pendentes/de correção detectados em popup).
ProcessarProtocolo(protocolo) {
    return MovDoc_BaixarProtocolo(protocolo)
}


InserirContasNaRemessa(protocolContas, tipoConta, erros) {
    totalContas := ContarContas(protocolContas)
    contaIdx := okCount := erroCount := blockerCount := 0

    if !FfcvContaPopup_AbrirEConfigurar(tipoConta)
        return MV_Abort("Nao consegui abrir/configurar o popup de conta no FFCV.")

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
                    return MV_Abort("Popup de erro nao fechado ou nao voltou apos conta " contaObj["conta"] ".")
            } else if (outcome["status"] = "ready") {
                okCount++
            } else {
                return MV_Abort("Estado incerto apos enviar conta " contaObj["conta"] ": " outcome["erro"])
            }
            Progress(60 + (contaIdx / totalContas) * 25)
        }
    }

    Notify("Resumo FFCV: ok=" okCount " erro=" erroCount " bloqueio=" blockerCount " total=" totalContas)
    if !FfcvContaPopup_Close(MV_TRANSITION_TIMEOUT_MS)
        return MV_Abort("Nao consegui fechar o popup de conta.")
    return true
}


; ════════════════════════════════════════════════════════════════
;  SHARED UI HELPERS
; ════════════════════════════════════════════════════════════════

