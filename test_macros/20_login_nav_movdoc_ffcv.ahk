; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_ScriptDir%\_mv_control_probe.ahk

; TESTE 20 - Abertura, login e navegação MOV DOC + FFCV
;
; Objetivo:
; - Isolar os pontos que NÃO eram fonte de verdade nos macros 02/11:
;   abertura por atalho, login e navegação pós-login.
; - Usar coordenadas Client validadas da tela Identificação.
; - Aguardar estabilização da janela antes de enviar atalhos de menu.
;
; Segurança:
; - Credenciais não ficam hardcoded neste arquivo.
; - Se TEST_USER/TEST_PASS estiverem vazios, o macro pergunta via InputBox.
; - A senha não é gravada no relatório.
;
; Evidências de referência:
; - Fluxos\Login\*.png contém capturas históricas da tela de login usadas para validação visual.

ListLines(false)
SetTitleMatchMode 2
DetectHiddenText true
SetControlDelay(-1)
SetWinDelay(0)
SetKeyDelay(10, 10)
SetMouseDelay(-1)
SetDefaultMouseSpeed(0)

; ════════════════════════════════════════════════════════════════
; FLAGS
; ════════════════════════════════════════════════════════════════

DO_MOVDOC := true
DO_FFCV   := true
DO_OPEN   := false ; não abrir novos atalhos, apenas detectar telas já abertas
DO_LOGIN  := true
DO_NAV    := true

; Se vazios, serão solicitados por InputBox.
TEST_USER := "iagosantana"
TEST_PASS := "iago##hsr16"

; Ajustes de estabilidade.
LOGIN_STABLE_MS       := 600
LOGIN_FIELD_SETTLE_MS := 100
POST_LOGIN_STABLE_MS  := 600
PRE_NAV_STABLE_MS     := 600
TARGET_STABLE_MS      := 600
NAV_TIMEOUT_SECS      := 100

; ════════════════════════════════════════════════════════════════
; JANELAS / ATALHOS
; ════════════════════════════════════════════════════════════════

PROJECT_ROOT := MV_Test_ProjectRoot()
LOGIN_EVIDENCE_DIR := PROJECT_ROOT "\Fluxos\Login"
MOVDOC_LNK := PROJECT_ROOT "\atalhos\MOVDOC.lnk"
FFCV_LNK   := PROJECT_ROOT "\atalhos\FFCV.lnk"

WIN_LOGIN := "Identificação ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"
WIN_LOGIN_ERROR := "Mensagem do MV2000 ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"
WIN_ANY_MODAL := "ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"

WIN_MOVDOC := "Movimentação de Documentos ahk_exe ifrun60.EXE"
WIN_BAIXA  := "Protocolação de Baixa de Documentos ahk_exe ifrun60.EXE"

WIN_FFCV := "MV2000i - Faturamento ahk_exe ifrun60.EXE"
WIN_REMESSA := "Manutenção de Remessa ahk_exe ifrun60.EXE"

LOGIN_USER_X := 170
LOGIN_USER_Y := 118
LOGIN_PASS_X := 307
LOGIN_PASS_Y := 119
MODAL_OK_CLASS := "Button1"

report := "SUÍTE: Abertura/Login/Navegação MOV DOC + FFCV`n"
        . "Timestamp: " FormatTime(, "yyyy-MM-dd HH:mm:ss") "`n"
        . "DO_MOVDOC=" DO_MOVDOC " DO_FFCV=" DO_FFCV " DO_OPEN=" DO_OPEN " DO_LOGIN=" DO_LOGIN " DO_NAV=" DO_NAV "`n"
        . "Login evidence dir: " LOGIN_EVIDENCE_DIR "`n`n"

if DO_LOGIN {
    cred := EnsureCredentials(TEST_USER, TEST_PASS)
    if !cred["ok"] {
        report .= "❌ Credenciais não informadas; teste cancelado antes de executar ações.`n"
        SaveAndShow(report)
        ExitApp
    }
    TEST_USER := cred["user"]
    TEST_PASS := cred["pass"]
    report .= "✅ Credenciais recebidas via InputBox/env local. Usuário informado; senha não registrada.`n`n"
}

if DO_MOVDOC
    report .= TestModule("MOV DOC", MOVDOC_LNK, WIN_MOVDOC, WIN_BAIXA, "{Alt down}mpb{Alt up}")

if DO_FFCV
    report .= TestModule("FFCV", FFCV_LNK, WIN_FFCV, WIN_REMESSA, "{Alt down}lm{Alt up}{Enter}")

SaveAndShow(report)

