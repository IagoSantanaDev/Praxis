#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\_mv_control_probe.ahk

; TESTE 02 - MOV DOC / Baixa de Documentos / fluxo completo por protocolo
;
; Fluxo testado:
; 1) Detectar/abrir MOV DOC por atalho local obrigatório em atalhos\MOVDOC.lnk.
; 2) Se aparecer login, enviar usuário → Tab → senha → Enter.
; 3) Sempre abrir nova tela funcional: Manutenção → Protocolação → Baixa.
; 4) Para cada protocolo: colar número, F8, esperar carregar, coletar todas as contas/convênios.
; 5) Dar Recebido, focar Protocolo, F10, F7 e repetir a partir da colagem do protocolo.
; 6) Relatório final informa contas, convênio majoritário e erros por convênio diferente.
;
; Não configure EditN fixo: Oracle Forms renumera Edit1/Edit2/Edit15 conforme estado.
; A leitura da grid usa somente ControlGetText(hwnd), sem clipboard.

DO_OPEN  := true
DO_LOGIN := true
DO_NAV   := true
DO_READ  := true

TEST_USER       := "iagosantana"
TEST_PASS       := "iago##hsr16"
TEST_PROTOCOLOS := "3249741" ; Separe múltiplos protocolos por vírgula.

MOVDOC_LNK := MV_Test_ProjectRoot() "\atalhos\MOVDOC.lnk"
WIN_LOGIN  := "Identificação ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"
WIN_LOGIN_ERROR := "Mensagem do MV2000 ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"
WIN_MOVDOC := "Movimentação de Documentos ahk_exe ifrun60.EXE"
WIN_BAIXA  := "Protocolação de Baixa de Documentos ahk_exe ifrun60.EXE"
WIN_MOVDOC_POPUP := "Forms ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"

; Regiões Client extraídas do Window Spy.
PROTO_X := 21
PROTO_Y := 106
CONTA_X := 252
CONVENIO_X := 491
GRID_ROWS_Y := [222, 245, 268, 291]

RECEB_CLASS := "Button1"
RECEB_X     := 718
RECEB_Y     := 359
MODAL_OK_CLASS := "Button1"

protocolos := T_ParseProtocolos(TEST_PROTOCOLOS)
linhasMovDoc := []
erros := []

report := "SUÍTE: MOV DOC - fluxo completo por protocolo`n"
        . "DO_OPEN=" DO_OPEN " DO_LOGIN=" DO_LOGIN " DO_NAV=" DO_NAV " DO_READ=" DO_READ "`n"
        . "Protocolos: " TEST_PROTOCOLOS "`n`n"

movdocReady := WinExist(WIN_MOVDOC)
if movdocReady {
    report .= "✅ MOV DOC detectado por título amplo.`n"
    WinActivate WIN_MOVDOC
} else {
    report .= "⚠️ MOV DOC não detectado.`n"
    if DO_OPEN {
        if !FileExist(MOVDOC_LNK) {
            report .= "❌ Atalho obrigatório não encontrado: " MOVDOC_LNK "`n"
            MV_Test_ShowReport(report)
            ExitApp
        }
        Run MOVDOC_LNK, MV_Test_ProjectRoot() "\atalhos"
        report .= "▶️ MOV DOC executado por atalho local obrigatório.`n"
        if !T_Poll(() => WinExist(WIN_LOGIN) || WinExist(WIN_MOVDOC), 20)
            report .= "❌ Login/MOV DOC não apareceu após abrir.`n"
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
        if WinExist(WIN_LOGIN_ERROR)
            report .= "⚠️ Popup/erro detectado por título: " WIN_LOGIN_ERROR "`n"
    }
}

if DO_NAV {
    if WinExist(WIN_MOVDOC)
        WinActivate WIN_MOVDOC

    ; Sempre abre nova tela funcional; não reaproveitar Baixa já aberta.
    Send "{Alt down}"
    Send "m"
    Send "p"
    Send "b"
    Send "{Alt up}"

    if T_Poll(() => WinExist(WIN_BAIXA), 20)
        report .= "✅ Tela Baixa de Documentos detectada.`n"
    else
        report .= "❌ Tela Baixa de Documentos não detectada.`n"
}

if DO_READ {
    if !WinExist(WIN_BAIXA) {
        report .= "❌ DO_READ exige a tela Baixa de Documentos aberta.`n"
    } else if (protocolos.Length = 0) {
        report .= "❌ Nenhum protocolo informado.`n"
    } else {
        for idx, protocolo in protocolos {
            report .= "`n── Protocolo " protocolo " (" idx "/" protocolos.Length ") ──`n"

            if !T_SetTextEditAtPoint(WIN_BAIXA, PROTO_X, PROTO_Y, protocolo) {
                report .= "❌ Falha ao preencher protocolo por região Client.`n"
                continue
            }

            report .= "✅ Protocolo preenchido; enviando F8.`n"
            Send "{F8}"
            T_WaitAfterF8()

            linhas := T_ColetarLinhasMovDoc(protocolo, &report)
            if (linhas.Length = 0) {
                report .= "❌ Nenhuma conta/convênio coletado para o protocolo.`n"
            } else {
                for _, linha in linhas {
                    linhasMovDoc.Push(linha)
                    report .= "  conta=" linha["conta"] " | convenio=" linha["convenio"] "`n"
                }
            }

            if T_FinalizarBaixaProtocolo(&report)
                report .= "✅ Recebido aplicado, F10 enviado e F7 preparado para próxima consulta.`n"
            else
                report .= "❌ Falha ao aplicar Recebido/salvar/preparar F7.`n"
        }
    }
}

