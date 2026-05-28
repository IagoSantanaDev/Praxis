#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\_mv_control_probe.ahk

ListLines(false)
ProcessSetPriority("AboveNormal")
SetKeyDelay(10, 10)
SetMouseDelay(-1)
SetDefaultMouseSpeed(0)
SetControlDelay(-1)

; ==============================================================================
; CONFIGURAÇÕES E VARIÁVEIS GLOBAIS
; ==============================================================================
DO_OPEN     := true
DO_LOGIN    := true
DO_NAV      := true
DO_READ     := true

TEST_USER      := "iagosantana"
TEST_PASS      := "iago##hsr16"
TEST_PROTOCOLOS := "3251014,3249741" ; Lote global unificado

MOVDOC_LNK      := MV_Test_ProjectRoot() "\atalhos\MOVDOC.lnk"
WIN_LOGIN       := "Identificação ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"
WIN_LOGIN_ERROR := "Mensagem do MV2000 ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"
WIN_MOVDOC      := "Movimentação de Documentos ahk_exe ifrun60.EXE"
WIN_BAIXA       := "Protocolação de Baixa de Documentos ahk_exe ifrun60.EXE"
WIN_MOVDOC_POPUP:= "Forms ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"

PROTO_X     := 21
PROTO_Y     := 106
CONTA_X     := 252
CONVENIO_X  := 491

GRID_ROWS_Y := [222, 245, 268, 291]

RECEB_CLASS := "Button1"
RECEB_X     := 718
RECEB_Y     := 359
MODAL_OK_CLASS := "Button1"

protocolos   := T_ParseProtocolos(TEST_PROTOCOLOS)
linhasMovDoc := []
erros        := []

report := "SUÍTE: MOV DOC - fluxo completo por protocolo`n" . "DO_OPEN=" DO_OPEN " DO_LOGIN=" DO_LOGIN " DO_NAV=" DO_NAV " DO_READ=" DO_READ "`n" . "Protocolos: " TEST_PROTOCOLOS "`n`n"

; ==============================================================================
; FLUXO PRINCIPAL DE EXECUÇÃO
; ==============================================================================
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
        Run(MOVDOC_LNK, MV_Test_ProjectRoot() "\atalhos")
        report .= "▶️ MOV DOC executado por atalho local obrigatório.`n"
        if !T_Poll(() => WinExist(WIN_LOGIN) || WinExist(WIN_MOVDOC), 100)
            report .= "❌ Login/MOV DOC não apareceu após abrir.`n"
    }
}

if DO_LOGIN
    T_Poll(() => WinExist(WIN_LOGIN) || WinExist(WIN_MOVDOC), 30)

if WinExist(WIN_LOGIN) {
    report .= "ℹ️ Janela Identificação detectada.`n"
    if DO_LOGIN {
        WinActivate WIN_LOGIN
        if !WinWaitActive(WIN_LOGIN,, 5) {
            report .= "❌ Janela Identificação apareceu, mas não ficou ativa para receber login.`n"
            MV_Test_ShowReport(report)
            ExitApp
        }

        CoordMode("Mouse", "Client")
        Click(170, 118, 1)
        Sleep 20
        SendText TEST_USER
        Sleep 20
        Click(307, 119, 1)
        Sleep 20
        SendText TEST_PASS
        Sleep 20
        Send "{Enter}"
        report .= "✅ Login de teste enviado por coordenadas Client validadas da Identificação.`n"

        if !T_Poll(() => WinExist(WIN_LOGIN_ERROR) || !WinExist(WIN_LOGIN) || WinExist(WIN_MOVDOC), 30)
            report .= "⚠️ Login enviado, mas não houve mudança observável em 30s.`n"
        if WinExist(WIN_LOGIN_ERROR)
            report .= "⚠️ Popup/erro detectado por título: " WIN_LOGIN_ERROR "`n"
    }
}