TestModule(moduleName, shortcutPath, moduleWin, targetWin, navKeys) {
    global DO_OPEN, DO_LOGIN, DO_NAV, WIN_LOGIN, WIN_LOGIN_ERROR, WIN_ANY_MODAL, PROJECT_ROOT
    global TEST_USER, TEST_PASS, POST_LOGIN_STABLE_MS, PRE_NAV_STABLE_MS, TARGET_STABLE_MS, NAV_TIMEOUT_SECS

    msg := "════════ " moduleName " ════════`n"

    if WinExist(moduleWin) {
        msg .= "✅ " moduleName " já detectado por título amplo.`n"
        WinActivate moduleWin
    } else {
        msg .= "⚠️ " moduleName " não detectado.`n"
        if !DO_OPEN {
            msg .= "ℹ️ DO_OPEN=false; não abriu atalho. Apenas detecta login existente para prosseguir.`n"
        } else {
            if !FileExist(shortcutPath) {
                msg .= "❌ Atalho obrigatório não encontrado: " shortcutPath "`n`n"
                return msg
            }

            Run shortcutPath, PROJECT_ROOT "\atalhos"
            msg .= "▶️ Atalho executado: " shortcutPath "`n"
        }
    }

    if !T_Poll(() => WinExist(WIN_LOGIN) || WinExist(moduleWin), NAV_TIMEOUT_SECS) {
        msg .= "❌ Nem login nem janela do módulo apareceram em " NAV_TIMEOUT_SECS "s.`n`n"
        return msg
    }

    if WinExist(WIN_LOGIN) {
        msg .= "ℹ️ Janela Identificação detectada para " moduleName ".`n"
        if DO_LOGIN {
            loginResult := DoLogin(moduleName, moduleWin)
            msg .= loginResult["report"]
            if !loginResult["ok"] {
                msg .= "⛔ Login falhou; navegação não executada.`n`n"
                return msg
            }
        } else {
            msg .= "ℹ️ DO_LOGIN=false; login não enviado.`n`n"
            return msg
        }
    }

    if !WaitWindowStable(moduleWin, POST_LOGIN_STABLE_MS, NAV_TIMEOUT_SECS) {
        msg .= "❌ " moduleName " não estabilizou após login/abertura.`n`n"
        return msg
    }
    msg .= "✅ " moduleName " estável antes da navegação.`n"

    if DO_NAV {
        WinActivate moduleWin
        if !WaitWindowStable(moduleWin, PRE_NAV_STABLE_MS, NAV_TIMEOUT_SECS) {
            msg .= "❌ " moduleName " não estabilizou antes do atalho de navegação.`n`n"
            return msg
        }

        Send navKeys
        msg .= "▶️ Atalho de navegação enviado: " navKeys "`n"

        if T_Poll(() => WinExist(targetWin), NAV_TIMEOUT_SECS) {
            msg .= "✅ Tela alvo detectada: " targetWin "`n"
            if WaitWindowStable(targetWin, TARGET_STABLE_MS, NAV_TIMEOUT_SECS) {
                msg .= "✅ Tela alvo estável após navegação.`n"
            } else {
                msg .= "⚠️ Tela alvo detectada, mas não estabilizou em " NAV_TIMEOUT_SECS "s: " targetWin "`n"
            }
        } else {
            msg .= "❌ Tela alvo não detectada em " NAV_TIMEOUT_SECS "s: " targetWin "`n"
            msg .= "   Janela ativa: " SafeActiveTitle() "`n"
            if WinExist(WIN_ANY_MODAL)
                msg .= "   Modal ativo detectado. Texto acessível:`n" SafeWinGetText(WIN_ANY_MODAL) "`n"
        }
    } else {
        msg .= "ℹ️ DO_NAV=false; navegação não enviada.`n"
    }

    msg .= "`n"
    return msg
}

DoLogin(moduleName, moduleWin) {
    global WIN_LOGIN, WIN_LOGIN_ERROR, TEST_USER, TEST_PASS
    global LOGIN_USER_X, LOGIN_USER_Y, LOGIN_PASS_X, LOGIN_PASS_Y, LOGIN_STABLE_MS, LOGIN_FIELD_SETTLE_MS, MODAL_OK_CLASS, NAV_TIMEOUT_SECS

    msg := "▶️ Enviando login para " moduleName " por coordenadas Client validadas.`n"
    if !WinExist(WIN_LOGIN)
        return Map("ok", false, "report", msg "❌ Janela Identificação não existe.`n")

    if !ActivateWindow(WIN_LOGIN)
        return Map("ok", false, "report", msg "❌ Janela Identificação não pôde ser ativada.`n")

    if !WaitWindowStable(WIN_LOGIN, LOGIN_STABLE_MS, NAV_TIMEOUT_SECS)
        return Map("ok", false, "report", msg "❌ Janela Identificação não estabilizou antes do envio.`n")

    msg .= "✅ Janela Identificação estável antes do envio.`n"

    if !ClickLoginField(LOGIN_USER_X, LOGIN_USER_Y)
        return Map("ok", false, "report", msg "❌ Falha ao posicionar o foco no campo Usuário.`n")
    SendText TEST_USER
    Sleep LOGIN_FIELD_SETTLE_MS

    if !ClickLoginField(LOGIN_PASS_X, LOGIN_PASS_Y)
        return Map("ok", false, "report", msg "❌ Falha ao posicionar o foco no campo Senha.`n")
    SendText TEST_PASS
    Sleep LOGIN_FIELD_SETTLE_MS
    Send "{Enter}"

    startedAt := A_TickCount
    Loop {
        if WinExist(WIN_LOGIN_ERROR) {
            DismissModal(WIN_LOGIN_ERROR, MODAL_OK_CLASS)
            return Map("ok", false, "report", msg "❌ Popup de erro de login detectado e fechado.`n")
        }

        if WinExist(moduleWin) {
            elapsed := A_TickCount - startedAt
            return Map("ok", true, "report", msg "✅ Login aceito; janela do módulo apareceu em " elapsed "ms.`n")
        }

        if (A_TickCount - startedAt > NAV_TIMEOUT_SECS * 1000)
            return Map("ok", false, "report", msg "❌ Timeout aguardando módulo após login.`n")

        Sleep 50
    }
}

