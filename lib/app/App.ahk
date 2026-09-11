; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug

#Include ..\..\lib\vendor\WebView2.ahk

; ─── State (AppState carregado antes deste include) ────────────
global gRoot
global gController := ""
global gWebView    := ""
global gMainGui    := ""
global gWorkDir    := ""
global gEmbeddedIndexHtmlBase64 := ""

#Include *i ..\..\build\generated\Praxis_Ui.ahk

; ─── Timing constants ────────────────────────────────────────
AWAIT_POLL_MS             := 100       ; intervalo de polling de AwaitPromise
WEBVIEW2_ENV_TIMEOUT_MS   := 15000     ; timeout de WebView2.CreateEnvironment
WEBVIEW2_CTRL_TIMEOUT_MS  := 15000     ; timeout de WebView2.CreateController
RESIZE_DEBOUNCE_MS        := 50        ; debounce negativo de OnGuiResize
CLOSE_HANDLER_TIMEOUT_MS  := 60000     ; deadline para handler terminar ao fechar
POLL_EXIT_INTERVAL_MS     := 100       ; intervalo de PollExitAfterStop
UI_CLOSE_ACK_TIMEOUT_MS   := 2000     ; prazo para a UI confirmar o fechamento

; ─── App Run ──────────────────────────────────────────────────
AwaitPromise(promise, timeoutMs, timeoutMessage) {
    if !IsObject(promise)
        throw Error("AwaitPromise recebeu valor invalido.")

    if !HasMethod(promise, "await")
        throw Error("Promise invalida. Metodo ausente: await")

    startTick := A_TickCount
    while !ObjHasOwnProp(promise, "status") {
        if (A_TickCount - startTick >= timeoutMs)
            throw Error(timeoutMessage)
        Sleep AWAIT_POLL_MS
    }

    ; Promise.ahk marca o resultado como propriedade própria somente ao
    ; concluir; await() então preserva o erro original em caso de rejeição.
    return promise.await()
}

