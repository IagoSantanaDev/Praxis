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
    global MV_POLL_MS
    deadline := A_TickCount + timeoutSecs * 1000
    Loop {
        if condFn()
            return true
        if A_TickCount > deadline
            return false
        Sleep MV_POLL_MS
    }
}

; Helper de logging interno usado por Dialogs/Popups/FfcvContaPopup.
; Substitui as 3 helpers *_Log byte-identicas que existiam em cada arquivo.
; Saida identica ao padrao anterior (funcName " => OK|FALHOU  " detail).
MV_Log(funcName, detail, result) {
    try {
        if (result)
            Log_Info(funcName " => OK  " detail)
        else
            Log_Warn(funcName " => FALHOU  " detail)
    }
}

; Espera a janela Oracle Forms estabilizar: sem modal, sem cursor de espera,
; contagem de controles inalterada por stableMs ms.
; Substitui _WaitOracleSettled (FfcvScreen) e TissXml_WaitOracleSettled
; (TissXmlScreen) que eram byte-identicos.
MV_WaitOracleSettled(winTitle, stableMs := 800, timeoutMs := 30000) {
    startedAt := A_TickCount
    stableSince := 0
    lastCount := -1

    Loop {
        modalClear := (Dialog_ActiveModalTitle() = "")
        cursorReady := (A_Cursor != "Wait" && A_Cursor != "AppStarting")
        exists := WinExist(winTitle)
        count := -1
        if exists {
            try hwnds := WinGetControlsHwnd(winTitle)
            catch
                hwnds := []
            count := hwnds.Length
        }
        if (exists && modalClear && cursorReady && count = lastCount) {
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

MV_WaitWindowStable(winTitle, stableMs := 600, timeoutSecs := 20) {
    global MV_POLL_MS
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
