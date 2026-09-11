; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug

#Include %A_LineFile%\..\..\FFCV_ErrorTemplates.ahk

; ════════════════════════════════════════════════════════════════
;  MV REPORT PRINT — impressão canônica do relatório de remessa
; ════════════════════════════════════════════════════════════════
;
; A preparação da remessa, inclusive identificação por OCR, pertence
; ao fluxo chamador. Este componente conhece apenas o contrato das
; janelas e controles necessários para imprimir o relatório.

; Extrai o número da remessa presente na janela de impressão de relatório via OCR.
MV_OcrExtractRemessaNumber(winTitle := MV_WIN_RELATORIO_REMESSA) {
    if !WinExist(winTitle)
        return ""

    region := FFCV_ResolveOcrRegion(winTitle)
    if !region["ok"]
        return ""

    ocrResult := FFCV_RunOcrScreen(region["x"], region["y"], region["w"], region["h"], "pt-BR")
    if !ocrResult.Get("ok", false)
        return ""

    fullText := ocrResult.Get("fullText", "")
    if (Trim(fullText) = "")
        return ""

    if RegExMatch(fullText, "(?i)remessa[:\s]*(\d{4,8})", &match)
        return match[1]

    if RegExMatch(fullText, "\b(\d{5,8})\b", &match)
        return match[1]

    return ""
}

; Imprime o relatório de atendimentos da remessa.
; Se openerTitle for informado, aciona o botão que abre o relatório
; antes de executar a sequência comum de impressão.
; Se o outRemessa (ref) for fornecido, tenta capturar o número da remessa via OCR durante a exibição.
MV_PrintDeliveryReport(message := "Impressão do relatório em andamento...", openerTitle := "", openerControl := "Button9", &outRemessa?) {
    if (message != "")
        Notify(message)

    outRemessa := ""

    try {
        if (openerTitle != "") {
            if !WinExist(openerTitle)
                throw Error("A janela de origem do relatório não está disponível.")
            if !MV_ClickFirstControl(openerTitle, openerControl)
                throw Error("Não foi possível abrir o relatório de atendimentos.")
        }

        if !MV_Poll(() => WinExist(MV_WIN_RELATORIO_REMESSA), MV_TIMEOUT_LOAD)
            throw Error("O popup do relatório de atendimentos não apareceu.")

        if !MV_WaitScreenStable(MV_WIN_RELATORIO_REMESSA, MV_TARGET_STABLE_MS,
            MV_TIMEOUT_LOAD * 1000)
            throw Error("O popup do relatório de atendimentos não ficou pronto.")

        ; Se for solicitada a captura da remessa via ref outRemessa, realiza o OCR antes de disparar a impressão
        if IsSet(outRemessa) {
            try outRemessa := MV_OcrExtractRemessaNumber(MV_WIN_RELATORIO_REMESSA)
            catch {
                outRemessa := ""
            }
        }

        reportButton := MV_FirstControlByClass(MV_WIN_RELATORIO_REMESSA,
            MV_BTN_IMPRIMIR_RELATORIO)
        if !reportButton
            throw Error("O botão de impressão do relatório não ficou disponível.")

        if !MV_ClickHwnd(reportButton)
            throw Error("Não foi possível acionar a impressão do relatório.")

        if !MV_Poll(() => WinExist(MV_WIN_PROGRESSO_RELATORIO), MV_TIMEOUT_LOAD)
            throw Error("A janela de andamento do relatório não apareceu.")

        if !MV_WaitWindowClosed(MV_WIN_PROGRESSO_RELATORIO, MV_TIMEOUT_LOAD * 1000)
            throw Error("A janela de andamento do relatório não fechou no tempo esperado.")

        if !MV_Poll(() => !ProcessExist(MV_PROCESSO_RELATORIO), MV_TIMEOUT_LOAD)
            throw Error("O processo do relatório não finalizou no tempo esperado.")

        MV_Log("MV_PrintDeliveryReport", "impressão concluída", true)
        return true
    } catch as err {
        MV_Log("MV_PrintDeliveryReport", err.Message, false)
        throw err
    }
}

