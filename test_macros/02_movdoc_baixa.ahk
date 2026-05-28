#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\_mv_control_probe.ahk

; TESTE 02 - MOV DOC / Baixa de Documentos / Coleta por clipboard
;
; Fluxo testado:
; 1) Detectar se MOV DOC está aberto por título amplo da janela.
; 2) Se não estiver aberto e DO_OPEN := true, abrir MOV DOC pelo .fmx.
; 3) Se aparecer login, testar login por teclado se DO_LOGIN := true.
; 4) Clicar Manutenção → Protocolação → Baixa de Documentos por imagens.
; 5) Aguardar título/imagem da tela Baixa.
; 6) Opcionalmente preencher protocolo + F8 e testar leitura de convênio/conta por double-click + Ctrl+C.
;
; Preencha os ClassNN/client dos 3 textfields quando tiver Window Spy.

DO_OPEN  := false
DO_LOGIN := false
DO_NAV   := false
DO_READ  := false

TEST_USER      := "TESTE_USUARIO"
TEST_PASS      := "TESTE_SENHA"
TEST_PROTOCOLO := "3247211"

MOVDOC_RUN := 'E:\mv2000\BIN\irfun60.EXE E:\mv2000\movdoc\movdoc.fmx'
WIN_LOGIN  := "Identificação ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"
WIN_MOVDOC := "Movimentação de Documentos ahk_exe ifrun60.EXE"
WIN_BAIXA  := "Protocolação de Baixa de Documentos ahk_exe ifrun60.EXE"

IMG_MENU_MANUT    := MV_Test_ImagePath("Menu_Manutenção.png")
IMG_MENU_PROTOC   := MV_Test_ImagePath("Menu_Protocolação.png")
IMG_MENU_BAIXA    := MV_Test_ImagePath("Menu_Baixa.png")
IMG_TELA_BAIXA    := MV_Test_ImagePath("Tittle_TelaBaixa.png")
IMG_ERRO_ICONE    := MV_Test_ImagePath("Erro_Icone.png")
IMG_RECEB_CHECK   := MV_Test_ImagePath("Botão_RecebimentoCheckado.png")

; PENDENTE Window Spy
PROTO_CLASS := "CLASSNN"
PROTO_X     := ""
PROTO_Y     := ""

CONVENIO_CLASS := "CLASSNN"
CONVENIO_X     := ""
CONVENIO_Y     := ""

CONTA_CLASS := "CLASSNN"
CONTA_X     := ""
CONTA_Y     := ""

; Confirmado previamente, validar antes de usar em produção.
RECEB_CLASS := "Button1"
RECEB_X     := 718
RECEB_Y     := 359

report := "SUÍTE: MOV DOC - fluxo Remessa por Protocolo`n"
        . "DO_OPEN=" DO_OPEN " DO_LOGIN=" DO_LOGIN " DO_NAV=" DO_NAV " DO_READ=" DO_READ "`n`n"

movdocReady := WinExist(WIN_MOVDOC)
if movdocReady {
    report .= "✅ MOV DOC detectado por título amplo. Não exige título de subtela.`n"
    WinActivate WIN_MOVDOC
} else {
    report .= "⚠️ MOV DOC não detectado.`n"
    if DO_OPEN {
        Run MOVDOC_RUN
        report .= "▶️ Run MOVDOC executado.`n"
        if !MV_Test_Poll(() => WinExist(WIN_LOGIN) || WinExist(WIN_MOVDOC), 20)
            report .= "❌ Login/MOV DOC não apareceu após abrir.`n"
    } else {
        report .= "ℹ️ DO_OPEN=false; não abri o MOV DOC.`n"
    }
}

if WinExist(WIN_LOGIN) {
    report .= "ℹ️ Janela Identificação detectada.`n"
    if DO_LOGIN {
        WinActivate WIN_LOGIN
        WinWaitActive WIN_LOGIN,, 2
        SendText TEST_USER
        Sleep 80
        Send "{Tab}"
        Sleep 80
        SendText TEST_PASS
        Sleep 80
        Send "{Enter}"
        report .= "✅ Login de teste enviado por teclado.`n"

        Sleep 700
        if MV_Test_ImageVisible(IMG_ERRO_ICONE)
            report .= "⚠️ Popup/erro detectado por Erro_Icone.png.`n"
    } else {
        report .= "ℹ️ DO_LOGIN=false; login não enviado.`n"
    }
}

