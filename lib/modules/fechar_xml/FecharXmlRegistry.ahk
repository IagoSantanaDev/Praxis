; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug

; ════════════════════════════════════════════════════════════════
;  FECHAR XML — REGISTRY DO MÓDULO
; ════════════════════════════════════════════════════════════════
;
; Padrão consistente com RPRegistry e ProtocolarRegistry: shim puro
; que inclui o módulo principal. FecharXml.ahk define RunFecharXML()
; usado pelo Dispatcher; o catálogo de scripts não inclui este registry.
;
; Consolidação 2026-09-09: FXML_Registry() removida (órfã — nunca
; chamada por ScriptRegistry/Dispatcher; o catálogo canônico de
; scripts é gScripts em lib/app/ScriptRegistry.ahk).
;
; Screens orquestrados:
;   - TissXmlScreen         — globals/mv/screens/TissXmlScreen.ahk
;   - FfcvScreen            — globals/mv/screens/FfcvScreen.ahk
;
; ════════════════════════════════════════════════════════════════

#Include FecharXml.ahk