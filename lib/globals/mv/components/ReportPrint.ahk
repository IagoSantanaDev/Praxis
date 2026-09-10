; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug

; ════════════════════════════════════════════════════════════════
;  MV REPORT PRINT — impressão canônica do relatório de remessa
; ════════════════════════════════════════════════════════════════
;
; A preparação da remessa, inclusive identificação por OCR, pertence
; ao fluxo chamador. Este componente conhece apenas o contrato das
; janelas e controles necessários para imprimir o relatório.

; Imprime o relatório de atendimentos da remessa.
; Se openerTitle for informado, aciona o botão que abre o relatório
; antes de executar a sequência comum de impressão.
MV_PrintDeliveryReport(message := "Impressão do relatório em andamento...", openerTitle := "", openerControl := "Button9") {
    if (message != "")
        Notify(message)

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