convenioMajoritario := T_ConvenioMajoritario(linhasMovDoc)
contasValidas := T_FiltrarContasPorConvenio(linhasMovDoc, convenioMajoritario, erros)

report .= "`n════════ RESUMO FINAL ════════`n"
report .= "Total de linhas coletadas: " linhasMovDoc.Length "`n"
report .= "Convênio majoritário: " (convenioMajoritario = "" ? "não identificado" : convenioMajoritario) "`n`n"

report .= "Contas válidas para remessa:`n"
if (contasValidas.Length = 0) {
    report .= "  nenhuma`n"
} else {
    for _, linha in contasValidas
        report .= "  Prot. " linha["protocolo"] " | Conta " linha["conta"] " | Convênio " linha["convenio"] "`n"
}

report .= "`nErros/pendências:`n"
if (erros.Length = 0) {
    report .= "  nenhuma`n"
} else {
    for _, e in erros
        report .= "  Prot. " e["protocolo"] " | Conta " e["conta"] " | " e["descricao"] "`n"
}

MV_Test_ShowReport(report)

T_ParseProtocolos(str) {
    result := []
    for _, p in StrSplit(str, ",") {
        p := Trim(p)
        if (p != "")
            result.Push(p)
    }
    return result
}

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

T_WaitAfterF8() {
    T_Poll(() => WinExist(WIN_BAIXA), 20)
    Sleep 700
}

T_ColetarLinhasMovDoc(protocolo, &report) {
    linhas := []
    vistos := Map()

    addedInitial := T_ColetarLinhasVisiveisMovDoc(protocolo, linhas, vistos)
    report .= "ℹ️ Coleta inicial: " addedInitial " nova(s) linha(s).`n"

    Loop 80 {
        result := T_AvancarGridQuatroLinhas()
        added := T_ColetarLinhasVisiveisMovDoc(protocolo, linhas, vistos)
        report .= "ℹ️ Bloco " A_Index ": novas=" added " popup=" (result["popup"] ? "sim" : "não") "`n"

        if result["popup"]
            break
        if (added = 0) {
            report .= "ℹ️ Parando: 4 setas não trouxeram conta nova; evita loop em protocolos com até 4 contas ou grid sem avanço.`n"
            break
        }
    }

    return linhas
}

T_AvancarGridQuatroLinhas() {
    Loop 4 {
        Send "{Down}"
        Sleep 100

        if T_Poll(() => WinExist(WIN_MOVDOC_POPUP), 0.25) {
            T_DismissMovDocPopup()
            return Map("popup", true)
        }
    }

    return Map("popup", false)
}

T_ColetarLinhasVisiveisMovDoc(protocolo, linhas, vistos) {
    added := 0

    for _, rowY in GRID_ROWS_Y {
        conta := T_ReadEditAtPoint(WIN_BAIXA, CONTA_X, rowY, "^\d+$")
        convenio := T_ReadEditAtPoint(WIN_BAIXA, CONVENIO_X, rowY, "^\d+$")

        if (conta = "" || convenio = "")
            continue

        key := protocolo "|" conta "|" convenio
        if vistos.Has(key)
            continue

        vistos[key] := true
        linhas.Push(Map("protocolo", protocolo, "conta", conta, "convenio", convenio))
        added++
    }

    return added
}

T_FinalizarBaixaProtocolo(&report) {
    checked := T_ControlCheckedAt(WIN_BAIXA, RECEB_CLASS, RECEB_X, RECEB_Y)

    if (checked = 0) {
        if !T_ClickControlAt(WIN_BAIXA, RECEB_CLASS, RECEB_X, RECEB_Y)
            return false
        report .= "ℹ️ Recebido estava 0; click simples enviado.`n"
    } else if (checked = 1) {
        if !T_DoubleClickControlAt(WIN_BAIXA, RECEB_CLASS, RECEB_X, RECEB_Y)
            return false
        report .= "ℹ️ Recebido estava 1; double click enviado.`n"
    } else {
        report .= "❌ Não consegui ler ControlGetChecked do Recebido.`n"
        return false
    }

    Sleep 100
    if !T_FocusEditAtPoint(WIN_BAIXA, PROTO_X, PROTO_Y)
        return false
    Sleep 80
    Send "{F10}"
    Sleep 500
    Send "{F7}"
    Sleep 120
    return true
}

