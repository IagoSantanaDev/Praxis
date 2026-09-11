; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug
#Include ProtocolarParsers.ahk
#Include ..\..\..\lib\config\Paths.ahk
#Include ..\..\..\lib\globals\mv\FFCV_ErrorTemplates.ahk

; ════════════════════════════════════════════════════════════════
;  PROTOCOLAR
; ════════════════════════════════════════════════════════════════
; Parâmetros da tela:
;   remessas    -> números das remessas separados por vírgula. Ex: 511458, 514015
;   setor_atual -> setor onde as contas estão. Ex: 34
;   setor_envio -> setor destino. Ex: 365
;
; A automação operacional no MV ainda depende dos títulos e ClassNN reais
; capturados pelo Window Spy.

RunProtocolar(params) {
    global gRunning

    remessas := Protocolar_ParseRemessas(params["remessas"])
    setorAtual := Trim(params["setor_atual"])
    setorEnvio := Trim(params["setor_envio"])
    tipo := params.Has("tipo") ? Trim(String(params["tipo"])) : "Ambulatorial"
    finalizarEnvio := Protocolar_OptionEnabled(params, "finalizar_envio", true)
    umaRemessaUmProtocolo := Protocolar_OptionEnabled(params, "uma_remessa_um_protocolo", false)
    csvPath := params.Has("csv_path")
        ? Trim(String(params["csv_path"]))
        : ""

    if (remessas.Length = 0)
        return Protocolar_Abort("Informe o número das remessas. Ex: 511458, 514015")
    if (setorAtual = "")
        return Protocolar_Abort("Informe o setor atual. Ex: 34")
    if (setorEnvio = "")
        return Protocolar_Abort("Informe o setor de envio. Ex: 365")
    if (setorAtual = setorEnvio)
        return Protocolar_Abort("O setor atual e o setor de envio devem ser diferentes.")
    if (tipo = "")
        tipo := "Ambulatorial"
    if (StrLower(tipo) != "ambulatorial" && StrLower(tipo) != "internamento" && StrLower(tipo) != "hospitalar")
        return Protocolar_Abort("Tipo de atendimento invalido. Use Ambulatorial ou Internamento.")

    ; ── FLUXO: UMA REMESSA = UM PROTOCOLO ─────────────────────────
    if umaRemessaUmProtocolo {
        Notify("Iniciando fluxo: Uma Remessa = Um Protocolo...")
        mapeamentoRemessas := []

        for idx, remessa in remessas {
            ThrowIfAppStopped()
            Notify("Processando remessa " remessa " (" idx "/" remessas.Length ")...")

            currentCsv := ""
            if (csvPath != "" && FileExist(csvPath)) {
                currentCsv := csvPath
            } else {
                try currentCsv := Protocolar_GerarCsvContas([remessa], tipo)
                catch as e {
                    if (e is AppStoppedError)
                        throw e
                    return Protocolar_Abort("Falha ao gerar CSV para remessa " remessa ": " e.Message)
                }
            }

            if !FileExist(currentCsv)
                return Protocolar_Abort("CSV de contas nao encontrado para remessa " remessa ": " currentCsv)

            try {
                contasRemessa := Protocolar_ExtractContasFromCsv(currentCsv, true, tipo)
            } catch as e {
                if (e is AppStoppedError)
                    throw e
                return Protocolar_Abort("Falha ao ler contas do CSV para remessa " remessa ": " e.Message)
            }

            if (contasRemessa.Length = 0) {
                Notify("Remessa " remessa " nao possui contas no CSV. Pulando...")
                continue
            }

            if !Protocolar_AbrirTelaEnvio(setorAtual, setorEnvio, tipo)
                return Protocolar_Abort("Nao foi possivel abrir ou preparar a tela de Envio para a remessa " remessa ".")

            Notify("Protocolar remessa " remessa ": enviando " contasRemessa.Length " conta(s)...")
            for index, conta in contasRemessa {
                ThrowIfAppStopped()
                Protocolar_EnviarConta(conta)
                popup := Protocolar_EncontrarPopupUsuario(400)
                if popup
                    return Protocolar_Abort(Protocolar_DescreverPopup(popup, conta))
                if (Mod(index, 25) = 0 || index = contasRemessa.Length)
                    Notify("Protocolar remessa " remessa ": " index "/" contasRemessa.Length " conta(s) enviada(s).")
            }

            if !Protocolar_RemoverRegistroVazio()
                return Protocolar_Abort("Contas da remessa " remessa " enviadas, mas nao foi possivel remover registro vazio final.")

            protNum := ""
            if (finalizarEnvio) {
                if !Protocolar_FinalizarEnvio()
                    return Protocolar_Abort("Falha ao finalizar/imprimir o envio da remessa " remessa ".")

                ; Copiar o número do protocolo gerado no campo de protocolo do MOV DOC após imprimir
                protNum := MovDoc_CopiarNumeroProtocolo(MV_WIN_MOVDOC_ENVIO)
                if (protNum = "")
                    protNum := MovDoc_CopiarNumeroProtocolo(MV_WIN_MOVDOC_BAIXA)
            }

            mapeamentoRemessas.Push(Map("remessa", remessa, "protocolo", protNum != "" ? protNum : "N/I"))
            Notify("Remessa " remessa " concluida. Protocolo gerado: " (protNum != "" ? protNum : "N/I"))
            Progress((idx / remessas.Length) * 100)
        }

        reportMsg := "Protocolar concluído (Uma Remessa = Um Protocolo)!`n`nRELAÇÃO DE REMESSAS E PROTOCOLOS:`n"
        for _, item in mapeamentoRemessas
            reportMsg .= "  • Remessa: " item["remessa"] " -> Protocolo Gerado: " item["protocolo"] "`n"

        Done(reportMsg)
        return true
    }

    ; ── FLUXO LEGADO: VÁRIAS REMESSAS MISTURADAS ─────────────────
    if (csvPath = "") {
        try csvPath := Protocolar_GerarCsvContas(remessas, tipo)
        catch as e {
            if (e is AppStoppedError)
                throw e
            return Protocolar_Abort("Falha ao gerar CSV de contas: " e.Message)
        }
    }

    if !FileExist(csvPath)
        return Protocolar_Abort("CSV de contas nao encontrado: " csvPath)

    try {
        contas := Protocolar_ExtractContasFromCsv(csvPath, true, tipo)
    } catch as e {
        if (e is AppStoppedError)
            throw e
        return Protocolar_Abort("Falha ao ler contas do CSV: " e.Message)
    }

    if (contas.Length = 0)
        return Protocolar_Abort("O CSV nao possui contas validas na coluna " Protocolar_GetCsvContaColumnName(tipo) ".")
    if !Protocolar_AbrirTelaEnvio(setorAtual, setorEnvio, tipo)
        return Protocolar_Abort("Nao foi possivel abrir ou preparar a tela Protocolacao de Envio de Documentos.")

    Notify("Protocolar: enviando " contas.Length " conta(s) do setor " setorAtual " para " setorEnvio ".")
    for index, conta in contas {
        ThrowIfAppStopped()
        Protocolar_EnviarConta(conta)
        popup := Protocolar_EncontrarPopupUsuario(400)
        if popup
            return Protocolar_Abort(Protocolar_DescreverPopup(popup, conta))
        if (Mod(index, 25) = 0 || index = contas.Length)
            Notify("Protocolar: " index "/" contas.Length " conta(s) enviada(s).")
    }

    if !Protocolar_RemoverRegistroVazio()
        return Protocolar_Abort("Contas enviadas, mas nao foi possivel remover o registro vazio final.")

    if (finalizarEnvio && !Protocolar_FinalizarEnvio())
        return Protocolar_Abort("Contas enviadas, mas nao foi possivel finalizar/imprimir o envio.")

    Done("Protocolar concluído: " contas.Length " conta(s) enviada(s).")
    return true
}


