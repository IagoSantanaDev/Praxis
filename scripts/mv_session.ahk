#Requires AutoHotkey v2.0

SetTitleMatchMode 2
DetectHiddenText true
SetControlDelay 0
SetWinDelay 0
SetKeyDelay 0, 0

; ════════════════════════════════════════════════════════════════
;  MV SESSION — módulo compartilhado
; ════════════════════════════════════════════════════════════════

; ── Executável, atalhos e janelas ─────────────────────────────
MV_PROJECT_ROOT   := RegExReplace(A_ScriptDir, "\\scripts$", "")
MV_SHORTCUT_DIR   := MV_PROJECT_ROOT "\atalhos"
MV_MOVDOC_LNK     := MV_SHORTCUT_DIR "\MOVDOC.lnk"
MV_FFCV_LNK       := MV_SHORTCUT_DIR "\FFCV.lnk"
MV_WIN_LOGIN      := "Identificação ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"
MV_WIN_LOGIN_ERROR := "Mensagem do MV2000 ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"

; Atenção: para detecção inicial, nunca exigir subtela exata.
; O usuário pode ter deixado MOV DOC/FFCV aberto em qualquer tela interna.
MV_WIN_MOVDOC_ANY := "Movimentação de Documentos ahk_exe ifrun60.EXE"
MV_WIN_FFCV_ANY   := "MV2000i - Faturamento ahk_exe ifrun60.EXE"

; Títulos específicos só devem ser usados depois de navegar para a tela esperada.
MV_WIN_MOVDOC_BAIXA := "Protocolação de Baixa de Documentos ahk_exe ifrun60.EXE"
MV_WIN_FFCV_REMESSA := "Manutenção de Remessa ahk_exe ifrun60.EXE"
MV_WIN_FFCV         := MV_WIN_FFCV_ANY
MV_WIN_MOVDOC       := MV_WIN_MOVDOC_ANY

; ── Imagens de referência ─────────────────────────────────────
MV_IMG_DIR            := A_ScriptDir "\Imagens_Debug"

; ── Controles de popups conhecidos ────────────────────────────
MV_MODAL_OK_CLASS := "Button1"

; ── Login Identificação em coordenadas Client ──────────────────
; Window Spy validado nas capturas Tela Login Usuario/Senha.
; Não usar ClassNN para diferenciar campos: usuário e senha aparecem como Edit2.
MV_LOGIN_USER_X := 170
MV_LOGIN_USER_Y := 118
MV_LOGIN_PASS_X := 307
MV_LOGIN_PASS_Y := 119

; ── Polling ───────────────────────────────────────────────────
MV_POLL_MS      := 50
MV_TIMEOUT_LOAD := 20
MV_TIMEOUT_ACOE := 10
MV_DELAY_INPUT  := 50

; ════════════════════════════════════════════════════════════════
;  API PÚBLICA
; ════════════════════════════════════════════════════════════════

MV_EnsureMovDoc() {
    if MV_ModuleReady(MV_WIN_MOVDOC_ANY) {
        MV_ActivateModule(MV_WIN_MOVDOC_ANY)
        return true
    }

    if !MV_AbrirMovDoc()
        return false
    return MV_LoginOpenedModule(MV_WIN_MOVDOC_ANY, "MOV DOC")
}

MV_EnsureFFCV() {
    if MV_ModuleReady(MV_WIN_FFCV_ANY) {
        MV_ActivateModule(MV_WIN_FFCV_ANY)
        return true
    }

    if !MV_AbrirFFCV()
        return false
    return MV_LoginOpenedModule(MV_WIN_FFCV_ANY, "FFCV")
}

MV_AbrirMovDoc() {
    if !FileExist(MV_MOVDOC_LNK)
        return false
    Run MV_MOVDOC_LNK, MV_SHORTCUT_DIR
    return true
}

MV_AbrirFFCV() {
    if !FileExist(MV_FFCV_LNK)
        return false
    Run MV_FFCV_LNK, MV_SHORTCUT_DIR
    return true
}

; ════════════════════════════════════════════════════════════════
;  LOGIN
; ════════════════════════════════════════════════════════════════

MV_LoginOpenedModule(moduleWin, moduleName) {
    if !MV_Poll(() => WinExist(MV_WIN_LOGIN) || MV_ModuleReady(moduleWin), MV_TIMEOUT_LOAD)
        return MV_RequestNewCredentials("Não consegui abrir a tela de login do " moduleName ".")

    if WinExist(MV_WIN_LOGIN) {
        if !MV_DoLoginKeyboard(moduleWin, moduleName)
            return false
    }

    if !MV_Poll(() => MV_ModuleReady(moduleWin), MV_TIMEOUT_LOAD)
        return MV_RequestNewCredentials("Login enviado, mas o " moduleName " não ficou disponível.")

    MV_ActivateModule(moduleWin)
    return true
}

