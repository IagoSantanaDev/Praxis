; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug

; Motor de sincronização orientado ao estado observável da interface MV.
; Sleep é usado apenas para espaçar polling; término de transição nunca é
; inferido de um atraso fixo.

MV_CaptureScreenState(winTitle := "") {
    hwnd := winTitle = "" ? WinExist("A") : WinExist(winTitle)
    if !hwnd
        return Map("hwnd", 0, "signature", "", "exists", false)

    return Map(
        "hwnd", hwnd,
        "capturedAt", A_TickCount,
        "exists", true,
        "signature", MV_GetScreenSignature(hwnd),
        "title", MV_SafeWinTitle(hwnd),
        "class", MV_SafeWinClass(hwnd),
        "process", MV_SafeWinProcess(hwnd))
}

MV_GetScreenSignature(hwnd) {
    if !hwnd
        return ""

    title := MV_SafeWinTitle(hwnd)
    className := MV_SafeWinClass(hwnd)
    process := MV_SafeWinProcess(hwnd)
    controls := ""
    focus := MV_SafeFocusedControl(hwnd)

    try controlNames := WinGetControls(hwnd)
    catch
        controlNames := []

    for _, control in controlNames {
        text := ""
        enabled := ""
        visible := ""
        try text := ControlGetText(control, hwnd)
        try enabled := ControlGetEnabled(control, hwnd) ? "1" : "0"
        try visible := ControlGetVisible(control, hwnd) ? "1" : "0"
        controls .= "|" control ":" SubStr(text, 1, 160) ":" enabled ":" visible
    }

    return hwnd ";" process ";" className ";" title ";focus=" focus ";" controls
}

MV_SafeFocusedControl(hwnd) {
    try return ControlGetFocus(hwnd)
    catch
        return ""
}

MV_GetFocusedControlText(winTitle) {
    try {
        control := ControlGetFocus(winTitle)
        return control = "" ? "" : ControlGetText(control, winTitle)
    } catch {
        return ""
    }
}

MV_WaitScreenChanged(previousState, timeoutMs := MV_DEFAULT_TIMEOUT_MS, winTitle := "") {
    startedAt := A_TickCount
    previousSignature := previousState is Map ? previousState["signature"] : String(previousState)
    previousHwnd := previousState is Map && previousState.Has("hwnd") ? previousState["hwnd"] : 0

    Loop {
        ThrowIfAppStopped()
        current := MV_CaptureScreenState(winTitle)
        if (current["exists"] && (current["hwnd"] != previousHwnd || current["signature"] != previousSignature)) {
            MV_Log("MV_WaitScreenChanged", "mudanca detectada em " (A_TickCount - startedAt) "ms", true)
            return current
        }
        if (A_TickCount - startedAt >= timeoutMs) {
            MV_Log("MV_WaitScreenChanged", "timeout=" timeoutMs "ms assinatura=" previousSignature, false)
            return false
        }
        Sleep MV_POLL_MS
    }
}

MV_WaitScreenStable(winTitle := "", stableMs := MV_DEFAULT_STABLE_MS, timeoutMs := MV_DEFAULT_TIMEOUT_MS) {
    startedAt := A_TickCount
    stableSince := 0
    lastSignature := ""

    Loop {
        ThrowIfAppStopped()
        current := MV_CaptureScreenState(winTitle)
        signature := current["signature"]
        if (current["exists"] && signature != "") {
            if (signature = lastSignature) {
                if (stableSince = 0)
                    stableSince := A_TickCount
                if (A_TickCount - stableSince >= stableMs) {
                    MV_Log("MV_WaitScreenStable", "estavel em " (A_TickCount - startedAt) "ms", true)
                    return current
                }
            } else {
                lastSignature := signature
                stableSince := A_TickCount
            }
        } else {
            lastSignature := ""
            stableSince := 0
        }

        if (A_TickCount - startedAt >= timeoutMs) {
            MV_Log("MV_WaitScreenStable", "timeout=" timeoutMs "ms", false)
            return false
        }
        Sleep MV_POLL_MS
    }
}

MV_WaitScreenChangedAndStable(previousState, winTitle := "", stableMs := MV_DEFAULT_STABLE_MS, timeoutMs := MV_DEFAULT_TIMEOUT_MS) {
    changed := MV_WaitScreenChanged(previousState, timeoutMs, winTitle)
    if !changed
        return false

    elapsed := A_TickCount
    startedAt := previousState is Map && previousState.Has("capturedAt") ? previousState["capturedAt"] : elapsed
    remaining := Max(timeoutMs - (elapsed - startedAt), 1)
    return MV_WaitScreenStable(winTitle, stableMs, remaining)
}

MV_WaitExpectedState(expectedFn, winTitle := "", timeoutMs := MV_DEFAULT_TIMEOUT_MS, description := "estado esperado") {
    startedAt := A_TickCount
    Loop {
        ThrowIfAppStopped()
        current := MV_CaptureScreenState(winTitle)
        if (current["exists"] && expectedFn(current["hwnd"], current)) {
            MV_Log("MV_WaitExpectedState", description " em " (A_TickCount - startedAt) "ms", true)
            return current
        }
        if (A_TickCount - startedAt >= timeoutMs) {
            MV_Log("MV_WaitExpectedState", "timeout=" timeoutMs "ms " description, false)
            return false
        }
        Sleep MV_POLL_MS
    }
}

MV_WaitWindowChanged(previousState, timeoutMs := MV_DEFAULT_TIMEOUT_MS) {
    return MV_WaitScreenChanged(previousState, timeoutMs)
}