Protocolar_GerarCsvContas(remessas, tipo := "Ambulatorial") {
    documentsDir := Config_GetPath("Documents")
    csvPath := documentsDir "\Envio.CSV"
    csvAltPath := documentsDir "\Envio.CSV.CSV"

    for oldPath in [csvPath, csvAltPath, documentsDir "\Envio"] {
        if FileExist(oldPath)
            try FileDelete oldPath
    }

    if !MV_EnsureFFCV()
        throw Error("FFCV nao ficou ativa para gerar o relatorio de contas.")

    if !MV_SendAndWait(MV_WIN_FFCV_ANY, "!e", MV_TIMEOUT_LOAD * 1000, , "menu de relatórios aberto")
        throw Error("Menu de relatorios nao produziu transicao observavel.")
    if !MV_SendAndWait(MV_WIN_FFCV_ANY, "{Enter 2}", MV_TIMEOUT_LOAD * 1000, , "relatório personalizado selecionado")
        throw Error("Seleção do relatório nao produziu transicao observavel.")
    if !MV_WaitScreenStable("Relatórios Personalizado ahk_exe ifrun60.EXE", MV_TARGET_STABLE_MS, MV_TIMEOUT_LOAD * 1000)
        throw Error("Janela Relatórios Personalizado nao estabilizou.")
    relHwnd := WinExist("Relatórios Personalizado ahk_exe ifrun60.EXE")

    MV_EnsureWindowActive("Relatórios Personalizado ahk_exe ifrun60.EXE")
    downRelatorio := Protocolar_IsHospitalar(tipo) ? 177 : 121
    if !MV_SendAndWait("Relatórios Personalizado ahk_exe ifrun60.EXE", "{Down " downRelatorio "}", 5000, , "relatório posicionado")
        throw Error("Nao foi possivel posicionar o relatório.")
    if !MV_SendAndWait("Relatórios Personalizado ahk_exe ifrun60.EXE", "!1", 30000, , "geração de arquivo solicitada")
        throw Error("Nao foi possivel abrir a geração do arquivo.")

    reportHwnd := Protocolar_WaitWindowWithControls("EXECUTASQL.exe", "TEdit1", "TBitBtn2", 60)
    if !reportHwnd
        throw Error("Popup de remessa/Gerar Arquivo nao apareceu.")
    reportTitle := "ahk_id " reportHwnd

    if !MV_SetTextByControl(reportTitle, "TEdit1", Protocolar_Join(remessas, ","), 110, 14)
        throw Error("Nao foi possivel preencher as remessas no relatorio FFCV.")

    button := MV_FirstControlByClass(reportTitle, "TBitBtn2")
    if !button
        throw Error("Botao Gerar Arquivo nao encontrado.")
    if !MV_ClickHwndAndWait(reportTitle, button, 30000, , "arquivo gerado")
        throw Error("Falha ao gerar arquivo FFCV.")

    saveHwnd := Protocolar_WaitWindowWithControls("", "Edit1", "Button2", 45)
    if !saveHwnd
        throw Error("Janela Salvar Como nao apareceu.")
    saveTitle := "ahk_id " saveHwnd
    if !MV_SetTextByControl(saveTitle, "Edit1", documentsDir "\Envio", "", "", true)
        throw Error("Nao foi possivel preencher o nome do CSV.")

    saveButton := MV_FirstControlByClass(saveTitle, "Button2")
    if !saveButton
        throw Error("Botao Salvar nao encontrado.")
    if !MV_ClickHwndAndWait(saveTitle, saveButton, 30000, , "CSV salvo")
        throw Error("Falha ao salvar CSV.")

    infoHwnd := Protocolar_WaitWindowWithControls("EXECUTASQL.exe", "Button1", "", 30)
    if !infoHwnd
        throw Error("A confirmação Information do relatório nao apareceu.")

    infoButton := MV_FirstControlByClass("ahk_id " infoHwnd, "Button1")
    if !infoButton
        throw Error("Botao de confirmacao Information nao encontrado.")
    if !MV_ClickHwndAndWait("ahk_id " infoHwnd, infoButton, 30000, , "geração do CSV confirmada")
        throw Error("Falha ao confirmar geração do CSV.")

    if relHwnd {
        relButton := MV_FirstControlByClass("ahk_id " relHwnd, "Button1")
        if relButton
            MV_ClickHwndAndWait("ahk_id " relHwnd, relButton, 30000, , "relatório fechado")
    }

    if MV_Poll(() => FileExist(csvPath) || FileExist(csvAltPath), 30)
        return FileExist(csvPath) ? csvPath : csvAltPath
    throw Error("O CSV nao apareceu em Documents após salvar.")
}

