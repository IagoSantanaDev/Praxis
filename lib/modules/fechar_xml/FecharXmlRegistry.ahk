; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug

; ════════════════════════════════════════════════════════════════
;  FECHAR XML — REGISTRY DE METADADOS DO MÓDULO
; ════════════════════════════════════════════════════════════════
;
; Centraliza metadados do módulo FecharXml. Fornece FXML_Registry()
; como ponto único de acesso para inspeção estática.
;
; Include do módulo principal (padrão RPRegistry → RemessaProtocolo)
; FecharXml.ahk define RunFecharXML() usado pelo Dispatcher.
; Ciclo FecharXml ↔ FecharXmlRegistry é seguro: AHK v2 protege
; contra re-entrada de #Include via double-load guard.
;
; Screens orquestrados:
;   - TissXmlScreen         — globals/mv/screens/TissXmlScreen.ahk
;   - FfcvScreen            — globals/mv/screens/FfcvScreen.ahk
;
; ════════════════════════════════════════════════════════════════

; Include do módulo principal (padrão RPRegistry → RemessaProtocolo)
#Include FecharXml.ahk

; ════════════════════════════════════════════════════════════════
;  Funções públicas
; ════════════════════════════════════════════════════════════════

/*
    FXML_Registry()
    Retorna metadados estáticos do módulo FecharXml.

    Auditoria 2026-06-27 (M4): removidos gFXMLScreenCounters /
    gFXMLScreenLastRun / gFXMLFlowState (declarados mas nunca
    incrementados). Contadores de runtime foram descartados porque
    FXML_Run é placeholder e nao instrumenta os screens.

    Retorna:
        Map com as seguintes chaves:
            module        — nome do módulo ("FecharXml")
            version       — versão do módulo
            screens       — Map[nome] => caminho relativo do .ahk
            dependencies  — array de módulos dependentes
*/
FXML_Registry() {
    return Map(
        "module",       "FecharXml",
        "version",      "1.0.0",
        "screens",      Map(
            "TissXmlScreen", "globals\mv\screens\TissXmlScreen.ahk",
            "FfcvScreen",    "globals\mv\screens\FfcvScreen.ahk"
        ),
        "dependencies", ["TissXmlScreen", "FfcvScreen"]
    )
}
