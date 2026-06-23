; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug

; ════════════════════════════════════════════════════════════════
;  FECHAR XML — ORQUESTRAÇÃO DE FECHAMENTO DE XML TISS
; ════════════════════════════════════════════════════════════════
;
; Orquestra o fluxo de fechamento de XML TISS após a geração
; e envio do lote. Coordena RemessaProtocolo, TissXmlScreen
; e FfcvScreen para completar a remessa.
;
; Screens orquestrados (futuros):
;   - TissXmlScreen    — espera query estar pronta, salva XML
;   - FfcvScreen       — confirma entrega da remessa
;
; ════════════════════════════════════════════════════════════════

; ── Includes de screens ────────────────────────────────────────
#Include ..\..\..\lib\globals\mv\screens\TissXmlScreen.ahk
#Include ..\..\..\lib\globals\mv\screens\FfcvScreen.ahk

; ── Includes de parsers e registry ─────────────────────────────
#Include FecharXmlParsers.ahk
; FecharXmlRegistry.ahk já é carregado via ScriptRegistry.ahk →
; FecharXmlRegistry.ahk → #Include FecharXml.ahk — não incluir novamente
; para evitar ciclo FecharXml ↔ FecharXmlRegistry.

; ════════════════════════════════════════════════════════════════
;  Entry point (Dispatcher bridge)
; ════════════════════════════════════════════════════════════════

/*
    RunFecharXML(params)
    Bridge entry point chamado pelo Dispatcher.
    Delega para FXML_Run() com conversao de params.

    Parâmetros:
        params.remessas         — números das remessas (string csv)
        params.data_entrega     — data de entrega
        params.data_vencimento   — data de vencimento

    Retorna:
        true  — fluxo concluído com sucesso
        false — fluxo falhou ou requer intervenção
*/
RunFecharXML(params) {
    return FXML_Run(params)
}

; ════════════════════════════════════════════════════════════════
;  Funções públicas
; ════════════════════════════════════════════════════════════════

/*
    FXML_Run(params)
    Orquestra o fluxo de fechamento de XML TISS.
    Placeholder — lógica de orquestração será implementada.

    Parâmetros (placeholder):
        params.loteId        — ID do lote gerado
        params.xmlPath       — caminho do XML salvo
        params.envioConfirmado — se o envio já foi confirmado

    Retorna:
        true  — fluxo concluído com sucesso
        false — fluxo falhou ou requer intervenção
*/
FXML_Run(params) {
    global
    ; Placeholder — lógica de orquestração será implementada
    ;   1. Validar que TissXmlScreen gerou XML
    ;   2. Confirmar envio na FfcvScreen
    ;   3. Persistir estado em FecharXmlRegistry
    ;   4. Retornar status consolidado
    SendToUI(Map("type", "log", "message", "FecharXml: orchestrator placeholder chamado."))
    return false
}