App_Run() {
    global gMainGui, gController, gWebView, gWorkDir, gEmbeddedIndexHtmlBase64

    if !IsSet(gRoot) || Trim(gRoot) = ""
        throw Error("gRoot nao inicializado. Verifique main.ahk antes de App_Run().")

    try {
        gWorkDir := Config_GetPath("WorkDir")
    } catch as e {
        localAppData := EnvGet("LOCALAPPDATA")
        gWorkDir := (localAppData != "" ? localAppData : A_Temp) "\Praxis"
        try DirCreate gWorkDir
        catch as fallbackError
            OutputDebug "[App] Diretorio de trabalho indisponivel: " . fallbackError.Message
    }

    webViewLoader := gRoot "\lib\vendor\" (A_PtrSize * 8) "bit\WebView2Loader.dll"
    if !FileExist(webViewLoader)
        throw Error("WebView2Loader.dll nao encontrado em: " . webViewLoader)

    ; A janela usa o ícone compartilhado do pacote quando executada a partir do
    ; código-fonte. No EXE compilado, o recurso /icon do Ahk2Exe é a fonte
    ; embutida e permanece como fallback.
    appIconPath := gRoot "\assets\icon.ico"
    if FileExist(appIconPath)
        TraySetIcon(appIconPath)

    gMainGui := Gui("-Resize -MaximizeBox", "Praxis")
    gMainGui.BackColor := "0xD4D0C8"
    gMainGui.OnEvent("Close", OnAppClose)
    gMainGui.OnEvent("Size",  OnGuiResize)
    gMainGui.Show("w750 h540")

    ; Criar ambiente WebView2 com timeout
    try {
        AwaitPromise(
            WebView2.CreateEnvironmentAsync(0, "", "", webViewLoader),
            WEBVIEW2_ENV_TIMEOUT_MS,
            "Timeout ao criar ambiente WebView2."
        )
    } catch as err {
        MsgBox(
            "Falha ao carregar o WebView2Loader.dll."
            . "`n`nArquitetura do processo: " (A_PtrSize * 8) " bits."
            . "`nLoader esperado: " . webViewLoader
            . "`n`nO WebView2 Runtime e necessario para executar o Praxis."
            . "`nBaixe em: https://developer.microsoft.com/microsoft-edge/webview2/"
            . "`n`nErro: " . err.Message,
            "Praxis — WebView2 Runtime",
            "OK Iconx"
        )
        ExitApp 1
    }

    ; Criar controller com timeout
    try {
        gController := AwaitPromise(
            WebView2.CreateControllerAsync(gMainGui.Hwnd, 0, "", "", webViewLoader),
            WEBVIEW2_CTRL_TIMEOUT_MS,
            "Timeout de 15s ao criar WebView2 Controller."
        )
    } catch as err {
        MsgBox(
            err.Message
            . "`n`nReinicie o aplicativo. Se o problema persistir, "
            . "verifique a instalacao do WebView2 Runtime.",
            "Praxis — WebView2",
            "OK Iconx"
        )
        ExitApp 1
    }

    if !(gController is WebView2.Controller)
        throw Error("Falha ao criar WebView2 Controller.")

    gWebView := gController.CoreWebView2

    settings := gWebView.Settings
    settings.AreDefaultContextMenusEnabled := false
    settings.AreDevToolsEnabled            := false

    gWebView.add_WebMessageReceived(OnJsMessage)

    if A_IsCompiled {
        if (Trim(gEmbeddedIndexHtmlBase64) = "")
            throw Error("UI embutida nao encontrada no executavel.")
        gWebView.NavigateToString(Base64DecodeUtf8(gEmbeddedIndexHtmlBase64))
    } else {
        uiPath := gRoot "\lib\ui\index.html"
        if !FileExist(uiPath)
            throw Error("UI de desenvolvimento nao encontrada em: " . uiPath)
        gWebView.Navigate("file:///" . StrReplace(uiPath, "\", "/"))
    }

    SyncViewBounds()
}

OnGuiResize(thisGui, minMax, width, height) {
    if (minMax = -1)
        return
    SetTimer SyncViewBounds, -RESIZE_DEBOUNCE_MS
}

; `OnAppClose` intercepta o fechamento: fecha direto se o app estiver ocioso ou 
; solicita a parada e monitora assincronamente com `SetTimer` se houver handler ativo.

OnAppClose(thisGui) {
    global gExitDeadline

    if !gExitAfterStop {
        RequestAppClose()

        if IsAppRunning() {
            gExitDeadline := A_TickCount + CLOSE_HANDLER_TIMEOUT_MS
            if !IsStopRequested() {
                RequestAppStop()
                SendToUI(Map("type","status","message","Interrompendo antes de fechar...","running",true))
            } else {
                SendToUI(Map("type","status","message","Aguardando interrupcao concluir...","running",true))
            }
            SetTimer PollExitAfterStop, POLL_EXIT_INTERVAL_MS
        } else {
            BeginUiClose()
        }
    }

    return true
}

; `FinishAppExitAfterStop` é o caminho comum de finalização do `close-after-stop`,
; chamado por `PollExitAfterStop` quando o handler termina ou estoura o timeout.
FinishAppExitAfterStop(reason := "") {
    SetTimer PollExitAfterStop, 0
    SetTimer PollUiCloseAck, 0
    ClearUiClose()
    ClearAppClose()

    if (reason != "")
        OutputDebug "[App] " . reason

    CleanupApp()
    ExitApp()
}

BeginUiClose(reason := "") {
    global gUiClosePending, gUiCloseRequestId, gUiCloseDeadline

    if gUiClosePending
        return

    gUiCloseRequestId += 1
    gUiClosePending  := true
    gUiCloseDeadline := A_TickCount + UI_CLOSE_ACK_TIMEOUT_MS

    if (reason != "")
        OutputDebug "[App] " . reason

    SendToUI(Map("type", "shutdown_flush", "requestId", gUiCloseRequestId))
    SetTimer PollUiCloseAck, POLL_EXIT_INTERVAL_MS
}

HandleUiCloseAck(data) {
    global gUiClosePending, gUiCloseRequestId

    if !gUiClosePending || !data.Has("requestId")
        return

    requestId := data["requestId"]
    if IsObject(requestId) || (String(requestId) != String(gUiCloseRequestId))
        return

    gUiClosePending := false
    SetTimer PollUiCloseAck, 0
    SetTimer FinishAppExitAfterStop, -1
}

PollUiCloseAck() {
    global gUiClosePending, gUiCloseDeadline

    if !gUiClosePending {
        SetTimer PollUiCloseAck, 0
        return
    }

    if (A_TickCount > gUiCloseDeadline)
        FinishAppExitAfterStop("Timeout aguardando confirmacao da UI antes de fechar.")
}

; PollExitAfterStop verifica periodicamente o fim do handler ou o timeout e 
; chama FinishAppExitAfterStop; Critical "On" evita reentrância do timer.
PollExitAfterStop() {
    Critical "On"
    try {
        if !IsAppRunning() {
            SetTimer PollExitAfterStop, 0
            BeginUiClose()
            return
        }

        if (A_TickCount > gExitDeadline)
            BeginUiClose("Timeout aguardando handler terminar antes de fechar.")
    } finally {
        Critical "Off"
    }
}

CleanupApp() {
    global gController, gWebView, gExitAfterStop, gExitDeadline

    try {
        if (gController is WebView2.Controller)
            gController.Close()
    } catch as e {
        OutputDebug "[App] CleanupApp falhou: " . e.Message
    } finally {
        ClearAppStop()
        gExitAfterStop := false
        gExitDeadline  := 0
        gWebView := ""
        gController := ""
    }
}


SyncViewBounds() {
    global gController

    if !(gController is WebView2.Controller)
        return

    gController.Fill()
}

Base64DecodeUtf8(base64Text) {
    if (Trim(base64Text) = "")
        return ""

    flags := 1 ; CRYPT_STRING_BASE64
    size := 0
    if !DllCall("Crypt32\CryptStringToBinary", "Str", base64Text, "UInt", 0, "UInt", flags, "Ptr", 0, "UIntP", &size, "Ptr", 0, "Ptr", 0)
        throw Error("Falha ao calcular tamanho do base64.")

    buf := Buffer(size)
    if !DllCall("Crypt32\CryptStringToBinary", "Str", base64Text, "UInt", 0, "UInt", flags, "Ptr", buf, "UIntP", &size, "Ptr", 0, "Ptr", 0)
        throw Error("Falha ao decodificar base64.")

    return StrGet(buf, size, "UTF-8")
}