if DO_NAV {
    if WinExist(WIN_MOVDOC) {
        WinActivate WIN_MOVDOC
        Sleep 200
        Send "{Alt down}mpb{Alt up}"
        if T_Poll(() => WinExist(WIN_BAIXA), 80)
            report .= "✅ Tela Baixa de Documentos detectada.`n"
        else
            report .= "❌ Tela Baixa de Documentos não detectada.`n"
    }
}

if DO_READ {
    if !WinExist(WIN_BAIXA) {
        report .= "❌ DO_READ exige a tela Baixa de Documentos aberta.`n"
    } else if (protocolos.Length = 0) {
        report .= "❌ Nenhum protocolo informado.`n"
    } else {
        Sleep 50
        for idx, protocolo in protocolos {
            report .= "`n── Protocolo " protocolo " (" idx "/" protocolos.Length ") ──`n"
            if !T_SetTextEditAtPoint(WIN_BAIXA, PROTO_X, PROTO_Y, protocolo) {
                report .= "❌ Falha ao preencher protocolo por região Client.`n"
                continue
            }
            report .= "✅ Protocolo preenchido; enviando F8.`n"
            Send "{F8}"
            if !T_WaitAfterF8(protocolo, &report) {
                report .= "❌ A primeira linha da grid não ficou legível após F8; coleta ignorada para este protocolo.`n"
                continue
            }
            
            linhas := T_ColetarLinhasMovDoc(protocolo, &report)
            if (linhas.Length = 0) {
                report .= "❌ Nenhuma conta/convênio coletado para o protocolo.`n"
            } else {
                for _, linha in linhas {
                    linhasMovDoc.Push(linha)
                    report .= " conta=" linha["conta"] " | convenio=" linha["convenio"] "`n"
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
    report .= " nenhuma`n"
} else {
    for _, linha in contasValidas
        report .= " Prot. " linha["protocolo"] " | Conta " linha["conta"] " | Convênio " linha["convenio"] "`n"
}

report .= "`nErros/pendências:`n"
if (erros.Length = 0) {
    report .= " nenhuma`n"
} else {
    for _, e in erros
        report .= " Prot. " e["protocolo"] " | Conta " e["conta"] " | " e["descricao"] "`n"
}

MV_Test_ShowReport(report)

; ==============================================================================
; FUNÇÕES OPERACIONAIS FILTRADAS PARA VELOCIDADE E DINÂMICA DE ROLAGEM
; ==============================================================================
T_ColetarLinhasMovDoc(protocolo, &report) {
    linhas := []
    vistos := Map()
    
    if (!(GRID_ROWS_Y is Array) || GRID_ROWS_Y.Length = 0) {
        report .= "❌ GRID_ROWS_Y precisa conter as coordenadas Y das linhas visíveis da Grid.`n"
        return linhas
    }
    
    WinActivate(WIN_BAIXA)
    if !WinWaitActive(WIN_BAIXA,, 2)
        return linhas
        
    MouseGetPos(&origX, &origY)
    CoordMode("Mouse", "Client")
    
    maxIteracoes := 100
    tabelaEncerrada := false
    
    Loop maxIteracoes {
        linhasAdicionadasNesteBloco := 0
        
        for idx, rowY in GRID_ROWS_Y {
            Sleep(20)
            
            contaRaw := T_ReadFieldByPhysicalClick(CONTA_X, rowY, "conta")
            convenioRaw := T_ReadFieldByPhysicalClick(CONVENIO_X, rowY, "convenio")
            
            conta := ""
            if RegExMatch(contaRaw, "\d+", &matchConta)
                conta := matchConta[] 
                
            convenio := ""
            if RegExMatch(convenioRaw, "\d+", &matchConvenio)
                convenio := matchConvenio[] 

            if (conta = protocolo || convenio = protocolo || conta = "" || convenio = "")
                continue
                
            if (conta = convenio) {
                contaRaw := T_ReadFieldByPhysicalClick(CONTA_X, rowY, "conta")
                if RegExMatch(contaRaw, "\d+", &matchConta)
                    conta := matchConta[]
            }

            key := protocolo "|" conta "|" convenio
            
            if vistos.Has(key)
                continue
                
            vistos[key] := true
            linhas.Push(Map("protocolo", protocolo, "conta", conta, "convenio", convenio))
            linhasAdicionadasNesteBloco++
        }
        
        if (tabelaEncerrada || linhasAdicionadasNesteBloco = 0) {
            if (tabelaEncerrada)
                report .= "ℹ️ Coleta concluída com sucesso após esvaziar o fim da Grid.`n"
            else
                report .= "ℹ️ Fim da Grid alcançado por repetição de registros.`n"
            break
        }
        
        ultimoY := GRID_ROWS_Y[GRID_ROWS_Y.Length]
        Click(CONTA_X + 15, ultimoY + 8, 1)
        Sleep(50)
        
        Loop GRID_ROWS_Y.Length {
            if WinExist(WIN_MOVDOC_POPUP) {
                T_DismissMovDocPopup()
                report .= "ℹ️ Popup de fim de registros detectado e fechado durante rolagem.`n"
                tabelaEncerrada := true 
                break
            }
            
            Send("{Down}")
            Sleep(90) 
        }
        
        if WinExist(WIN_MOVDOC_POPUP) {
            T_DismissMovDocPopup()
            report .= "ℹ️ Popup de fim de registros detectado pós-rolagem.`n"
            tabelaEncerrada := true
        }
        
        primeiroY := GRID_ROWS_Y[1]
        Click(CONTA_X + 15, primeiroY + 8, 1)
        Sleep(50)
    }
    
    MouseMove(origX, origY, 0)
    return linhas
}

T_ReadFieldByPhysicalClick(x, y, campo := "", fastTimeoutMs := 200, fallbackTimeoutMs := 300) {
    CoordMode("Mouse", "Client")
    
    centroX := x + 15
    centroY := y + 8
    
    Click(centroX, centroY, 1)
    Sleep(40)
    Send("{Home}")
    Sleep(30)
    Send("+{End}")
    Sleep(30)

    valor := T_CopySelectedFieldText(campo, fastTimeoutMs)
    if T_ValorCampoValido(valor, campo)
        return valor

    valor := T_CopySelectedFieldText(campo, fallbackTimeoutMs)
    if T_ValorCampoValido(valor, campo)
        return valor
        
    return ""
}

T_CopySelectedFieldText(campo := "", timeoutMs := 500) {
    A_Clipboard := ""
    Send("^c")
    if !ClipWait(timeoutMs / 1000)
        return ""

    return Trim(A_Clipboard)
}

T_ValorCampoValido(valor, campo := "") {
    valor := Trim(valor)
    if (valor = "")
        return false

    if !RegExMatch(valor, "^\d+$")
        return false

    if (campo = "convenio" && StrLen(valor) >= 4)
        return false

    if (campo = "conta" && StrLen(valor) < 5)
        return false

    return true
}

T_SetTextEditAtPoint(winTitle, x, y, value) {
    if !WinExist(winTitle) {
        if WinExist("ahk_exe ifrun60.EXE") {
            winTitle := "ahk_exe ifrun60.EXE"
        } else {
            return false 
        }
    }

    try {
        WinActivate(winTitle)
        if !WinWaitActive(winTitle,, 2)
            return false
    } catch {
        return false 
    }
        
    CoordMode("Mouse", "Client")
    centroProtoX := x + 40
    centroProtoY := y + 10
    
    Click(centroProtoX, centroProtoY, 1)
    Sleep(20)
    
    if (value != "") {
        SendText(value)
    }
    return true
}

T_FocusEditAtPoint(winTitle, x, y) {
    WinActivate(winTitle)
    CoordMode("Mouse", "Client")
    centroProtoX := x + 40
    centroProtoY := y + 10
    
    Click(centroProtoX, centroProtoY, 1)
    return true
}

T_FinalizarBaixaProtocolo(&report) {
    hwndReceb := T_FindControlGeneric(WIN_BAIXA, RECEB_CLASS, RECEB_X, RECEB_Y, 30)
    if (!hwndReceb) {
        report .= "❌ Botão Recebido não localizado pelas coordenadas.`n"
        return false
    }
    
    try checked := ControlGetChecked(hwndReceb)
    catch
        checked := ""
    
    if (checked = 0 || checked = "") {
        ControlClick(hwndReceb,,,,,"NA")
        report .= "✅ Recebido estava desmarcado/indefinido; click simples enviado.`n"
    } else if (checked = 1) {
        ControlClick(hwndReceb,,, 2,,"NA")
        report .= "✅ Recebido já estava marcado; double click enviado.`n"
    }
    
    Sleep(20)
    Send("{F10}")
    report .= "✅ F10 enviado após checkbox Recebido.`n"
    Sleep(20)
    
    if !T_FocusEditAtPoint(WIN_BAIXA, PROTO_X, PROTO_Y) {
        report .= "❌ Não consegui clicar/focar o campo Protocolo após F10.`n"
        return false
    }
    Sleep(20)
    
    Send("{F7}")
    Sleep(20)
    report .= "✅ Campo Protocolo clicado e F7 enviado para preparar nova consulta.`n"
    
    return true
}

; ==============================================================================
; ALGORITMOS INTERNOS E PARSEADORES
; ==============================================================================
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
        Sleep 25
    }
}

T_WaitAfterF8(protocolo, &report) {
    T_Poll(() => WinExist(WIN_BAIXA), 80)

    startedAt := A_TickCount
    deadline := startedAt + 12000

    Loop {
        if T_FirstGridLineReady(protocolo, &conta, &convenio) {
            elapsed := A_TickCount - startedAt
            report .= "ℹ️ Primeira linha legível após F8 em " elapsed "ms: conta=" conta " | convenio=" convenio "`n"
            return true
        }

        if (A_TickCount >= deadline) {
            elapsed := A_TickCount - startedAt
            report .= "❌ Timeout aguardando primeira linha legível após F8 (" elapsed "ms).`n"
            return false
        }

        Sleep(80)
    }
}

T_FirstGridLineReady(protocolo, &conta, &convenio) {
    conta := T_ReadFieldByPhysicalClick(CONTA_X, GRID_ROWS_Y[1], "conta", 100, 200)
    convenio := T_ReadFieldByPhysicalClick(CONVENIO_X, GRID_ROWS_Y[1], "convenio", 100, 200)

    if (conta = "" || convenio = "")
        return false

    if (conta = protocolo || convenio = protocolo)
        return false

    return true
}

T_ConvenioMajoritario(linhas) {
    counts := Map()
    ordem := []
    for _, linha in hyperlinks := linhas {
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

T_FindControlGeneric(winTitle, classNN, targetX, targetY, tolerance := 30) {
    try hwnds := WinGetControlsHwnd(winTitle)
    catch
        return 0
    bestHwnd := 0
    bestDist := 999999
    for hwnd in hwnds {
        try ctrlClass := ControlGetClassNN(hwnd)
        catch
            continue
        if (ctrlClass != classNN)
            continue
        try ControlGetPos(&cx, &cy, &cw, &ch, hwnd, winTitle)
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

T_ClickFirstControl(winTitle, classNN) {
    try hwnds := WinGetControlsHwnd(winTitle)
    catch
        return false
    for hwnd in hwnds {
        try ctrlClass := ControlGetClassNN(hwnd)
        catch
            continue
        if (ctrlClass = classNN) {
            ControlClick(hwnd,,,,,"NA")
            return true
        }
    }
    return false
}

T_DismissMovDocPopup() {
    try {
        if WinExist(WIN_MOVDOC_POPUP) {
            WinActivate(WIN_MOVDOC_POPUP)
            Sleep(50)
            if !T_ClickFirstControl(WIN_MOVDOC_POPUP, MODAL_OK_CLASS) {
                Send("{Enter}") 
            }
            T_Poll(() => !WinExist(WIN_MOVDOC_POPUP), 3)
        }
    }
}
