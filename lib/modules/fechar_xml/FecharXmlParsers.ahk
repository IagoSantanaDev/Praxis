; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug
; ════════════════════════════════════════════════════════════════
;  FECHAR XML — PARSERS DE RESPOSTA E DADOS DO MÓDULO
; ════════════════════════════════════════════════════════════════
;
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
;
; ════════════════════════════════════════════════════════════════

; ── Parsers públicos ───────────────────────────────────────────

/*
    FXML_ParseXmlSaveResult(raw)
    Parseia resultado bruto da operação de salvar XML do TissXmlScreen.

    Parâmetros:
        raw — valor retornado por TissXmlScreen

    Retorna:
        Map com:
            success  — true se XML foi salvo com sucesso
            xmlPath  — caminho do arquivo XML (vazio se falhou)
            error    — mensagem de erro descritiva (vazio se sucesso)
*/
FXML_ParseXmlSaveResult(raw) {
    ; TODO: implementar parse real quando TissXmlScreen gain logic
    return Map(
        "success", false,
        "xmlPath", "",
        "error",   "FXML_ParseXmlSaveResult: placeholder — implementar com lógica real"
    )
}

/*
    FXML_ParseFfcvConfirmResult(raw)
    Parseia resultado bruto da confirmação de entrega na FfcvScreen.

    Parâmetros:
        raw — valor retornado por FfcvScreen (Ffcv_ConfirmarEntregaRemessa)

    Retorna:
        Map com:
            success    — true se confirmação foi bem-sucedida
            remessaId  — ID da remessa confirmada (vazio se falhou)
            error      — mensagem de erro descritiva (vazio se sucesso)
*/
FXML_ParseFfcvConfirmResult(raw) {
    ; TODO: implementar parse real quando FfcvScreen gain more logic
    return Map(
        "success",   false,
        "remessaId", "",
        "error",     "FXML_ParseFfcvConfirmResult: placeholder — implementar com lógica real"
    )
}



/*
    FXML_ValidateParams(params)
    Valida parâmetros de entrada para o fluxo FXML_Run.

    Parâmetros:
        params — Map com parâmetros do fluxo

    Retorna:
        Map com:
            valid  — true se parâmetros são válidos
            errors — array de mensagens de erro (vazio se válido)
*/
FXML_ValidateParams(params) {
    errors := []
    if !IsObject(params) {
        errors.Push("params deve ser um objeto Map")
        return Map("valid", false, "errors", errors)
    }
    ; TODO: adicionar validações específicas quando params for implementado
    return Map("valid", errors.Length == 0, "errors", errors)
}

/*
    FXML_ParseFlowResult(results)
    Agrega resultados de múltiplos parsers em resultado consolidado.

    Parâmetros:
        results — Map com resultados parciais de cada screen

    Retorna:
        Map com:
            overallSuccess — true se todos os steps succeeded
            consolidated   — Map com xmlPath, remessaId, protocolo
            errors         — array de erros encontrados
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