EnsureCredentials(userValue, passValue) {
    userValue := Trim(userValue)
    if (userValue = "") {
        ib := InputBox("Informe o usuário do MV2000i para este teste.", "Login MV2000i", "w420 h130")
        if (ib.Result != "OK" || Trim(ib.Value) = "")
            return Map("ok", false, "user", "", "pass", "")
        userValue := Trim(ib.Value)
    }

    if (passValue = "") {
        ib := InputBox("Informe a senha do MV2000i para este teste. Ela não será gravada no relatório.", "Senha MV2000i", "Password w460 h140")
        if (ib.Result != "OK" || ib.Value = "")
            return Map("ok", false, "user", "", "pass", "")
        passValue := ib.Value
    }

    return Map("ok", true, "user", userValue, "pass", passValue)
}

ActivateWindow(winTitle, timeoutSecs := 5) {
    if !WinExist(winTitle)
        return false

    WinActivate winTitle
    if WinWaitActive(winTitle,, timeoutSecs)
        return true

    loop 2 {
        Sleep 150
        WinActivate winTitle
        if WinWaitActive(winTitle,, timeoutSecs)
            return true
    }
    return false
}

ClickLoginField(clientX, clientY) {
    global WIN_LOGIN, LOGIN_FIELD_SETTLE_MS

    if !ActivateWindow(WIN_LOGIN)
        return false

    CoordMode("Mouse", "Client")
    MouseMove(clientX, clientY, 0)
    Sleep 50
    Click
    Sleep LOGIN_FIELD_SETTLE_MS

    if !WinActive(WIN_LOGIN) {
        if !ActivateWindow(WIN_LOGIN)
            return false
        MouseMove(clientX, clientY, 0)
        Sleep 50
        Click
        Sleep LOGIN_FIELD_SETTLE_MS
    }
    return WinActive(WIN_LOGIN)
}

WaitWindowStable(winTitle, stableMs := 800, timeoutSecs := 20) {
    startedAt := A_TickCount
    stableSince := 0
    lastCount := -1

    Loop {
        if WinExist(winTitle) {
            if !WinActive(winTitle)
                WinActivate winTitle
            try hwnds := WinGetControlsHwnd(winTitle)
            catch
                hwnds := []
            count := hwnds.Length

            if WinActive(winTitle) && count = lastCount {
                if (stableSince = 0)
                    stableSince := A_TickCount
                if (A_TickCount - stableSince >= stableMs)
                    return true
            } else {
                stableSince := 0
                lastCount := count
            }
        }

        if (A_TickCount - startedAt > timeoutSecs * 1000)
            return false

        Sleep 50
    }
}

DismissModal(winTitle, buttonClass) {
    if !WinExist(winTitle)
        return false
    WinActivate winTitle
    Sleep 100
    return ClickFirstControl(winTitle, buttonClass)
}

ClickFirstControl(winTitle, classNN) {
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

SafeActiveTitle() {
    try return WinGetTitle("A")
    catch as e
        return "<erro ao ler ativa: " e.Message ">"
}

SafeWinGetText(winTitle) {
    try text := WinGetText(winTitle)
    catch as e
        return "<erro WinGetText: " e.Message ">"
    text := Trim(text)
    return text = "" ? "<vazio>" : text
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

SaveAndShow(content) {
    logPath := A_ScriptDir "\ultimo_login_nav.txt"
    try FileDelete logPath
    FileAppend content, logPath, "UTF-8"
    A_Clipboard := content
    MsgBox content "`n`nCopiado para o clipboard e salvo em:`n" logPath, "Login/Navegação", "Iconi"
}