if DO_NAV {
    if WinExist(WIN_MOVDOC)
        WinActivate WIN_MOVDOC

    if MV_Test_ClickImage(IMG_MENU_MANUT) {
        report .= "✅ Clique em Menu_Manutenção.png.`n"
        Sleep 180
    } else {
        report .= "❌ Não encontrei Menu_Manutenção.png.`n"
    }

    if MV_Test_ClickImage(IMG_MENU_PROTOC) {
        report .= "✅ Clique em Menu_Protocolação.png.`n"
        Sleep 180
    } else {
        report .= "❌ Não encontrei Menu_Protocolação.png.`n"
    }

    if MV_Test_ClickImage(IMG_MENU_BAIXA) {
        report .= "✅ Clique em Menu_Baixa.png.`n"
    } else {
        report .= "❌ Não encontrei Menu_Baixa.png.`n"
    }

    if MV_Test_Poll(() => WinExist(WIN_BAIXA) || MV_Test_ImageVisible(IMG_TELA_BAIXA), 20)
        report .= "✅ Tela Baixa de Documentos detectada.`n"
    else
        report .= "❌ Tittle_TelaBaixa.png/título amplo não detectado.`n"
} else {
    report .= "ℹ️ DO_NAV=false; navegação Manutenção → Protocolação → Baixa não executada.`n"
}

if DO_READ {
    if !WinExist(WIN_BAIXA) {
        report .= "❌ DO_READ exige a tela Baixa de Documentos aberta.`n"
    } else {
        if MV_Test_Mapped(PROTO_CLASS, PROTO_X, PROTO_Y) {
            if MV_Test_SetTextAt(WIN_BAIXA, PROTO_CLASS, PROTO_X, PROTO_Y, TEST_PROTOCOLO) {
                report .= "✅ Protocolo preenchido por ClassNN+Client; enviando F8.`n"
                Send "{F8}"
                Sleep 700
            } else {
                report .= "❌ Falha ao preencher protocolo.`n"
            }
        } else {
            report .= "⚠️ Campo Protocolo pendente: preencha PROTO_CLASS/PROTO_X/PROTO_Y.`n"
        }

        if MV_Test_Mapped(CONVENIO_CLASS, CONVENIO_X, CONVENIO_Y) {
            convenio := MV_Test_ReadAt(WIN_BAIXA, CONVENIO_CLASS, CONVENIO_X, CONVENIO_Y)
            report .= "✅ Convênio copiado: " convenio "`n"
        } else {
            report .= "⚠️ Campo Convênio pendente: preencha CONVENIO_CLASS/CONVENIO_X/CONVENIO_Y.`n"
        }

        if MV_Test_Mapped(CONTA_CLASS, CONTA_X, CONTA_Y) {
            conta := MV_Test_ReadAt(WIN_BAIXA, CONTA_CLASS, CONTA_X, CONTA_Y)
            report .= "✅ Primeira conta copiada: " conta "`n"
            Send "{Down}"
            Sleep 100
            if MV_Test_ImageVisible(IMG_ERRO_ICONE)
                report .= "ℹ️ Popup/fim do grid detectado por Erro_Icone.png após Down.`n"
        } else {
            report .= "⚠️ Campo Conta pendente: preencha CONTA_CLASS/CONTA_X/CONTA_Y.`n"
        }

        if MV_Test_ImageVisible(IMG_RECEB_CHECK)
            report .= "✅ Checkbox Recebido parece checkado por imagem.`n"
        else
            report .= "ℹ️ Checkbox Recebido não parece checkado pela imagem atual.`n"
    }
} else {
    report .= "ℹ️ DO_READ=false; leitura de protocolo/convênio/conta não executada.`n"
}

MV_Test_ShowReport(report)

MV_Test_Poll(condFn, timeoutSecs) {
    deadline := A_TickCount + timeoutSecs * 1000
    Loop {
        if condFn()
            return true
        if A_TickCount > deadline
            return false
        Sleep 50
    }
}

MV_Test_Mapped(classNN, x, y) {
    return !(classNN = "" || classNN = "CLASSNN" || x = "" || y = "")
}

MV_Test_SetTextAt(winTitle, classNN, x, y, value) {
    found := MV_Test_FindControlByClientPoint(winTitle, classNN, x + 0, y + 0)
    hwnd := found.Get("hwnd", 0)
    if !hwnd
        return false
    ControlFocus hwnd
    Sleep 80
    SendText value
    return true
}

MV_Test_ReadAt(winTitle, classNN, x, y) {
    found := MV_Test_FindControlByClientPoint(winTitle, classNN, x + 0, y + 0)
    hwnd := found.Get("hwnd", 0)
    if !hwnd
        return ""
    A_Clipboard := ""
    ControlClick hwnd,,,, 2, "NA"
    Sleep 80
    Send "^c"
    MV_Test_Poll(() => A_Clipboard != "", 3)
    return Trim(A_Clipboard)
}