MV_WaitWindowClosed(winTitle, timeoutMs := MV_DEFAULT_TIMEOUT_MS) {
    startedAt := A_TickCount
    Loop {
        ThrowIfAppStopped()
        if !WinExist(winTitle) {
            MV_Log("MV_WaitWindowClosed", winTitle " fechada em " (A_TickCount - startedAt) "ms", true)
            return true
        }
        if (A_TickCount - startedAt >= timeoutMs) {
            MV_Log("MV_WaitWindowClosed", "timeout=" timeoutMs "ms " winTitle, false)
            return false
        }
        Sleep MV_POLL_MS
    }
}

MV_ActAndWait(winTitle, actionFn, timeoutMs := MV_DEFAULT_TIMEOUT_MS, expectedFn := unset, description := "ação") {
    before := MV_CaptureScreenState(winTitle)
    if !actionFn()
        return false

    changed := MV_WaitScreenChanged(before, timeoutMs, winTitle)
    if !changed
        return false
    if !MV_WaitScreenStable(winTitle, MV_TARGET_STABLE_MS, timeoutMs)
        return false
    if IsSet(expectedFn)
        return MV_WaitExpectedState(expectedFn, winTitle, timeoutMs, description)
    return changed
}

MV_ClickAndWait(winTitle, classNN, x, y, timeoutMs := MV_DEFAULT_TIMEOUT_MS, expectedFn := unset, description := "clique") {
    return MV_ActAndWait(winTitle, () => MV_ClickControlAt(winTitle, classNN, x, y), timeoutMs, expectedFn, description)
}

MV_ClickAtAndWait(winTitle, x, y, timeoutMs := MV_DEFAULT_TIMEOUT_MS, expectedFn := unset, description := "clique físico") {
    return MV_ActAndWait(winTitle, () => MV_ClickAt(winTitle, x, y), timeoutMs, expectedFn, description)
}

MV_ClickAt(winTitle, x, y) {
    if !WinExist(winTitle)
        return false
    try {
        WinActivate winTitle
        Click(x, y, 1)
        return true
    } catch {
        return false
    }
}

MV_ClickHwnd(hwnd) {
    try {
        ControlClick hwnd,,,,, "NA"
        return true
    } catch {
        return false
    }
}

MV_ClickHwndAndWait(winTitle, hwnd, timeoutMs := MV_DEFAULT_TIMEOUT_MS, expectedFn := unset, description := "controle acionado") {
    return MV_ActAndWait(winTitle, () => MV_ClickHwnd(hwnd), timeoutMs, expectedFn, description)
}

MV_ClickModalAndWait(modalTitle, hwnd, timeoutMs := MV_DEFAULT_TIMEOUT_MS, parentTitle := "", description := "modal respondido") {
    if !MV_ClickHwnd(hwnd)
        return false
    if !MV_WaitWindowClosed(modalTitle, timeoutMs)
        return false
    if (parentTitle != "" && !MV_WaitScreenStable(parentTitle, MV_TARGET_STABLE_MS, timeoutMs))
        return false
    MV_Log("MV_ClickModalAndWait", description, true)
    return true
}

MV_SendAndWait(winTitle, keys, timeoutMs := MV_DEFAULT_TIMEOUT_MS, expectedFn := unset, description := "atalho") {
    return MV_ActAndWait(winTitle, () => MV_Send(keys), timeoutMs, expectedFn, description)
}

MV_Send(keys) {
    Send keys
    return true
}

MV_SendTextAndWait(winTitle, text, timeoutMs := MV_DEFAULT_TIMEOUT_MS, expectedFn := unset, description := "texto") {
    return MV_ActAndWait(winTitle, () => MV_SendText(text), timeoutMs, expectedFn, description)
}

MV_SendText(text) {
    SendText text
    return true
}

MV_SetTextAndWait(winTitle, x, y, text, timeoutMs := MV_DEFAULT_TIMEOUT_MS, expectedFn := unset, description := "campo preenchido") {
    return MV_ActAndWait(winTitle, () => MV_SetTextAction(winTitle, x, y, text), timeoutMs, expectedFn, description)
}

MV_SetTextAction(winTitle, x, y, text) {
    if !MV_ClickAt(winTitle, x, y)
        return false
    Send("{Home}{Shift down}{End}{Shift up}{Backspace}")
    SendText text
    return true
}

MV_SendFunctionAndWait(winTitle, functionKey, timeoutMs := MV_DEFAULT_TIMEOUT_MS, expectedFn := unset, description := "tecla funcional") {
    return MV_SendAndWait(winTitle, "{" functionKey "}", timeoutMs, expectedFn, description)
}

MV_SendEnterAndWait(winTitle, timeoutMs := MV_DEFAULT_TIMEOUT_MS, expectedFn := unset, description := "Enter") {
    return MV_SendAndWait(winTitle, "{Enter}", timeoutMs, expectedFn, description)
}

MV_CloseWindowAndWait(winTitle, actionFn, parentTitle := "", timeoutMs := MV_DEFAULT_TIMEOUT_MS, description := "janela fechada") {
    if !actionFn()
        return false
    if !MV_WaitWindowClosed(winTitle, timeoutMs)
        return false
    if (parentTitle != "") {
        if !MV_WaitScreenStable(parentTitle, MV_TARGET_STABLE_MS, timeoutMs)
            return false
    }
    MV_Log("MV_CloseWindowAndWait", description, true)
    return true
}

MV_SafeWinTitle(hwnd) {
    try return WinGetTitle(hwnd)
    catch
        return ""
}

MV_SafeWinClass(hwnd) {
    try return WinGetClass(hwnd)
    catch
        return ""
}

MV_SafeWinProcess(hwnd) {
    try return WinGetProcessName(hwnd)
    catch
        return ""
}
