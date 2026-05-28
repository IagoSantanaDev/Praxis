#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\_mv_control_probe.ahk

; TESTE 03 - FFCV / Manutenção de Remessas
; Preencha ClassNN e coordenadas Client conforme Window Spy.
; Campos/botões com atalho F6/F7/F8/F10 podem ficar como locate se preferir testar teclado no macro principal.

DO_ACTION := false
WIN_TITLE := "MV2000i - Faturamento - [WIN_PRINCIPAL - HOSPITAL SAO RAFAEL]"

controls := [
    Map("name", "FFCV_BTN_HABILITAR",     "class", "CLASSNN",  "x", "", "y", "", "action", "click"),
    Map("name", "FFCV_CAMPO_CONVENIO",    "class", "CLASSNN",  "x", "", "y", "", "action", "setText", "value", "930"),
    Map("name", "FFCV_AREA_REMESSAS",     "class", "CLASSNN",  "x", "", "y", "", "action", "focus"),
    Map("name", "FFCV_BTN_BUSCAR_REM",    "class", "CLASSNN",  "x", "", "y", "", "action", "click"),
    Map("name", "FFCV_CAMPO_NUM_REM",     "class", "CLASSNN",  "x", "", "y", "", "action", "setText", "value", "510794"),
    Map("name", "FFCV_BTN_CONFIRMAR_REM", "class", "CLASSNN",  "x", "", "y", "", "action", "click"),
    Map("name", "FFCV_BTN_NOVA_REM",      "class", "CLASSNN",  "x", "", "y", "", "action", "click"),
    Map("name", "FFCV_CAMPO_DATA_REM",    "class", "CLASSNN",  "x", "", "y", "", "action", "setText", "value", "18/05/2026"),
    Map("name", "FFCV_CAMPO_TIPO",        "class", "CLASSNN",  "x", "", "y", "", "action", "setText", "value", "3"),
    Map("name", "FFCV_BTN_SALVAR_REM",    "class", "CLASSNN",  "x", "", "y", "", "action", "click"),
    Map("name", "FFCV_BTN_ADICIONAR",     "class", "Button10", "x", "", "y", "", "action", "locate"),
    Map("name", "FFCV_BTN_FINALIZAR",     "class", "Button3",  "x", "", "y", "", "action", "locate"),
    Map("name", "FFCV_BTN_ABRIR_DATAS",   "class", "Button6",  "x", "", "y", "", "action", "locate")
]

MV_Test_RunSuite("FFCV - manutenção de remessas", WIN_TITLE, controls, DO_ACTION)
