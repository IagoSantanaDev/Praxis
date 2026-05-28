#Requires AutoHotkey v2.0
#SingleInstance Force

; Biblioteca de teste para localizar controles por HWND + ClassNN + coordenada Client.
; Uso esperado:
;   1) Preencha ClassNN e x/y client nos arquivos 01..06.
;   2) Deixe DO_ACTION := false para apenas localizar.
;   3) Mude DO_ACTION := true para testar setText/click/focus.

SetTitleMatchMode 2
DetectHiddenText true
SetControlDelay 0
SetWinDelay 0
SetKeyDelay 0, 0

MV_Test_RunSuite(suiteName, winTitle, controls, doAction := false, tolerance := 14) {
    report := "SUÍTE: " suiteName "`n"
           . "Janela: " winTitle "`n"
           . "Modo ação: " (doAction ? "SIM" : "NÃO - apenas localizar") "`n"
           . "Tolerância: " tolerance "px`n`n"

    if !WinExist(winTitle) {
        report .= "❌ Janela não encontrada.`n"
        report .= "Abra a tela correta no MV e rode de novo.`n"
        MV_Test_ShowReport(report)
        return false
    }

    WinActivate winTitle
    WinWaitActive winTitle,, 2

    for _, spec in controls {
        report .= MV_Test_RunOne(winTitle, spec, doAction, tolerance) "`n"
    }

    MV_Test_ShowReport(report)
    return true
}

MV_Test_RunOne(winTitle, spec, doAction, tolerance) {
    name := spec.Get("name", "sem_nome")
    classNN := spec.Get("class", "")
    x := spec.Get("x", "")
    y := spec.Get("y", "")
    action := spec.Get("action", "locate")
    value := spec.Get("value", "")

    if (classNN = "" || classNN = "CLASSNN")
        return "⚠️ " name ": ClassNN pendente. Preencha no arquivo de teste."

    hwnd := 0
    detail := ""

    if (x != "" && y != "") {
        found := MV_Test_FindControlByClientPoint(winTitle, classNN, x + 0, y + 0, tolerance)
        hwnd := found.Get("hwnd", 0)
        detail := found.Get("detail", "")
    } else {
        found := MV_Test_FindFirstControlByClass(winTitle, classNN)
        hwnd := found.Get("hwnd", 0)
        detail := found.Get("detail", "")
    }

    if !hwnd
        return "❌ " name ": não encontrado. " detail

    msg := "✅ " name ": hwnd=" hwnd " class=" classNN " " detail

    if doAction {
        try {
            switch action {
                case "setText":
                    ControlSetText value, hwnd
                    msg .= " | ação=setText valor='" value "'"
                case "click":
                    ControlClick hwnd,,,,, "NA"
                    msg .= " | ação=click"
                case "focus":
                    ControlFocus hwnd
                    msg .= " | ação=focus"
                case "sendEnter":
                    ControlSend "{Enter}", hwnd
                    msg .= " | ação=sendEnter"
                default:
                    msg .= " | ação=locate"
            }
        } catch as e {
            msg .= " | ❌ falha na ação: " e.Message
        }
    }

    return msg
}

MV_Test_FindControlByClientPoint(winTitle, classNN, targetX, targetY, tolerance := 14) {
    bestHwnd := 0
    bestDist := 999999
    bestDetail := ""

    try hwnds := WinGetControlsHwnd(winTitle)
    catch as e
        return Map("hwnd", 0, "detail", "WinGetControlsHwnd falhou: " e.Message)

    for hwnd in hwnds {
        try ctrlClass := ControlGetClassNN(hwnd)
        catch
            continue

        if (ctrlClass != classNN)
            continue

        try ControlGetPos &cx, &cy, &cw, &ch, hwnd
        catch
            continue

        inside := (targetX >= cx && targetX <= cx + cw && targetY >= cy && targetY <= cy + ch)
        centerX := cx + (cw / 2)
        centerY := cy + (ch / 2)
        dist := Sqrt((targetX - centerX) ** 2 + (targetY - centerY) ** 2)
        detail := "rect=[x:" cx " y:" cy " w:" cw " h:" ch "] target=[x:" targetX " y:" targetY "]"

        if inside
            return Map("hwnd", hwnd, "detail", detail " match=inside")

        if (dist < bestDist) {
            bestDist := dist
            bestHwnd := hwnd
            bestDetail := detail " nearestDist=" Round(dist, 1)
        }
    }

    if (bestHwnd && bestDist <= tolerance)
        return Map("hwnd", bestHwnd, "detail", bestDetail " match=nearest")

    return Map("hwnd", 0, "detail", "Nenhum " classNN " contém o ponto; mais próximo: " bestDetail)
}

