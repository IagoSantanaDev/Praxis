#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\_mv_control_probe.ahk

; TESTE 07 - Tela XML gerado
; Abra a tela "XML gerado" antes de rodar.

DO_ACTION := false
WIN_TITLE := "MV2000i - Faturamento - [WIN_PRINCIPAL]"

controls := [
    Map("name", "XML_FORM_CAMPO_PATH", "class", "Edit1",   "x", 267, "y", 467, "action", "setText", "value", "C:\\XML\\510794.xml"),
    Map("name", "XML_FORM_BTN_SALVAR", "class", "Button4", "x", 623, "y", 471, "action", "locate"),
    Map("name", "XML_BTN_NAO",         "class", "Button2", "x", "",  "y", "",  "action", "locate"),
    Map("name", "XML_FORM_BTN_VOLTAR", "class", "Button7", "x", 731, "y", 470, "action", "locate")
]

MV_Test_RunSuite("XML gerado - caminho/salvar/voltar", WIN_TITLE, controls, DO_ACTION)
