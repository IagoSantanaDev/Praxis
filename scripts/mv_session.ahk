#Requires AutoHotkey v2.0

SetTitleMatchMode 2
DetectHiddenText true
SetControlDelay 0
SetWinDelay 0
SetKeyDelay 0, 0

; ════════════════════════════════════════════════════════════════
;  MV SESSION — módulo compartilhado
; ════════════════════════════════════════════════════════════════

; ── Executável e janelas ──────────────────────────────────────
MV_RUN_FFCV       := 'C:\orant\BIN\ifrun60.EXE E:\Mv2000\ffcv\ffcv.fmx'
MV_RUN_MOVDOC     := 'C:\orant\BIN\ifrun60.EXE E:\Mv2000\movdoc\movdoc.fmx'
MV_WIN_LOGIN      := "Identificação ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"

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
MV_IMG_ERROR_ICON     := MV_IMG_DIR "\Erro_Icone.png"

; ── Polling ───────────────────────────────────────────────────
MV_POLL_MS      := 50
MV_TIMEOUT_LOAD := 20
MV_TIMEOUT_ACOE := 10
MV_DELAY_INPUT  := 80

; ════════════════════════════════════════════════════════════════
;  API PÚBLICA
; ════════════════════════════════════════════════════════════════

MV_EnsureMovDoc() {
    if MV_ModuleReady(MV_WIN_MOVDOC_ANY) {
        MV_ActivateModule(MV_WIN_MOVDOC_ANY)
        return true
    }

    MV_AbrirMovDoc()
    return MV_LoginOpenedModule(MV_WIN_MOVDOC_ANY, "MOV DOC")
}

MV_EnsureFFCV() {
    if MV_ModuleReady(MV_WIN_FFCV_ANY) {
        MV_ActivateModule(MV_WIN_FFCV_ANY)
        return true
    }

    MV_AbrirFFCV()
    return MV_LoginOpenedModule(MV_WIN_FFCV_ANY, "FFCV")
}

MV_AbrirMovDoc() {
    Run MV_RUN_MOVDOC
}

MV_AbrirFFCV() {
    Run MV_RUN_FFCV
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

; Login principal: teclado somente.
; O campo Usuário já abre focado no MV.
MV_DoLoginKeyboard(moduleWin, moduleName) {
    global gUser, gPass

    if (Trim(gUser) = "" || gPass = "")
        return MV_RequestNewCredentials("Credenciais não carregadas. Informe usuário e senha.")

    WinActivate MV_WIN_LOGIN
    if !MV_Poll(() => WinActive(MV_WIN_LOGIN), 5)
        return false

    SendText gUser
    Sleep MV_DELAY_INPUT
    Send "{Tab}"
    Sleep MV_DELAY_INPUT
    SendText gPass
    Sleep MV_DELAY_INPUT
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
    return MV_ImageVisible(MV_IMG_ERROR_ICON)
}

MV_DismissActivePopup() {
    try {
        if WinExist("ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE") {
            WinActivate "ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"
            Sleep MV_DELAY_INPUT
            Send "{Enter}"
        }
    }
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

MV_ClickImage(imagePath, variation := 10, offsetX := 8, offsetY := 8) {
    if !FileExist(imagePath)
        return false

    CoordMode "Pixel", "Screen"
    CoordMode "Mouse", "Screen"
    try {
        if ImageSearch(&x, &y, 0, 0, A_ScreenWidth, A_ScreenHeight, "*" variation " " imagePath) {
            Click x + offsetX, y + offsetY
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

MV_ReadTextControlAt(winTitle, classNN, clientX, clientY, tolerance := 14) {
    A_Clipboard := ""
    if !MV_DoubleClickControlAt(winTitle, classNN, clientX, clientY, tolerance)
        return ""
    Sleep MV_DELAY_INPUT
    Send "^c"
    MV_Poll(() => A_Clipboard != "", 3)
    return Trim(A_Clipboard)
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
