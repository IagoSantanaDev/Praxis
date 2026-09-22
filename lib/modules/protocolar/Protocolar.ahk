; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug
#Include ProtocolarParsers.ahk
#Include ..\..\..\lib\config\Paths.ahk
#Include ..\..\..\lib\globals\mv\FFCV_ErrorTemplates.ahk
#Include ..\..\..\lib\globals\mv\screens\MovDocScreen.ahk

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

    remessas := ParseListaCsv(params["remessas"])
    setorAtual := Trim(params["setor_atual"])
    setorEnvio := Trim(params["setor_envio"])
    tipo := params.Has("tipo") ? Trim(String(params["tipo"])) : "Ambulatorial"
    finalizarEnvio := MV_OptionEnabled(params, "finalizar_envio", true)
    umaRemessaUmProtocolo := MV_OptionEnabled(params, "uma_remessa_um_protocolo", false)
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
                if !Protocolar_GarantirTelaEnvio(setorAtual, setorEnvio, tipo)
                    return Protocolar_Abort("Nao foi possivel garantir a tela de Envio para a conta " conta " (remessa " remessa ").")
                resultado := Protocolar_ProcessarConta(conta, setorAtual, setorEnvio, tipo)
                if !resultado["ok"]
                    return Protocolar_Abort(resultado["erro"])
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
        if !Protocolar_GarantirTelaEnvio(setorAtual, setorEnvio, tipo)
            return Protocolar_Abort("Nao foi possivel garantir a tela de Envio para a conta " conta ".")
        resultado := Protocolar_ProcessarConta(conta, setorAtual, setorEnvio, tipo)
        if !resultado["ok"]
            return Protocolar_Abort(resultado["erro"])
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
    if !MV_SendAndWait("Relatórios Personalizado ahk_exe ifrun60.EXE", "{Down " downRelatorio "}", MV_TRANSITION_TIMEOUT_MS, , "relatório posicionado")
        throw Error("Nao foi possivel posicionar o relatório.")
    if !MV_SendAndWait("Relatórios Personalizado ahk_exe ifrun60.EXE", "!1", MV_DEFAULT_TIMEOUT_MS, , "geração de arquivo solicitada")
        throw Error("Nao foi possivel abrir a geração do arquivo.")

    reportHwnd := Protocolar_WaitWindowWithControls("EXECUTASQL.exe", "TEdit1", "TBitBtn2", MV_REPORT_WINDOW_TIMEOUT_SECS)
    if !reportHwnd
        throw Error("Popup de remessa/Gerar Arquivo nao apareceu.")
    reportTitle := "ahk_id " reportHwnd

    if !MV_SetTextByControl(reportTitle, "TEdit1", MV_JoinArray(remessas, ","), 110, 14)
        throw Error("Nao foi possivel preencher as remessas no relatorio FFCV.")

    button := MV_FirstControlByClass(reportTitle, "TBitBtn2")
    if !button
        throw Error("Botao Gerar Arquivo nao encontrado.")
    if !MV_ClickHwndAndWait(reportTitle, button, MV_DEFAULT_TIMEOUT_MS, , "arquivo gerado")
        throw Error("Falha ao gerar arquivo FFCV.")

    saveHwnd := Protocolar_WaitWindowWithControls("", "Edit1", "Button2", MV_SAVE_DIALOG_TIMEOUT_SECS)
    if !saveHwnd
        throw Error("Janela Salvar Como nao apareceu.")
    saveTitle := "ahk_id " saveHwnd
    if !MV_SetTextByControl(saveTitle, "Edit1", documentsDir "\Envio", "", "", true)
        throw Error("Nao foi possivel preencher o nome do CSV.")

    saveButton := MV_FirstControlByClass(saveTitle, "Button2")
    if !saveButton
        throw Error("Botao Salvar nao encontrado.")
    if !MV_ClickHwndAndWait(saveTitle, saveButton, MV_DEFAULT_TIMEOUT_MS, , "CSV salvo")
        throw Error("Falha ao salvar CSV.")

    infoHwnd := Protocolar_WaitWindowWithControls("EXECUTASQL.exe", "Button1", "", MV_INFO_DIALOG_TIMEOUT_SECS)
    if !infoHwnd
        throw Error("A confirmação Information do relatório nao apareceu.")

    infoButton := MV_FirstControlByClass("ahk_id " infoHwnd, "Button1")
    if !infoButton
        throw Error("Botao de confirmacao Information nao encontrado.")
    if !MV_ClickHwndAndWait("ahk_id " infoHwnd, infoButton, MV_DEFAULT_TIMEOUT_MS, , "geração do CSV confirmada")
        throw Error("Falha ao confirmar geração do CSV.")

    if relHwnd {
        relButton := MV_FirstControlByClass("ahk_id " relHwnd, "Button1")
        if relButton
            MV_ClickHwndAndWait("ahk_id " relHwnd, relButton, MV_DEFAULT_TIMEOUT_MS, , "relatório fechado")
    }

    if MV_Poll(() => FileExist(csvPath) || FileExist(csvAltPath), MV_FILE_APPEAR_TIMEOUT_SECS)
        return FileExist(csvPath) ? csvPath : csvAltPath
    throw Error("O CSV nao apareceu em Documents após salvar.")
}