Protocolar_OptionEnabled(params, key, defaultValue := false) {
    if !params.Has(key) || Trim(String(params[key])) = ""
        return defaultValue
    value := StrLower(Trim(String(params[key])))
    return !(value = "false" || value = "0" || value = "nao" || value = "não")
}

Protocolar_WaitWindowWithControls(processName, requiredClass, optionalClass := "", timeoutSecs := 20) {
    startedAt := A_TickCount
    while (A_TickCount - startedAt <= timeoutSecs * 1000) {
        ThrowIfAppStopped()
        spec := processName = "" ? "" : "ahk_exe " processName
        for hwnd in WinGetList(spec) {
            title := "ahk_id " hwnd
            if !MV_FirstControlByClass(title, requiredClass)
                continue
            if (optionalClass != "" && !MV_FirstControlByClass(title, optionalClass))
                continue
            return hwnd
        }
        Sleep MV_POLL_MS
    }
    return 0
}

Protocolar_Join(items, separator) {
    result := ""
    for _, item in items
        result .= (result = "" ? "" : separator) item
    return result
}

Protocolar_EnviarConta(conta) {
    previousClipboard := ClipboardAll()
    try {
        A_Clipboard := ""
        A_Clipboard := conta
        if !ClipWait(1)
            throw Error("Falha ao preparar clipboard da conta " conta ".")
        if !MV_SendAndWait(MV_WIN_MOVDOC_ENVIO, "^v", 3000, , "conta colada")
            throw Error("Colagem da conta nao produziu estado observavel.")
        if !MV_SendEnterAndWait(MV_WIN_MOVDOC_ENVIO, 3000, , "conta enviada")
            throw Error("Enter da conta nao produziu estado observavel.")
    } finally {
        A_Clipboard := previousClipboard
    }
}

