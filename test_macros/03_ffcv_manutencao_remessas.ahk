; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\_mv_control_probe.ahk

; TESTE 03 - FFCV / Manutenção de Remessa
;
; Decisão: este fluxo usa teclado/atalhos de propósito.
; Os campos da remessa são Oracle Forms com EditN variável: a numeração muda conforme
; quantidade de remessas do convênio e estado da tela. Não converter esses campos para
; ClassNN fixo sem nova validação, porque pode ficar menos confiável que F7/F8/F6/F10.
;
; Fluxo testado:
; 1) Detectar FFCV por título amplo.
; 2) Se não estiver aberto e DO_OPEN=true, abrir FFCV.
; 3) Se aparecer login e DO_LOGIN=true, enviar usuário → Tab → senha → Enter.
; 4) Navegar Lançamentos → Manutenção de Remessa por imagem/cache.
; 5) Opcionalmente F7 → convênio → F8, Tab x3, selecionar/criar remessa.

DO_OPEN := true
DO_LOGIN := true
DO_NAV := true
DO_LOAD_CONVENIO := true
DO_SELECT_OR_CREATE_REMESSA := true
CLEAR_MENU_CACHE := false

TEST_USER := "iagosantana"
TEST_PASS := "iago##hsr16"
TEST_CONVENIO := "930"
TEST_REMESSA := "" ; vazio cria nova; preenchido busca existente
TEST_TIPO_CONTA := "Ambulatório" ; Emergência / Internamento / Ambulatório

FFCV_RUN := "C:\Users\ALLAN.DOSSANTOS\Desktop\FFCV.lnk"
WIN_LOGIN := "Identificação ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"
WIN_FFCV := "MV2000i - Faturamento ahk_exe ifrun60.EXE"
WIN_REMESSA := "MV2000i - Faturamento ahk_exe ifrun60.EXE"

IMG_ERRO := MV_Test_ImagePath("Erro_Icone.png")

TIPO_CODIGO := Map("Emergência", "1", "Internamento", "2", "Ambulatório", "3")

report := "SUÍTE: FFCV - Manutenção de Remessa`n"
        . "DO_OPEN=" DO_OPEN " DO_LOGIN=" DO_LOGIN " DO_NAV=" DO_NAV " DO_LOAD_CONVENIO=" DO_LOAD_CONVENIO " DO_SELECT_OR_CREATE_REMESSA=" DO_SELECT_OR_CREATE_REMESSA "`n`n"


if WinExist(WIN_FFCV) {
    report .= "✅ FFCV detectado por título amplo.`n"
    WinActivate WIN_FFCV
} else {
    report .= "⚠️ FFCV não detectado.`n"
    if DO_OPEN {
        Run FFCV_RUN
        report .= "▶️ Run FFCV executado.`n"
        if !T_Poll(() => WinExist(WIN_LOGIN) || WinExist(WIN_FFCV), 20)
            report .= "❌ Login/FFCV não apareceu após abrir.`n"
    }
}

if WinExist(WIN_LOGIN) {
    report .= "ℹ️ Janela Identificação detectada.`n"
    if DO_LOGIN {
        WinActivate WIN_LOGIN
        WinWaitActive WIN_LOGIN,, 2
        SendText TEST_USER
        Sleep 50
        Send "{Tab}"
        Sleep 50
        SendText TEST_PASS
        Sleep 50
        Send "{Enter}"
        report .= "✅ Login de teste enviado por teclado.`n"
        Sleep 700
        if MV_Test_ImageVisible(IMG_ERRO)
            report .= "⚠️ Erro_Icone.png detectado após login.`n"
    }
}

if DO_NAV {
    Sleep 100
    if WinExist(WIN_FFCV)
        WinActivate WIN_FFCV

    Send "{Alt down}"
    Send "l"
    Send "m"
    Send "{Alt up}"
    Send "{Enter}"

    if T_Poll(() => WinExist(WIN_REMESSA), 20)
        report .= "✅ Tela Manutenção de Remessa detectada.`n"
    else
        report .= "❌ Tela Manutenção de Remessa não detectada.`n"
}

if DO_LOAD_CONVENIO {
    Sleep 50
    Send "{F7}"
    Sleep 50
    SendText TEST_CONVENIO
    Sleep 50
    Send "{F8}"
    report .= "✅ F7 → convênio → F8 enviado.`n"
    Sleep 700
    Send "{Tab 3}"
    report .= "✅ Tab x3 enviado para área de remessas.`n"
}

if DO_SELECT_OR_CREATE_REMESSA {
    if (Trim(TEST_REMESSA) != "") {
        Send "{F7}"
        Sleep 50
        SendText TEST_REMESSA
        Sleep 50
        Send "{F8}"
        report .= "✅ Busca de remessa existente enviada: " TEST_REMESSA "`n"
    } else {
        hoje := FormatTime(, "dd/MM/yyyy")
        Send "{F6}"
        Sleep 50
        SendText hoje
        Sleep 50
        Send "{Tab 3}"
        Sleep 50
        SendText TIPO_CODIGO[TEST_TIPO_CONTA]
        Sleep 50
        Send "{F10}"
        report .= "✅ Nova remessa enviada: data=" hoje " tipo=" TEST_TIPO_CONTA " código=" TIPO_CODIGO[TEST_TIPO_CONTA] "`n"
    }
}

MV_Test_ShowReport(report)

T_Poll(condFn, timeoutSecs) {
    deadline := A_TickCount + timeoutSecs * 1000
    Loop {
        if condFn()
            return true
        if A_TickCount > deadline
            return false
        Sleep 50
    }
}