MV_Test_FindFirstControlByClass(winTitle, classNN) {
    try hwnds := WinGetControlsHwnd(winTitle)
    catch as e
        return Map("hwnd", 0, "detail", "WinGetControlsHwnd falhou: " e.Message)

    for hwnd in hwnds {
        try ctrlClass := ControlGetClassNN(hwnd)
        catch
            continue
        if (ctrlClass = classNN) {
            try ControlGetPos &cx, &cy, &cw, &ch, hwnd
            catch {
                cx := "?", cy := "?", cw := "?", ch := "?"
            }
            return Map("hwnd", hwnd, "detail", "rect=[x:" cx " y:" cy " w:" cw " h:" ch "] match=firstClass")
        }
    }

    return Map("hwnd", 0, "detail", "Nenhum controle com ClassNN " classNN)
}

MV_Test_ProjectRoot() {
    return RegExReplace(A_ScriptDir, "\\test_macros$", "")
}

MV_Test_ImagePath(fileName) {
    return MV_Test_ProjectRoot() "\Imagens_Debug\" fileName
}

MV_Test_ImageVisible(imagePath, variation := 10) {
    if !FileExist(imagePath)
        return false
    CoordMode "Pixel", "Screen"
    try return ImageSearch(&x, &y, 0, 0, A_ScreenWidth, A_ScreenHeight, "*" variation " " imagePath)
    catch
        return false
}

MV_Test_ClickImage(imagePath, variation := 10, offsetX := 8, offsetY := 8) {
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

MV_Test_ClickCachedImage(cacheKey, imagePath, winTitle, variation := 10, offsetX := 8, offsetY := 8) {
    cfgPath := MV_Test_ProjectRoot() "\config.ini"

    if (winTitle != "" && WinExist(winTitle)) {
        WinGetPos &wx, &wy, &ww, &wh, winTitle
        cachedX := IniRead(cfgPath, "ImageCache", cacheKey "_x", "")
        cachedY := IniRead(cfgPath, "ImageCache", cacheKey "_y", "")

        if (cachedX != "" && cachedY != "") {
            CoordMode "Mouse", "Screen"
            Click wx + (cachedX + 0), wy + (cachedY + 0)
            return "cached [relX=" cachedX " relY=" cachedY "]"
        }
    }

    if !FileExist(imagePath)
        return "missing image"

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
                return "image+saved [relX=" relX " relY=" relY "]"
            }
            return "image"
        }
    }
    return "not found"
}

MV_Test_ClearImageCache(cacheKeys*) {
    cfgPath := MV_Test_ProjectRoot() "\config.ini"
    for _, key in cacheKeys {
        try IniDelete cfgPath, "ImageCache", key "_x"
        try IniDelete cfgPath, "ImageCache", key "_y"
    }
}

MV_Test_ShowReport(report) {
    logPath := A_ScriptDir "\ultimo_resultado.txt"
    try FileDelete logPath
    FileAppend report, logPath, "UTF-8"
    A_Clipboard := report
    MsgBox report "`n`nRelatório copiado para a área de transferência e salvo em:`n" logPath, "Resultado do teste", "Iconi"
}
