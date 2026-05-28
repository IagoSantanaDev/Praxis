; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\_mv_control_probe.ahk

; TESTE 06 - XML / Monitoração TISS e XML gerado
; Rode primeiro com XML gerado fechado para testar a tela TISS.
; Depois abra/gere a tela XML gerado e rode 07_xml_gerado.ahk.

DO_ACTION := false
WIN_TITLE := "Monitoração de Faturamento - TISS"

controls := [
    Map("name", "XML_CAMPO_REMESSA",   "class", "CLASSNN", "x", "", "y", "",  "action", "setText", "value", "510794"),
    Map("name", "XML_BTN_BUSCAR",      "class", "CLASSNN", "x", "", "y", "",  "action", "click"),
    Map("name", "XML_BTN_FATURAMENTO", "class", "Button7", "x", 55, "y", 458, "action", "locate"),
    Map("name", "XML_BTN_SAIR_TELA",   "class", "CLASSNN", "x", "", "y", "",  "action", "click")
]

MV_Test_RunSuite("XML - Monitoração TISS", WIN_TITLE, controls, DO_ACTION)
