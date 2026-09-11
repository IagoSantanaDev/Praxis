; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug
#Include %A_LineFile%\..\..\..\globals\mv\ParseUtils.ahk
; Parsers para extração e validação de dados provenientes dos
; screens orquestrados (TissXmlScreen, FfcvScreen).
; Centraliza transformação de dados brutos em estruturas tipadas.
;
; Screens fornecedores:
;   - TissXmlScreen    — globals/mv/screens/TissXmlScreen.ahk
;   - FfcvScreen       — globals/mv/screens/FfcvScreen.ahk
;
; Observabilidade:
;   - Logs de parse por tipo de dado
;   - Erros específicos por falha de parse

/*
    FXML_ParseXmlSaveResult(raw)
    Parseia resultado bruto da operação de salvar XML do TissXmlScreen.
*/
FXML_ParseXmlSaveResult(raw) {
    ; Placeholder mantido até a fatia S05 definir o payload bruto do TissXmlScreen.
    return Map(
        "success", false,
        "xmlPath", "",
        "error",   "FXML_ParseXmlSaveResult: placeholder — implementar com lógica real"
    )
}

/*
    FXML_ParseFfcvConfirmResult(raw)
    Parseia resultado bruto da confirmação de entrega na FfcvScreen.
*/
FXML_ParseFfcvConfirmResult(raw) {
    ; Placeholder mantido até a fatia S05 definir o payload bruto do FfcvScreen.
    return Map(
        "success",   false,
        "remessaId", "",
        "error",     "FXML_ParseFfcvConfirmResult: placeholder — implementar com lógica real"
    )
}



/*
    FXML_ValidateParams(params)
    Valida parâmetros de entrada para o fluxo FXML_Run.
*/
FXML_ValidateParams(params) {
    errors := []
    if !(params is Map) {
        errors.Push("params deve ser um Map")
        return Map("valid", false, "errors", errors)
    }

    if !params.Has("remessas") || Trim(String(params["remessas"])) = ""
        errors.Push("Parametro obrigatorio ausente: remessas")

    fechar := FXML_OptionEnabled(params, "fechar", true)
    gerarXml := FXML_OptionEnabled(params, "gerar_xml", true)
    if !fechar && !gerarXml
        errors.Push("Marque Fechar Remessa ou Gerar XML.")

    if fechar {
        for key in ["data_entrega", "data_vencimento"] {
            if !params.Has(key) || Trim(String(params[key])) = ""
                errors.Push("Parametro obrigatorio ausente: " key)
        }
    }

    return Map("valid", errors.Length = 0, "errors", errors)
}

FXML_OptionEnabled(params, key, defaultValue := true) {
    if !params.Has(key) || Trim(String(params[key])) = ""
        return defaultValue

    value := StrLower(Trim(String(params[key])))
    return !(value = "nao" || value = "não" || value = "false" || value = "0")

}

/*
    FXML_ParseFlowResult(results)
    Agrega resultados de múltiplos parsers em resultado consolidado.
*/
FXML_ParseFlowResult(results) {
    errors := []
    consolidated := Map(
        "xmlPath",   "",
        "remessaId", "",
        "protocolo", ""
    )
    overallSuccess := true

    for step, result in results {
        if result.Has("success") && !result["success"] {
            overallSuccess := false
            if result.Has("error") && result["error"] != "" {
                errors.Push(result["error"])
            }
        } else {
            if result.Has("xmlPath") && result["xmlPath"] != "" {
                consolidated["xmlPath"] := result["xmlPath"]
            }
            if result.Has("remessaId") && result["remessaId"] != "" {
                consolidated["remessaId"] := result["remessaId"]
            }
            if result.Has("protocolo") && result["protocolo"] != "" {
                consolidated["protocolo"] := result["protocolo"]
            }
        }
    }

    return Map(
        "overallSuccess", overallSuccess,
        "consolidated",   consolidated,
        "errors",         errors
    )
}
