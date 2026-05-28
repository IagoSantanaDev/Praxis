#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\_mv_control_probe.ahk

; TESTE 01 - Login Identificação por teclado
; Objetivo: validar o fluxo atual recomendado para o MV:
;   campo Usuário já focado → digitar usuário → Tab → digitar senha → Enter.
;
; DO_ACTION := false apenas confirma se a janela de login existe.
; DO_ACTION := true envia os valores abaixo. Use somente com usuário/senha de teste.

DO_ACTION := false
WIN_TITLE := "Identificação ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"
TEST_USER := "TESTE_USUARIO"
TEST_PASS := "TESTE_SENHA"
IMG_ERRO_ICONE := MV_Test_ImagePath("Erro_Icone.png")

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
    if MV_Test_ImageVisible(IMG_ERRO_ICONE)
        report .= "⚠️ Popup de erro/login detectado via Erro_Icone.png.`n"
    else
        report .= "ℹ️ Popup de erro não detectado no intervalo curto.`n"
}

report .= "`nFallback ainda possível: HWND + ClassNN + Client quando o foco inicial não vier correto.`n"
MV_Test_ShowReport(report)