T_ConvenioMajoritario(linhas) {
    counts := Map()
    ordem := []

    for _, linha in linhas {
        convenio := linha["convenio"]
        if !counts.Has(convenio) {
            counts[convenio] := 0
            ordem.Push(convenio)
        }
        counts[convenio] += 1
    }

    escolhido := ""
    maior := 0
    for _, convenio in ordem {
        if (counts[convenio] > maior) {
            maior := counts[convenio]
            escolhido := convenio
        }
    }
    return escolhido
}

T_FiltrarContasPorConvenio(linhas, convenioEscolhido, erros) {
    result := []
    if (convenioEscolhido = "")
        return result

    for _, linha in linhas {
        if (linha["convenio"] = convenioEscolhido) {
            result.Push(linha)
        } else {
            erros.Push(Map(
                "protocolo", linha["protocolo"],
                "conta", linha["conta"],
                "descricao", "Convênio diferente: " linha["convenio"]
            ))
        }
    }
    return result
}

T_SetTextEditAtPoint(winTitle, x, y, value) {
    hwnd := T_FindEditByClientPoint(winTitle, x + 0, y + 0)
    if !hwnd
        return false
    WinActivate winTitle
    WinWaitActive winTitle,, 2
    ControlFocus hwnd
    Sleep 80
    Send "^a"
    Sleep 50
    SendText value
    return true
}

T_FocusEditAtPoint(winTitle, x, y) {
    hwnd := T_FindEditByClientPoint(winTitle, x + 0, y + 0)
    if !hwnd
        return false
    WinActivate winTitle
    WinWaitActive winTitle,, 2
    ControlFocus hwnd
    return true
}

T_ReadEditAtPoint(winTitle, x, y, expectedPattern := "") {
    hwnd := T_FindEditByClientPoint(winTitle, x + 0, y + 0)
    if !hwnd
        return ""

    try text := Trim(ControlGetText(hwnd))
    catch
        return ""

    return T_TextMatches(text, expectedPattern) ? text : ""
}

T_FindEditByClientPoint(winTitle, targetX, targetY, tolerance := 14) {
    try hwnds := WinGetControlsHwnd(winTitle)
    catch
        return 0

    bestHwnd := 0
    bestDist := 999999

    for hwnd in hwnds {
        try ctrlClass := ControlGetClassNN(hwnd)
        catch
            continue
        if (SubStr(ctrlClass, 1, 4) != "Edit")
            continue
        try ControlGetPos &cx, &cy, &cw, &ch, hwnd
        catch
            continue

        if (targetX >= cx && targetX <= cx + cw && targetY >= cy && targetY <= cy + ch)
            return hwnd

        centerX := cx + (cw / 2)
        centerY := cy + (ch / 2)
        dist := Sqrt((targetX - centerX) ** 2 + (targetY - centerY) ** 2)
        if (dist < bestDist) {
            bestDist := dist
            bestHwnd := hwnd
        }
    }

    return (bestHwnd && bestDist <= tolerance) ? bestHwnd : 0
}

T_TextMatches(text, expectedPattern := "") {
    if (text = "")
        return false
    if (expectedPattern = "")
        return true
    return RegExMatch(text, expectedPattern)
}

T_ControlCheckedAt(winTitle, classNN, x, y) {
    found := MV_Test_FindControlByClientPoint(winTitle, classNN, x + 0, y + 0)
    hwnd := found.Get("hwnd", 0)
    if !hwnd
        return ""
    try return ControlGetChecked(hwnd)
    catch
        return ""
}

T_ClickControlAt(winTitle, classNN, x, y) {
    found := MV_Test_FindControlByClientPoint(winTitle, classNN, x + 0, y + 0)
    hwnd := found.Get("hwnd", 0)
    if !hwnd
        return false
    ControlClick hwnd,,,,, "NA"
    return true
}

T_DoubleClickControlAt(winTitle, classNN, x, y) {
    found := MV_Test_FindControlByClientPoint(winTitle, classNN, x + 0, y + 0)
    hwnd := found.Get("hwnd", 0)
    if !hwnd
        return false
    ControlClick hwnd,,,, 2, "NA"
    return true
}

T_ClickFirstControl(winTitle, classNN) {
    try hwnds := WinGetControlsHwnd(winTitle)
    catch
        return false

    for hwnd in hwnds {
        try ctrlClass := ControlGetClassNN(hwnd)
        catch
            continue
        if (ctrlClass = classNN) {
            ControlClick hwnd,,,,, "NA"
            return true
        }
    }
    return false
}

T_DismissMovDocPopup() {
    try {
        if WinExist(WIN_MOVDOC_POPUP) {
            WinActivate WIN_MOVDOC_POPUP
            Sleep 80
            if !T_ClickFirstControl(WIN_MOVDOC_POPUP, MODAL_OK_CLASS)
                return false
            return T_Poll(() => !WinExist(WIN_MOVDOC_POPUP), 10)
        }
    }
    return false
}
