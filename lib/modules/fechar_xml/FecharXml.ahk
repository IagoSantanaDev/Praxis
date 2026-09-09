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
; FecharXmlRegistry.ahk já é carregado via ScriptRegistry.ahk →
; FecharXmlRegistry.ahk → #Include FecharXml.ahk — não incluir novamente
; para evitar ciclo FecharXml ↔ FecharXmlRegistry.

RunFecharXML(params) {
    global
    ; Placeholder — lógica de orquestração será implementada
    ;   1. Validar que TissXmlScreen gerou XML
    ;   2. Confirmar envio na FfcvScreen
    ;   3. Persistir estado em FecharXmlRegistry
    ;   4. Retornar status consolidado
    SendToUI(Map("type", "log", "message", "FecharXml: orchestrator placeholder chamado."))
    return false
}