; Login principal: ativar a janela e clicar nos campos por coordenada Client validada.
; Não depender de foco inicial nem de ClassNN: usuário e senha podem aparecer ambos como Edit2.
MV_DoLoginKeyboard(moduleWin, moduleName) {
    global gUser, gPass

    if (Trim(gUser) = "" || gPass = "")
        return MV_RequestNewCredentials("Credenciais não carregadas. Informe usuário e senha.")

    if !MV_ActivateLoginWindow()
        return false

    if !MV_ClickLoginField(MV_LOGIN_USER_X, MV_LOGIN_USER_Y)
        return false
    MV_SendLoginText(gUser)

    if !MV_ClickLoginField(MV_LOGIN_PASS_X, MV_LOGIN_PASS_Y)
        return false
    MV_SendLoginText(gPass)
    Send "{Enter}"

    deadline := A_TickCount + MV_TIMEOUT_LOAD * 1000
    Loop {
        if MV_LoginErrorVisible() {
            MV_DismissActivePopup()
            Sleep MV_DELAY_INPUT
            MV_CloseModule(moduleWin)
            return MV_RequestNewCredentials("O MV recusou o login. Informe novas credenciais.")
        }

        if MV_ModuleReady(moduleWin)
            return true

        if (A_TickCount > deadline)
            return false

        Sleep MV_POLL_MS
    }
}

MV_LoginErrorVisible() {
    return WinExist(MV_WIN_LOGIN_ERROR)
}

MV_ActivateLoginWindow() {
    if !WinExist(MV_WIN_LOGIN)
        return false

    WinActivate MV_WIN_LOGIN
    return MV_Poll(() => WinActive(MV_WIN_LOGIN), 5)
}

MV_ClickLoginField(clientX, clientY) {
    if !MV_ActivateLoginWindow()
        return false

    CoordMode("Mouse", "Client")
    Click(clientX, clientY, 1)
    Sleep 20
    return true
}

MV_SendLoginText(value) {
    SendText value
    Sleep 20
}

MV_DismissActivePopup() {
    try {
        if WinExist(MV_WIN_LOGIN_ERROR) {
            WinActivate MV_WIN_LOGIN_ERROR
            Sleep MV_DELAY_INPUT
            return MV_ClickFirstControl(MV_WIN_LOGIN_ERROR, MV_MODAL_OK_CLASS)
        }
    }
    return false
}

MV_RequestNewCredentials(message) {
    global gUser, gPass, gRunning
    gUser := ""
    gPass := ""
    gRunning := false

    try SendToUI(Map("type", "login_failed", "message", message))
    catch {
        try SendToUI(Map("type", "show_login", "message", message))
    }
    return false
}

MV_CloseModule(moduleWin) {
    try {
        if WinExist(moduleWin) {
            WinActivate moduleWin
            WinClose moduleWin
        }
    }
}

; ════════════════════════════════════════════════════════════════
;  DETECÇÃO / IMAGEM / CONTROLES
; ════════════════════════════════════════════════════════════════

MV_ModuleReady(moduleWin) {
    return MV_WinReady(moduleWin)
}

MV_ActivateModule(moduleWin) {
    if WinExist(moduleWin) {
        WinActivate moduleWin
        MV_Poll(() => WinActive(moduleWin), 3)
    }
}

MV_WinReady(title) {
    if !WinExist(title)
        return false
    return WinGetMinMax(title) != -1
}

MV_ImageVisible(imagePath, variation := 10) {
    if !FileExist(imagePath)
        return false

    CoordMode "Pixel", "Screen"
    try return ImageSearch(&x, &y, 0, 0, A_ScreenWidth, A_ScreenHeight, "*" variation " " imagePath)
    catch
        return false
}

MV_ClickImage(imagePath, variation := 10, offsetX := 8, offsetY := 8, winTitle := "") {
    if !FileExist(imagePath)
        return false

    CoordMode "Pixel", "Screen"
    CoordMode "Mouse", "Screen"

    x1 := 0, y1 := 0, x2 := A_ScreenWidth, y2 := A_ScreenHeight
    if (winTitle != "" && WinExist(winTitle)) {
        WinGetPos &wx, &wy, &ww, &wh, winTitle
        x1 := wx, y1 := wy, x2 := wx + ww, y2 := wy + wh
    }

    try {
        if ImageSearch(&x, &y, x1, y1, x2, y2, "*" variation " " imagePath) {
            Click x + offsetX, y + offsetY
            return true
        }
    }
    return false
}

