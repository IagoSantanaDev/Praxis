; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

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
MV_WIN_IDENTIFICACAO := "Identificação ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"

; Atenção: para detecção inicial, nunca exigir subtela exata.
; O usuário pode ter deixado MOV DOC/FFCV aberto em qualquer tela interna.
MV_WIN_MOVDOC_ANY := "Movimentação ahk_exe ifrun60.EXE"
; Detectar FFCV pelo executável e título principal para evitar dependência de subtela.
MV_WIN_FFCV_ANY   := "Faturamento ahk_exe ifrun60.EXE"

; Títulos específicos só devem ser usados depois de navegar para a tela esperada.
MV_WIN_MOVDOC_BAIXA := "Protocolação de Baixa de Documentos ahk_exe ifrun60.EXE"
MV_WIN_FFCV_REMESSA := "MV2000i - Faturamento ahk_exe ifrun60.EXE"
MV_WIN_FFCV         := MV_WIN_FFCV_ANY
MV_WIN_MOVDOC       := MV_WIN_MOVDOC_ANY

; ── Controles de popups conhecidos ────────────────────────────
MV_MODAL_OK_CLASS := "Button1"

; ── Polling / estabilidade ────────────────────────────────────
MV_POLL_MS          := 100
MV_TIMEOUT_LOAD     := 100
MV_TIMEOUT_ACOE     := 100
MV_DELAY_INPUT      := 100
MV_MODULE_STABLE_MS := 600
MV_TARGET_STABLE_MS := 600

; ════════════════════════════════════════════════════════════════
;  API PÚBLICA
; ════════════════════════════════════════════════════════════════

MV_EnsureMovDoc() {
    if WinExist(MV_WIN_MOVDOC_ANY) {
        MV_ActivateModule(MV_WIN_MOVDOC_ANY)
        if MV_WaitWindowStable(MV_WIN_MOVDOC_ANY, MV_MODULE_STABLE_MS, MV_TIMEOUT_LOAD)
            return true
        ; se a janela de identificação aparecer, a automação não prossegue
    }

    if WinExist(MV_WIN_IDENTIFICACAO)
        return MV_AbortAuthenticationRequired("MOV DOC")

    ; Não abrir novo MOV DOC via atalho. Se não estiver aberto, abortar.
    return false
}

MV_EnsureFFCV() {
    if WinExist(MV_WIN_FFCV_ANY) {
        MV_ActivateModule(MV_WIN_FFCV_ANY)
        if MV_WaitWindowStable(MV_WIN_FFCV_ANY, MV_MODULE_STABLE_MS, MV_TIMEOUT_LOAD)
            return true
        ; se a janela de identificação aparecer, a automação não prossegue
    }

    if WinExist(MV_WIN_IDENTIFICACAO)
        return MV_AbortAuthenticationRequired("FFCV")

    ; Não abrir novo FFCV via atalho. Se não estiver aberto, abortar.
    return false
}

MV_AbrirMovDoc() {
    ; Abertura por atalho está desabilitada neste fluxo.
    return false
}

MV_AbrirFFCV() {
    ; Abertura por atalho está desabilitada neste fluxo.
    return false
}

; ════════════════════════════════════════════════════════════════
;  AUTENTICAÇÃO AUTOMÁTICA DESABILITADA
; ════════════════════════════════════════════════════════════════

MV_AbortAuthenticationRequired(moduleName) {
    global gRunning
    gRunning := false

    message := "O Praxis não executa autenticação automática. Abra e autentique o " moduleName " manualmente no MV2000i antes de iniciar a automação."
    try SendToUI(Map("type", "error", "message", message))
    return false
}

; ════════════════════════════════════════════════════════════════
;  DETECÇÃO / CONTROLES
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

MV_WaitWindowStable(winTitle, stableMs := 600, timeoutSecs := 20) {
    startedAt := A_TickCount
    stableSince := 0
    lastCount := -1

    Loop {
        if WinExist(winTitle) {
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
