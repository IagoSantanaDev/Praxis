; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\_mv_control_probe.ahk

; TESTE 05 - Entrega de Remessas / Datas
; Abra a tela "Entrega de Remessas" antes de rodar.
; Preencha os campos pendentes com ClassNN + coordenada Client.

DO_ACTION := false
WIN_TITLE := "Cadastro: Faturas e Remessas"

controls := [
    Map("name", "DATAS_CAMPO_REMESSA",    "class", "Edit1",    "x", "",  "y", "",  "action", "locate"),
    Map("name", "DATAS_CAMPO_ENTREGA",    "class", "CLASSNN",  "x", "",  "y", "",  "action", "setText", "value", "18/05/2026"),
    Map("name", "DATAS_CAMPO_VENCIMENTO", "class", "CLASSNN",  "x", "",  "y", "",  "action", "setText", "value", "22/05/2026"),
    Map("name", "DATAS_CHECKBOX",         "class", "Button3",  "x", 541, "y", 242, "action", "locate"),
    Map("name", "DATAS_BTN_CONFIRMAR",    "class", "Button10", "x", 30,  "y", 426, "action", "locate"),
    Map("name", "DATAS_BTN_VOLTAR",       "class", "Button7",  "x", "",  "y", "",  "action", "locate")
]

MV_Test_RunSuite("Entrega de Remessas - datas", WIN_TITLE, controls, DO_ACTION)