Protocolar_EncontrarPopupUsuario(timeoutMs := 400) {
    startedAt := A_TickCount
    while (A_TickCount - startedAt <= timeoutMs) {
        ThrowIfAppStopped()
        hwnd := WinExist("Mensagem ao Usuário do MV 2000 ahk_exe ifrun60.EXE")
        if hwnd
            return hwnd
        Sleep MV_POLL_MS
    }
    return 0
}

Protocolar_DescreverPopup(hwnd, conta) {
    title := "ahk_id " hwnd
    try text := Trim(WinGetText(title))
    catch
        text := ""

    if (text = "" || text = "&OK") {
        try {
            classified := FFCV_ClassifyErrorModal(title)
            ocrText := Trim(classified.Get("texto", ""))
            if (ocrText != "")
                text := ocrText
        } catch {
        }
    }

    if (text = "")
        text := "Mensagem do MV sem texto acessível."
    else
        text := SubStr(text, 1, 400)

    return "Popup do MV ao enviar a conta " conta ": " text
}

Protocolar_AbrirTelaEnvio(setorAtual, setorEnvio, tipo := "Ambulatorial") {
    if !MV_EnsureModule(MV_WIN_MOVDOC_ANY)
        return false

    if !MV_SendAndWait(MV_WIN_MOVDOC_ANY, "{Alt down}mpe{Alt up}", MV_TIMEOUT_LOAD * 1000,
        , "abertura da Protocolação de Envio")
        return false
    if !MV_WaitScreenStable(MV_WIN_MOVDOC_ENVIO, MV_TARGET_STABLE_MS, MV_TIMEOUT_LOAD * 1000)
        return false
    if !MV_EnsureWindowActive(MV_WIN_MOVDOC_ENVIO)
        return false

    if !MV_SendTextAndWait(MV_WIN_MOVDOC_ENVIO, setorAtual, 3000, , "setor atual preenchido")
        return false
    if !MV_SendEnterAndWait(MV_WIN_MOVDOC_ENVIO, 3000, , "setor atual confirmado")
        return false
    if !MV_SendTextAndWait(MV_WIN_MOVDOC_ENVIO, setorEnvio, 3000, , "setor de envio preenchido")
        return false

    hwnd := MV_FirstControlByClass(MV_WIN_MOVDOC_ENVIO, "Button2")
    if !hwnd
        return false
    if !MV_ClickHwndAndWait(MV_WIN_MOVDOC_ENVIO, hwnd, 5000, , "setores confirmados")
        return false
    if !MV_SendAndWait(MV_WIN_MOVDOC_ENVIO, "{Tab 2}", 3000, , "tipo de atendimento posicionado")
        return false

    if (StrLower(tipo) = "internamento" || StrLower(tipo) = "hospitalar") {
        if !MV_SendAndWait(MV_WIN_MOVDOC_ENVIO, "+{Tab 2}", 3000, , "tipo hospitalar reposicionado")
            return false
        if !MV_SendAndWait(MV_WIN_MOVDOC_ENVIO, "{Up 2}", 3000, , "tipo hospitalar selecionado")
            return false
        if !MV_SendAndWait(MV_WIN_MOVDOC_ENVIO, "+{Tab 2}", 3000, , "tipo hospitalar confirmado")
            return false
    }
    return true
}

Protocolar_FinalizarEnvio() {
    reportTitle := "Relatório de Registro de Envio ahk_exe ifrun60.EXE"
    if !MV_SendAndWait(MV_WIN_MOVDOC_ENVIO, "!1", MV_TIMEOUT_LOAD * 1000, , "finalização do envio")
        return false
    if !MV_WaitScreenStable(reportTitle, MV_TARGET_STABLE_MS, MV_TIMEOUT_LOAD * 1000)
        return false

    reportButton := MV_FirstControlByClass(reportTitle, "Button2")
    if !reportButton
        return false
    return MV_CloseWindowAndWait(reportTitle, () => MV_ClickHwnd(reportButton),
        MV_WIN_MOVDOC_ENVIO, MV_TIMEOUT_LOAD * 1000, "relatório de registro fechado")
}

Protocolar_RemoverRegistroVazio() {
    hwnd := MV_FirstControlByClass(MV_WIN_MOVDOC_ENVIO, "ui60Viewcore_W3211")
    if !hwnd
        return false
    return MV_ClickHwndAndWait(MV_WIN_MOVDOC_ENVIO, hwnd, 5000, , "registro vazio selecionado")
}
