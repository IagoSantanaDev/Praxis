#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\_mv_control_probe.ahk

; TESTE 01 - Login Identificação por teclado
; Objetivo: validar o fluxo atual recomendado para o MV:
;   campo Usuário já focado → digitar usuário → Tab → digitar senha → Enter.
;
; DO_ACTION := false apenas confirma se a janela de login existe.
; DO_ACTION := true envia os valores abaixo. Use somente com usuário/senha de teste.

DO_ACTION := true
WIN_TITLE := "Identificação ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"
WIN_LOGIN_ERROR := "Mensagem do MV2000 ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"
TEST_USER := "iagosantana"
TEST_PASS := "iago##hsr16"

report := "SUÍTE: Login - teclado`n"
        . "Janela: " WIN_TITLE "`n"
        . "Modo ação: " (DO_ACTION ? "SIM" : "NÃO - apenas detectar") "`n`n"

if !WinExist(WIN_TITLE) {
    report .= "❌ Janela de login não encontrada.`n"
    report .= "Abra o login do MV e rode de novo.`n"
    MV_Test_ShowReport(report)
    ExitApp
}

WinActivate WIN_TITLE
WinWaitActive WIN_TITLE,, 2
report .= "✅ Janela de login encontrada e ativada.`n"
report .= "ℹ️ Fluxo esperado: Usuário já focado → texto → Tab → senha → Enter.`n"

if DO_ACTION {
    SendText TEST_USER
    Sleep 80
    Send "{Tab}"
    Sleep 80
    SendText TEST_PASS
    Sleep 80
    Send "{Enter}"
    report .= "✅ Credenciais de teste enviadas por teclado.`n"

    Sleep 700
    if WinExist(WIN_LOGIN_ERROR)
        report .= "⚠️ Popup de erro/login detectado por título: " WIN_LOGIN_ERROR "`n"
    else
        report .= "ℹ️ Popup de erro não detectado por título no intervalo curto.`n"
}

report .= "`nFallback de imagem removido: erro de login deve ser detectado por título/modal.`n"
MV_Test_ShowReport(report)
