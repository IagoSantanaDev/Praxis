; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug

; ════════════════════════════════════════════════════════════════
;  MV CONTROLS — helpers de deteccao e interacao
; ════════════════════════════════════════════════════════════════

; ════════════════════════════════════════════════════════════════
;  DETECCAO / CONTROLES
; ════════════════════════════════════════════════════════════════

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
    hwnd := MV_FirstControlByClass(winTitle, classNN)
    if !hwnd
        return false
    ControlClick hwnd,,,,, "NA"
    return true
}

MV_ControlCheckedAt(winTitle, classNN, clientX, clientY, tolerance := 14) {
    hwnd := MV_FindControlByClientPoint(winTitle, classNN, clientX, clientY, tolerance)
    if !hwnd
        return ""

    try return ControlGetChecked(hwnd)
    catch
        return ""
}

MV_Poll(condFn, timeoutSecs) {
    global MV_POLL_MS
    deadline := A_TickCount + timeoutSecs * 1000
    Loop {
        ThrowIfAppStopped()
        if condFn()
            return true
        if A_TickCount > deadline
            return false
        Sleep MV_POLL_MS
    }
}

; Centraliza o logging interno de Dialogs/Popups/FfcvContaPopup, 
; substituindo três helpers duplicadas sem alterar o padrão de saída.
MV_Log(funcName, detail, result) {
    try {
        if (result)
            Log_Info(funcName " => OK  " detail)
        else
            Log_Warn(funcName " => FALHOU  " detail)
    }
}

; Aguarda o Oracle Forms estabilizar, substituindo duas funções duplicadas e idênticas por um helper único.
MV_WaitOracleSettled(winTitle, stableMs := MV_ORACLE_STABLE_MS, timeoutMs := MV_DEFAULT_TIMEOUT_MS) {
    startedAt := A_TickCount
    stableSince := 0
    lastCount := -1

    Loop {
        ThrowIfAppStopped()
        modalClear := (Dialog_ActiveModalTitle() = "")
        cursorReady := (A_Cursor != "Wait" && A_Cursor != "AppStarting")
        exists := WinExist(winTitle)
        count := -1
        enumerated := false
        if exists {
            try {
                hwnds := WinGetControlsHwnd(winTitle)
                count := hwnds.Length
                enumerated := true
            } catch {
            }
        }
        if (exists && enumerated && modalClear && cursorReady && count = lastCount) {
            if (stableSince = 0)
                stableSince := A_TickCount
            if (A_TickCount - stableSince >= stableMs)
                return true
        } else {
            stableSince := 0
            lastCount := count
        }
        if (A_TickCount - startedAt >= timeoutMs)
            return false
        Sleep MV_POLL_MS
    }
}

