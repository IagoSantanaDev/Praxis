; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug

; Orquestra o fluxo de fechamento de XML TISS após a geração
; e envio do lote. Coordena RemessaProtocolo, TissXmlScreen
; e FfcvScreen para completar a remessa.
;
; Screens orquestrados (futuros):
;   - TissXmlScreen    — espera query estar pronta, salva XML
;   - FfcvScreen       — confirma entrega da remessa

#Include ..\..\..\lib\globals\mv\screens\TissXmlScreen.ahk
#Include ..\..\..\lib\globals\mv\screens\FfcvScreen.ahk

#Include FecharXmlParsers.ahk
; FecharXmlRegistry.ahk é apenas o shim de compatibilidade do módulo.
; O Dispatcher carrega este arquivo diretamente; não incluir o registry
; aqui para evitar ciclo FecharXml ↔ FecharXmlRegistry.

RunFecharXML(params) {
    validation := FXML_ValidateParams(params)
    if !validation["valid"] {
        detail := ""
        for _, errorText in validation["errors"]
            detail .= (detail = "" ? "" : "; ") errorText
        return MV_Abort("Parametros invalidos para fechar XML: " detail, true)
    }

    remessas := ParseListaCsv(params["remessas"])
    dataEntrega := Trim(String(params["data_entrega"]))
    dataVenc := Trim(String(params["data_vencimento"]))
    fechar := MV_OptionEnabled(params, "fechar", true)
    gerarXml := MV_OptionEnabled(params, "gerar_xml", true)
    results := []

    if !MV_EnsureFFCV()
        return MV_Abort("FFCV nao ficou ativa para executar FecharEXML.", true)

    ; Fluxo independente: FecharEXML.ahk. A impressao inicial e opcional
    ; porque algumas telas do FFCV nao exibem Button9.
    if (fechar && !FXML_ImprimirRelatorioInicial())
        return MV_Abort("Nao foi possivel concluir a impressao inicial de atendimentos.", true)

    if fechar {
        for index, remessa in remessas {
            ThrowIfAppStopped()
            if !Ffcv_AbrirTelaEntregaRemessas()
                return MV_Abort("Nao foi possivel abrir Entrega de Remessas para " remessa ".", true)

            Notify("Fechando remessa " remessa " (" index "/" remessas.Length ")...")
            entrega := Ffcv_ConfirmarEntregaNaTela(dataEntrega, dataVenc)
            if !entrega["ok"]
                return MV_Abort(entrega["erro"], true)

            results.Push(Map(
                "success", true,
                "remessaId", entrega["remessa"],
                "xmlPath", ""
            ))

            if !Ffcv_SairTelaEntregaPendente()
                return MV_Abort("A tela Entrega de Remessas nao fechou apos a remessa " remessa ".", true)
        }
    }

    if gerarXml {
        for _, remessa in remessas {
            ThrowIfAppStopped()
            Notify("Gerando XML da remessa " remessa "...")
            xml := TissXml_Gerar(remessa)
            if !xml["ok"]
                return MV_Abort(xml["erro"], true)

            results.Push(Map(
                "success", true,
                "xmlPath", xml["path"],
                "remessaId", remessa
            ))
        }
    }

    summary := FXML_ParseFlowResult(results)
    Done("FecharEXML concluído: " remessas.Length " remessa(s).")
    return summary
}

FXML_ImprimirRelatorioInicial() {
    if !MV_FirstControlByClass(MV_WIN_FFCV_ANY, "Button9")
        return true

    try {
        MV_PrintDeliveryReport(
            "Impressão inicial do relatório em andamento...",
            MV_WIN_FFCV_ANY,
            "Button9")
        return true
    } catch as err {
        Notify(err.Message)
        return false
    }
}
