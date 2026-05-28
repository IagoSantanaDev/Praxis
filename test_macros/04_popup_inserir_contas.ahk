; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\_mv_control_probe.ahk

; TESTE 04 - Popup de envio/inserção de contas
; Abra o popup pelo botão "1 - Inserir Conta" antes de rodar.
; Preencha título, ClassNN e coordenadas Client conforme Window Spy.

DO_ACTION := false
WIN_TITLE := "TÍTULO POPUP ENVIO DE CONTA" ; TODO: substituir pelo título real do popup

controls := [
    Map("name", "POPUP_DROPDOWN_1",  "class", "CLASSNN", "x", "", "y", "", "action", "locate"),
    Map("name", "POPUP_DROPDOWN_2",  "class", "CLASSNN", "x", "", "y", "", "action", "locate"),
    Map("name", "POPUP_CAMPO_CONTA", "class", "CLASSNN", "x", "", "y", "", "action", "setText", "value", "12960859"),
    Map("name", "POPUP_BTN_OK",      "class", "CLASSNN", "x", "", "y", "", "action", "click")
]

MV_Test_RunSuite("Popup - inserir contas na remessa", WIN_TITLE, controls, DO_ACTION)