MV_ClickCachedImage(cacheKey, imagePath, winTitle, variation := 10, offsetX := 8, offsetY := 8) {
    cfgPath := A_ScriptDir "\config.ini"

    if (winTitle != "" && WinExist(winTitle)) {
        WinGetPos &wx, &wy, &ww, &wh, winTitle
        cachedX := IniRead(cfgPath, "ImageCache", cacheKey "_x", "")
        cachedY := IniRead(cfgPath, "ImageCache", cacheKey "_y", "")

        if (cachedX != "" && cachedY != "") {
            CoordMode "Mouse", "Screen"
            Click wx + (cachedX + 0), wy + (cachedY + 0)
            return true
        }
    }

    if !FileExist(imagePath)
        return false

    CoordMode "Pixel", "Screen"
    CoordMode "Mouse", "Screen"

    x1 := 0, y1 := 0, x2 := A_ScreenWidth, y2 := A_ScreenHeight
    hasWindow := (winTitle != "" && WinExist(winTitle))
    if hasWindow {
        WinGetPos &wx, &wy, &ww, &wh, winTitle
        x1 := wx, y1 := wy, x2 := wx + ww, y2 := wy + wh
    }

    try {
        if ImageSearch(&x, &y, x1, y1, x2, y2, "*" variation " " imagePath) {
            clickX := x + offsetX
            clickY := y + offsetY
            Click clickX, clickY

            if hasWindow {
                relX := clickX - wx
                relY := clickY - wy
                IniWrite relX, cfgPath, "ImageCache", cacheKey "_x"
                IniWrite relY, cfgPath, "ImageCache", cacheKey "_y"
            }
            return true
        }
    }
    return false
}

MV_DoubleClickControlAt(winTitle, classNN, clientX, clientY, tolerance := 14) {
    hwnd := MV_FindControlByClientPoint(winTitle, classNN, clientX, clientY, tolerance)
    if !hwnd
        return false
    ControlClick hwnd,,,, 2, "NA"
    return true
}

MV_ClickControlAt(winTitle, classNN, clientX, clientY, tolerance := 14) {
    hwnd := MV_FindControlByClientPoint(winTitle, classNN, clientX, clientY, tolerance)
    if !hwnd
        return false
    ControlClick hwnd,,,,, "NA"
    return true
}

MV_ClickFirstControl(winTitle, classNN) {
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

MV_FocusControlAt(winTitle, classNN, clientX, clientY, tolerance := 14) {
    hwnd := MV_FindControlByClientPoint(winTitle, classNN, clientX, clientY, tolerance)
    if !hwnd
        return false
    ControlFocus hwnd
    return true
}

MV_SetTextControlAt(winTitle, classNN, clientX, clientY, value, tolerance := 14) {
    hwnd := MV_FindControlByClientPoint(winTitle, classNN, clientX, clientY, tolerance)
    if !hwnd
        return false
    ControlFocus hwnd
    Sleep MV_DELAY_INPUT
    SendText value
    return true
}

MV_SetTextEditAtPoint(winTitle, clientX, clientY, value, tolerance := 14) {
    hwnd := MV_FindEditByClientPoint(winTitle, clientX, clientY, tolerance)
    if !hwnd
        return false

    WinActivate winTitle
    MV_Poll(() => WinActive(winTitle), 2)
    CoordMode("Mouse", "Client")
    Click(clientX + 15, clientY + 8, 1)
    Sleep 20
    Send "{Home}{Shift down}{End}{Shift up}{Backspace}"
    Sleep 20
    SendText value
    return true
}

MV_FocusEditAtPoint(winTitle, clientX, clientY, tolerance := 14) {
    hwnd := MV_FindEditByClientPoint(winTitle, clientX, clientY, tolerance)
    if !hwnd
        return false

    WinActivate winTitle
    MV_Poll(() => WinActive(winTitle), 2)
    ControlFocus hwnd
    return true
}

MV_ReadEditAtPoint(winTitle, clientX, clientY, expectedPattern := "", tolerance := 14) {
    hwnd := MV_FindEditByClientPoint(winTitle, clientX, clientY, tolerance)
    if !hwnd
        return ""

    try text := Trim(ControlGetText(hwnd))
    catch
        return ""

    return MV_TextMatchesExpected(text, expectedPattern) ? text : ""
}

MV_TextMatchesExpected(text, expectedPattern := "") {
    if (text = "")
        return false
    if (expectedPattern = "")
        return true
    return RegExMatch(text, expectedPattern)
}

MV_FindEditByClientPoint(winTitle, targetX, targetY, tolerance := 14) {
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

MV_ControlCheckedAt(winTitle, classNN, clientX, clientY, tolerance := 14) {
    hwnd := MV_FindControlByClientPoint(winTitle, classNN, clientX, clientY, tolerance)
    if !hwnd
        return ""

    try return ControlGetChecked(hwnd)
    catch
        return ""
}

MV_FindControlByClientPoint(winTitle, classNN, targetX, targetY, tolerance := 14) {
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

MV_Poll(condFn, timeoutSecs) {
    deadline := A_TickCount + timeoutSecs * 1000
    Loop {
        if condFn()
            return true
        if A_TickCount > deadline
            return false
        Sleep MV_POLL_MS
    }
}

MV_WaitAnyWindow(titles, timeoutSecs) {
    deadline := A_TickCount + timeoutSecs * 1000
    Loop {
        for title in titles {
            if WinExist(title)
                return title
        }
        if A_TickCount > deadline
            return ""
        Sleep MV_POLL_MS
    }
}