Protocolar_WaitWindowWithControls(processName, requiredClass, optionalClass := "", timeoutSecs := MV_DEFAULT_TIMEOUT_SECS) {
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

Protocolar_EnviarConta(conta) {
    previousClipboard := ClipboardAll()
    try {
        A_Clipboard := ""
        A_Clipboard := conta
        if !ClipWait(MV_CLIPBOARD_NATIVE_TIMEOUT_SECS)
            throw Error("Falha ao preparar clipboard da conta " conta ".")
        if !MV_SendAndWait(MV_WIN_MOVDOC_ENVIO, "^v", MV_ACTION_TIMEOUT_MS, , "conta colada")
            throw Error("Colagem da conta nao produziu estado observavel.")
        if !MV_SendEnterAndWait(MV_WIN_MOVDOC_ENVIO, MV_ACTION_TIMEOUT_MS, , "conta enviada")
            throw Error("Enter da conta nao produziu estado observavel.")
    } finally {
        A_Clipboard := previousClipboard
    }
}

Protocolar_EncontrarPopupUsuario(timeoutMs := MV_USER_POPUP_TIMEOUT_MS) {
    startedAt := A_TickCount
    while (A_TickCount - startedAt <= timeoutMs) {
        ThrowIfAppStopped()
        hwnd := WinExist(MV_WIN_MENSAGEM_USUARIO " ahk_exe ifrun60.EXE")
        if hwnd
            return hwnd
        Sleep MV_POLL_MS
    }
    return 0
}

; Lê o texto do popup "Mensagem ao Usuário do MV 2000" via OCR — o MV não
; expõe esse texto de forma confiável por WinGetText (normalmente só
; "&OK"). Reusa a infraestrutura de OCR do FFCV (FFCV_ResolveOcrRegion +
; FFCV_RunOcrScreen), só sem o passo de classificação contra os templates
; fixos do FFCV, que não se aplicam a este popup genérico do MOV DOC.
Protocolar_LerTextoPopup(hwnd) {
    winTitle := "ahk_id " hwnd
    region := FFCV_ResolveOcrRegion(winTitle)
    if !region["ok"]
        return ""
    ocr := FFCV_RunOcrScreen(region["x"], region["y"], region["w"], region["h"], FFCV_OCR_LANGUAGE)
    if !ocr["ok"]
        return ""
    return ocr.Get("fullText", "")
}

; Fecha o popup "Mensagem ao Usuário do MV 2000" identificado por hwnd.
; Não reusa Popup_DismissActiveModal (components/Popups.ahk) porque aquela
; função detecta o modal Forms genérico por título "Forms " + classe
; ui60Modal_W32 — um mecanismo de detecção diferente do usado por
; Protocolar_EncontrarPopupUsuario (título específico "Mensagem ao Usuário
; do MV 2000"), sem garantia de que apontem para a mesma janela. Como o
; hwnd já foi encontrado, fechamos ele diretamente.
Protocolar_FecharPopup(hwnd) {
    winTitle := "ahk_id " hwnd
    if !MV_EnsureWindowActive(winTitle)
        return false
    button := MV_FirstControlByClass(winTitle, "Button1")
    if button
        return !!MV_ClickHwndAndWait(winTitle, button, MV_ACTION_TIMEOUT_MS, , "popup do MV fechado")
    return !!MV_SendAndWait(winTitle, "{Enter}", MV_ACTION_TIMEOUT_MS, , "popup do MV fechado (Enter)")
}

; Garante que a tela de Envio está pronta para a próxima conta, reabrindo
; do zero (Protocolar_AbrirTelaEnvio) só quando necessário. Precisa ser
; chamada antes de CADA conta, não apenas uma vez no início do lote: baixar
; um protocolo pendente ou corrigir um setor (Protocolar_ProcessarConta)
; troca de tela no meio do processo e não retorna sozinho para o Envio.
Protocolar_GarantirTelaEnvio(setorAtual, setorEnvio, tipo := "Ambulatorial") {
    if WinExist(MV_WIN_MOVDOC_ENVIO)
        return MV_EnsureWindowActive(MV_WIN_MOVDOC_ENVIO)
    return Protocolar_AbrirTelaEnvio(setorAtual, setorEnvio, tipo)
}

; Envia uma conta para protocolação e trata os 3 desfechos conhecidos de
; popup que o MV pode abrir em resposta. Reenvia a mesma conta uma vez se o
; MV pedir para completar dados de movimentação antes; qualquer outro
; popup não reconhecido retorna erro com o texto lido por OCR, para o
; operador decidir manualmente.
;
; Regra de negócio (comportamento do MV2000i observado no Protocolar.exe
; original, recuperado por engenharia reversa — não documentado pelo MV):
;   - "[...] restante dos dados de movimentação antes de criar um novo
;     registro [...]" -> o Enter anterior não foi processado pela tela;
;     reenviar a MESMA conta resolve na quase totalidade dos casos.
;   - "[...] documento com protocolo pendente [...]" -> a conta já tem um
;     protocolo aberto (de uma tentativa anterior); a ação correta é
;     baixar esse protocolo pendente em vez de criar um novo envio.
;   - "[...] setor recebido diferente do setor atual informado [...]" -> a
;     conta está fisicamente em outro setor; a correção é abrir um envio
;     TEMPORÁRIO no sentido inverso (do setor onde o documento está de
;     volta para o setor atual do operador) para gerar um protocolo, e
;     baixar esse protocolo — isso "traz" o documento de volta
;     corretamente roteado antes de seguir com as próximas contas.
Protocolar_ProcessarConta(conta, setorAtual, setorEnvio, tipo) {
    maxTentativas := 2 ; 1 tentativa original + 1 retry para dados incompletos.
    Loop maxTentativas {
        ThrowIfAppStopped()
        Protocolar_EnviarConta(conta)
        popup := Protocolar_EncontrarPopupUsuario()
        if !popup
            return Map("ok", true)

        msg := Protocolar_LerTextoPopup(popup)
        loose := Protocolar_NormalizeOcrText(msg)

        if Protocolar_IsPopupDadosIncompletos(loose) {
            if !Protocolar_FecharPopup(popup)
                return Map("ok", false, "erro", "Popup de dados incompletos nao fechou para a conta " conta ".")
            if (A_Index < maxTentativas) {
                ; Fechar o popup nem sempre devolve o foco à tela de Envio
                ; automaticamente; garante antes de reenviar a mesma conta.
                if !MV_EnsureWindowActive(MV_WIN_MOVDOC_ENVIO)
                    return Map("ok", false, "erro", "Tela de Envio nao ficou ativa para reenviar a conta " conta ".")
                continue
            }
            return Map("ok", false, "erro", "MV informou dados incompletos mesmo apos reenviar a conta " conta ".")
        }

        protocoloPendente := Protocolar_ExtrairProtocoloPendente(loose)
        if (protocoloPendente != "") {
            if !Protocolar_FecharPopup(popup)
                return Map("ok", false, "erro", "Popup de protocolo pendente nao fechou para a conta " conta ".")
            if !MV_EnsureMovDoc() || !MovDoc_AbrirTelaBaixa()
                return Map("ok", false, "erro", "Nao foi possivel abrir a Baixa para o protocolo pendente " protocoloPendente " (conta " conta ").")
            baixa := MovDoc_BaixarProtocolo(protocoloPendente)
            if !baixa["ok"]
                return Map("ok", false, "erro", "Falha ao baixar protocolo pendente " protocoloPendente " (conta " conta "): " baixa["erro"])
            return Map("ok", true)
        }

        setorRecebido := Protocolar_ExtrairSetorRecebido(loose, setorEnvio, setorAtual)
        if (setorRecebido != "") {
            if !Protocolar_FecharPopup(popup)
                return Map("ok", false, "erro", "Popup de setor diferente nao fechou para a conta " conta ".")
            correcao := Protocolar_CorrigirSetorEBaixar(conta, setorRecebido, setorAtual, tipo)
            if !correcao["ok"]
                return Map("ok", false, "erro", "Falha ao corrigir setor da conta " conta ": " correcao["erro"])
            return Map("ok", true)
        }

        ; Popup não reconhecido: aborta com o texto lido para o operador decidir.
        return Map("ok", false, "erro", "Popup do MV nao reconhecido ao enviar a conta " conta ": "
            (msg != "" ? SubStr(Trim(msg), 1, 400) : "sem texto legivel por OCR."))
    }
    return Map("ok", false, "erro", "Conta " conta " excedeu as tentativas sem resposta reconhecida do MV.")
}

; Corrige o roteamento de uma conta que está em setor diferente do
; esperado: abre um envio TEMPORÁRIO no sentido inverso (setorRecebido →
; setorAtualOriginal), confirma esse envio para gerar um protocolo, copia
; o número gerado e baixa esse protocolo — trazendo o documento de volta
; corretamente roteado. Não remove o registro vazio (Protocolar_RemoverRegistroVazio):
; isso só se aplica ao fechamento final de TODAS as contas, não a este
; atalho pontual de correção por conta.
Protocolar_CorrigirSetorEBaixar(conta, setorRecebido, setorAtualOriginal, tipo) {
    if !Protocolar_AbrirTelaEnvio(setorRecebido, setorAtualOriginal, tipo)
        return Map("ok", false, "erro", "Nao foi possivel abrir o envio temporario de correcao de setor.")

    Protocolar_EnviarConta(conta)

    reportTitle := "Relatório de Registro de Envio ahk_exe ifrun60.EXE"
    if !MV_SendAndWait(MV_WIN_MOVDOC_ENVIO, "!1", MV_TIMEOUT_LOAD * 1000, , "confirmacao do envio de correcao de setor")
        return Map("ok", false, "erro", "Confirmacao do envio de correcao nao produziu transicao observavel.")
    if !MV_WaitScreenStable(reportTitle, MV_TARGET_STABLE_MS, MV_TIMEOUT_LOAD * 1000)
        return Map("ok", false, "erro", "Relatorio de registro de envio (correcao) nao estabilizou.")

    reportButton := MV_FirstControlByClass(reportTitle, "Button1")
    if !reportButton
        return Map("ok", false, "erro", "Botao de confirmacao do relatorio de correcao nao encontrado.")
    if !MV_CloseWindowAndWait(reportTitle, () => MV_ClickHwnd(reportButton), MV_WIN_MOVDOC_ENVIO, MV_TIMEOUT_LOAD * 1000, "relatorio de correcao fechado")
        return Map("ok", false, "erro", "Relatorio de registro de envio (correcao) nao fechou.")

    protocoloNovo := RegExReplace(MovDoc_CopiarNumeroProtocolo(MV_WIN_MOVDOC_ENVIO), "\D")
    if (protocoloNovo = "")
        return Map("ok", false, "erro", "Nao foi possivel copiar o protocolo gerado pela correcao de setor.")

    if !MV_CloseWindowAndWait(MV_WIN_MOVDOC_ENVIO, () => MV_Send("^q"), MV_WIN_MOVDOC_ANY, MV_TIMEOUT_LOAD * 1000, "envio temporario de correcao fechado")
        return Map("ok", false, "erro", "Envio temporario de correcao de setor nao fechou.")

    if !MV_EnsureMovDoc() || !MovDoc_AbrirTelaBaixa()
        return Map("ok", false, "erro", "Nao foi possivel abrir a Baixa para o protocolo de correcao " protocoloNovo ".")

    baixa := MovDoc_BaixarProtocolo(protocoloNovo)
    if !baixa["ok"]
        return Map("ok", false, "erro", "Falha ao baixar o protocolo de correcao " protocoloNovo ": " baixa["erro"])

    return Map("ok", true, "protocolo", protocoloNovo)
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

    if !MV_SendTextAndWait(MV_WIN_MOVDOC_ENVIO, setorAtual, MV_ACTION_TIMEOUT_MS, , "setor atual preenchido")
        return false
    if !MV_SendEnterAndWait(MV_WIN_MOVDOC_ENVIO, MV_ACTION_TIMEOUT_MS, , "setor atual confirmado")
        return false
    if !MV_SendTextAndWait(MV_WIN_MOVDOC_ENVIO, setorEnvio, MV_ACTION_TIMEOUT_MS, , "setor de envio preenchido")
        return false

    hwnd := MV_FirstControlByClass(MV_WIN_MOVDOC_ENVIO, "Button2")
    if !hwnd
        return false
    if !MV_ClickHwndAndWait(MV_WIN_MOVDOC_ENVIO, hwnd, MV_TRANSITION_TIMEOUT_MS, , "setores confirmados")
        return false
    if !MV_SendAndWait(MV_WIN_MOVDOC_ENVIO, "{Tab 2}", MV_ACTION_TIMEOUT_MS, , "tipo de atendimento posicionado")
        return false

    if (StrLower(tipo) = "internamento" || StrLower(tipo) = "hospitalar") {
        if !MV_SendAndWait(MV_WIN_MOVDOC_ENVIO, "+{Tab 2}", MV_ACTION_TIMEOUT_MS, , "tipo hospitalar reposicionado")
            return false
        if !MV_SendAndWait(MV_WIN_MOVDOC_ENVIO, "{Up 2}", MV_ACTION_TIMEOUT_MS, , "tipo hospitalar selecionado")
            return false
        if !MV_SendAndWait(MV_WIN_MOVDOC_ENVIO, "+{Tab 2}", MV_ACTION_TIMEOUT_MS, , "tipo hospitalar confirmado")
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
    return MV_ClickHwndAndWait(MV_WIN_MOVDOC_ENVIO, hwnd, MV_TRANSITION_TIMEOUT_MS, , "registro vazio selecionado")
}