MV_WaitWindowStable(winTitle, stableMs := MV_DEFAULT_STABLE_MS, timeoutSecs := MV_DEFAULT_TIMEOUT_SECS) {
    global MV_POLL_MS
    startedAt := A_TickCount
    stableSince := 0
    lastCount := -1

    Loop {
        ThrowIfAppStopped()
        if WinExist(winTitle) {
            WinActivate winTitle
            enumerated := false
            try {
                hwnds := WinGetControlsHwnd(winTitle)
                count := hwnds.Length
                enumerated := true
            } catch {
                count := -1
            }

            if WinActive(winTitle) && enumerated && count = lastCount {
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

; ════════════════════════════════════════════════════════════════
;  HELPERS CANÔNICOS (consolidados 2026-09-09)
;  Versões únicas de helpers que existiam duplicadas entre screens
;  e test_macros. Fonte única — os callers devem chamar estas funções.
; ════════════════════════════════════════════════════════════════

; Extende a busca por ponto com prefixo de ClassNN.
; Busca por ponto com prefixo de ClassNN. classPrefix="" (default)
; busca por classe exata;
; classPrefix="Edit"/"ComboBox"/"ui60Drawn" = prefixo.
MV_FindControlAtPoint(winTitle, classNN, targetX, targetY, tolerance := 14, classPrefix := "") {
    try hwnds := WinGetControlsHwnd(winTitle)
    catch
        return 0

    bestHwnd := 0
    bestDist := 999999

    for hwnd in hwnds {
        try ctrlClass := ControlGetClassNN(hwnd)
        catch
            continue

        if (classPrefix != "") {
            if (SubStr(ctrlClass, 1, StrLen(classPrefix)) != classPrefix)
                continue
        } else if (ctrlClass != classNN) {
            continue
        }

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

; MV_FindControlByClientPoint (classe exata) delega para MV_FindControlAtPoint.
MV_FindControlByClientPoint(winTitle, classNN, targetX, targetY, tolerance := 14) {
    return MV_FindControlAtPoint(winTitle, classNN, targetX, targetY, tolerance, "")
}

; Primeiro controle com a classe ClassNN exata na janela (hwnd ou 0).
; Base única para localizar o primeiro controle por ClassNN.
MV_FirstControlByClass(winTitle, classNN) {
    try hwnds := WinGetControlsHwnd(winTitle)
    catch
        return 0

    for hwnd in hwnds {
        try ctrlClass := ControlGetClassNN(hwnd)
        catch
            continue
        if (ctrlClass = classNN)
            return hwnd
    }
    return 0
}

; Clique por ClassNN + client coords, com fallback para clique físico.
; Implementação canônica para callers que não precisam compor espera de estado.
MV_ClickBySpec(winTitle, classNN, x, y) {
    if (classNN = "" || classNN = "CLASSNN" || x = "" || y = "")
        return false
    if MV_ClickControlAt(winTitle, classNN, x, y, 20)
        return true
    if !WinExist(winTitle)
        return false
    try {
        WinActivate winTitle
        if !MV_Poll(() => WinActive(winTitle), MV_WINDOW_ACTIVATE_TIMEOUT_SECS)
            return false
        Click(x, y, 1)
        return true
    } catch {
        return false
    }
}

; Copia o texto focado com Ctrl+C e aguarda o clipboard (ClipWait).
; Canônica única de _CopyFocusedNumericText (FfcvScreen) e _CopySelecionado (MovDocScreen).
; Extração numérica opcional via parâmetro.
MV_CopyFocusedText(timeoutMs := MV_CLIPBOARD_TIMEOUT_MS, extrairNumero := false) {
    A_Clipboard := ""
    Send "^c"
    if !ClipWait(timeoutMs / 1000)
        return ""

    value := Trim(A_Clipboard)
    if (extrairNumero && RegExMatch(value, "\d+", &m))
        return m[0]
    return value
}

; Aguarda o modal Forms ativo sumir (base de _WaitModalGone).
MV_WaitModalGone(timeoutMs := MV_DEFAULT_TIMEOUT_MS) {
    return MV_Poll(() => Dialog_ActiveModalTitle() = "", timeoutMs / 1000)
}

; Aguarda uma janela específica sumir (base de _WaitWindowGone).
MV_WaitWindowGone(winTitle, timeoutMs := MV_DEFAULT_TIMEOUT_MS) {
    return MV_Poll(() => !WinExist(winTitle), timeoutMs / 1000)
}

; Garante que a janela está ativa (base de _EnsureWindowActive).
MV_EnsureWindowActive(winTitle, timeoutSecs := MV_WINDOW_ACTIVATE_TIMEOUT_SECS) {
    if !WinExist(winTitle)
        return false
    WinActivate winTitle
    return MV_Poll(() => WinActive(winTitle), timeoutSecs)
}

; Encontra um botão do modal por texto visível; retorna hwnd ou 0.
; Base única de TissXml_ClickModalButtonByText e TissXml_ModalHasButton.
MV_FindButtonByText(winTitle, buttonText) {
    try hwnds := WinGetControlsHwnd(winTitle)
    catch
        return 0

    for hwnd in hwnds {
        try ctrlClass := ControlGetClassNN(hwnd)
        catch
            continue
        if (ctrlClass != "Button" && !InStr(ctrlClass, "Button"))
            continue
        try btnText := ControlGetText(hwnd)
        catch
            continue
        if (Trim(btnText) = buttonText)
            return hwnd
    }
    return 0
}

; Tenta preencher por ClassNN via ControlSetText e usa clique físico como fallback.
; O fallback preserva o contrato para campos Oracle Forms que não aceitam WM_SETTEXT.
MV_SetTextByControl(winTitle, classNN, value, fallbackX := "", fallbackY := "", clear := true) {
    if (classNN != "" && classNN != "CLASSNN") {
        hwnd := MV_FirstControlByClass(winTitle, classNN)
        if hwnd {
            try {
                ControlSetText value, hwnd
                try {
                    if (Trim(ControlGetText(hwnd)) = Trim(String(value)))
                        return true
                } catch {
                    return true
                }
            } catch {
            }
        }
    }

    if (fallbackX = "" || fallbackY = "")
        return false
    return MV_SetTextByClick(winTitle, fallbackX, fallbackY, value, clear)
}

; Preenche um campo por clique físico + teclado (clear opcional).
; É o fallback para campos que não aceitam ControlSetText.
MV_SetTextByClick(winTitle, x, y, value, clear := true) {
    if !MV_EnsureWindowActive(winTitle)
        return false

    before := MV_CaptureScreenState(winTitle)
    Click(x + 15, y + 8, 1)
    if !MV_WaitScreenChanged(before, MV_KEY_SETTLE_MS * 10, winTitle)
        return false
    if !MV_WaitScreenStable(winTitle, MV_KEY_SETTLE_MS, MV_KEY_SETTLE_MS * 20)
        return false

    if (clear) {
        before := MV_CaptureScreenState(winTitle)
        Send "{Home}"
        Send "^+{End}"
        Send "{Backspace}"
        if !MV_WaitScreenChanged(before, MV_KEY_SETTLE_MS * 10, winTitle)
            return false
        if !MV_WaitScreenStable(winTitle, MV_KEY_SETTLE_MS, MV_KEY_SETTLE_MS * 20)
            return false
    }

    before := MV_CaptureScreenState(winTitle)
    SendText value
    if !MV_WaitScreenChanged(before, MV_KEY_SETTLE_MS * 10, winTitle)
        return false
    if !MV_WaitScreenStable(winTitle, MV_KEY_SETTLE_MS, MV_KEY_SETTLE_MS * 20)
        return false
    return true
}
