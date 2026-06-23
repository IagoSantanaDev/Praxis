; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#SingleInstance Force

#Include lib\WebView2.ahk
#Include lib\JSON.ahk
#Include scripts\remessa_protocolo.ahk
#Include scripts\protocolar.ahk
#Include scripts\fechar_xml.ahk

SetTitleMatchMode 2

; ─── State ────────────────────────────────────────────────────
global gController := ""
global gWebView    := ""
global gMainGui    := ""
global gRunning    := false
global gWorkDir    := ""
global gIntegrityExpectedFiles := Map()
global gIntegritySilentMode := false
global gEmbeddedIndexHtmlBase64 := ""
#Include *i build\generated\Praxis_IntegrityManifest.ahk
#Include *i build\generated\Praxis_Ui.ahk

; ─── Script registry ──────────────────────────────────────────
global gScripts := [
    Map(
        "id",        "remessa_protocolo",
        "nome",      "Remessa por Protocolo",
        "categoria", "Faturamento",
        "descricao", "Baixa protocolos no MOV DOC e cria/atualiza remessa no FFCV",
        "params", [
            Map("id","protocolos",     "label","Protocolos",
                "tipo","text",   "obrigatorio",true,
                "hint","Ex: 12345, 67890"),
            Map("id","tipo_conta",     "label","Tipo de Conta",
                "tipo","select", "obrigatorio",true,
                "opcoes",["Internamento","Ambulatório","Emergência"]),
            Map("id","num_remessa",    "label","Remessa Existente",
                "tipo","text",   "obrigatorio",false,
                "hint","Deixe vazio para criar nova"),
            Map("id","data_entrega",   "label","Data de Entrega",
                "tipo","date",   "obrigatorio",false),
            Map("id","data_vencimento","label","Data de Vencimento",
                "tipo","date",   "obrigatorio",false)
        ]
    ),
    Map(
        "id",        "protocolar",
        "nome",      "Protocolar",
        "categoria", "Movimentação",
        "descricao", "Movimenta contas de remessas para outro setor",
        "params", [
            Map("id","remessas",    "label","Número das Remessas",
                "tipo","text",  "obrigatorio",true,
                "hint","Ex: 511458, 514015"),
            Map("id","setor_atual", "label","Setor Atual",
                "tipo","text",  "obrigatorio",true,
                "hint","Ex: 34"),
            Map("id","setor_envio", "label","Setor de Envio",
                "tipo","text",  "obrigatorio",true,
                "hint","Ex: 365")
        ]
    ),
    Map(
        "id",        "fechar_xml",
        "nome",      "Fechar e Gerar XML",
        "categoria", "Faturamento",
        "descricao", "Fecha remessas e gera arquivo XML",
        "params", [
            Map("id","remessas",      "label","Número das Remessas",
                "tipo","text", "obrigatorio",true,
                "hint","Ex: 511458, 514015"),
            Map("id","data_entrega",  "label","Data de Entrega",
                "tipo","date", "obrigatorio",true),
            Map("id","data_vencimento","label","Data de Vencimento",
                "tipo","date", "obrigatorio",true)
        ]
    )
]

; ─── Entry point ──────────────────────────────────────────────
if (A_Args.Length > 0 && A_Args[1] = "--integrity-check") {
    gIntegritySilentMode := true
    AssertRuntimeIntegrity()
    ExitApp 0
}

AppInit()

AppInit() {
    global gMainGui, gController, gWebView, gWorkDir, gEmbeddedIndexHtmlBase64

    AssertRuntimeIntegrity()

    ; Lê o WorkDir configurado pelo installer
    gWorkDir := IniRead(A_ScriptDir "\config.ini", "Paths", "WorkDir",
                        A_MyDocuments "\Praxis")

    gMainGui := Gui("+Resize +MinSize640x460", "Praxis")
    gMainGui.BackColor := "0xD4D0C8"
    gMainGui.OnEvent("Close", (*) => ExitApp())
    gMainGui.OnEvent("Size",  OnGuiResize)
    gMainGui.Show("w750 h540")

    webViewLoader := A_ScriptDir "\lib\" (A_PtrSize * 8) "bit\WebView2Loader.dll"
    if !FileExist(webViewLoader)
        throw Error("WebView2Loader.dll não encontrado em: " . webViewLoader)

    gController := WebView2.CreateControllerAsync(gMainGui.Hwnd, 0, "", "", webViewLoader).await()
    if !(gController is WebView2.Controller)
        throw Error("Falha ao criar WebView2 Controller.")

    gWebView := gController.CoreWebView2

    settings := gWebView.Settings
    settings.AreDefaultContextMenusEnabled := false
    settings.AreDevToolsEnabled            := false

    gWebView.add_WebMessageReceived(OnJsMessage)

    if A_IsCompiled {
        if (Trim(gEmbeddedIndexHtmlBase64) = "")
            throw Error("UI embutida não encontrada no executável.")
        gWebView.NavigateToString(Base64DecodeUtf8(gEmbeddedIndexHtmlBase64))
    } else {
        uiPath := A_ScriptDir "\ui\index.html"
        if !FileExist(uiPath)
            throw Error("UI de desenvolvimento não encontrada em: " . uiPath)
        gWebView.Navigate("file:///" . StrReplace(uiPath, "\", "/"))
    }

    SyncViewBounds()
}

; ─── Runtime integrity ────────────────────────────────────────
AssertRuntimeIntegrity() {
    global gIntegrityExpectedFiles

    ; Em desenvolvimento, permite rodar main.ahk sem o manifesto gerado pelo build.
    if !A_IsCompiled
        return

    if !(gIntegrityExpectedFiles is Map) || gIntegrityExpectedFiles.Count = 0 {
        FailRuntimeIntegrity("Manifesto de integridade não está embutido no executável.")
        return
    }

    failures := []
    for relativePath, expectedHash in gIntegrityExpectedFiles {
        normalizedPath := StrReplace(relativePath, "/", "\")
        fullPath := A_ScriptDir "\" normalizedPath

        if !FileExist(fullPath) {
            failures.Push(relativePath " ausente")
            continue
        }

        actualHash := FileSHA256(fullPath)
        if (actualHash = "") {
            failures.Push(relativePath " ilegível")
            continue
        }

        if (StrLower(actualHash) != StrLower(expectedHash))
            failures.Push(relativePath " alterado")
    }

    if failures.Length > 0
        FailRuntimeIntegrity("Recursos do Praxis foram alterados ou removidos:`n- " . JoinStrings(failures, "`n- "))
}

FailRuntimeIntegrity(message) {
    global gIntegritySilentMode

    logPath := A_ScriptDir "\praxis-integrity.log"
    try FileAppend FormatTime(, "yyyy-MM-dd HH:mm:ss") " | " StrReplace(message, "`n", " | ") "`n", logPath, "UTF-8"
    if !gIntegritySilentMode
        MsgBox message "`n`nReinstale o Praxis usando o instalador oficial.", "Praxis - integridade inválida", "Iconx"
    ExitApp 70
}

FileSHA256(path) {
    tempFile := A_Temp "\praxis_hash_" A_TickCount "_" Random(1000, 9999) ".txt"

    try {
        quote := Chr(34)
        command := A_ComSpec " /C certutil -hashfile " quote path quote " SHA256 > " quote tempFile quote " 2>&1"
        exitCode := RunWait(command, , "Hide")
        if (exitCode != 0)
            return ""

        output := FileRead(tempFile, "UTF-8")
        Loop Parse output, "`n", "`r" {
            candidate := RegExReplace(Trim(A_LoopField), "\s", "")
            if RegExMatch(candidate, "i)^[0-9a-f]{64}$")
                return StrLower(candidate)
        }

        return ""
    } catch as e {
        return ""
    } finally {
        try FileDelete tempFile
    }
}

JoinStrings(items, separator) {
    output := ""
    for index, item in items {
        if (index > 1)
            output .= separator
        output .= item
    }
    return output
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

OnGuiResize(thisGui, minMax, width, height) {
    if (minMax = -1)
        return
    SyncViewBounds()
}

SyncViewBounds() {
    global gController

    if !(gController is WebView2.Controller)
        return

    gController.Fill()
}

; ─── JS → AHK ─────────────────────────────────────────────────
OnJsMessage(handler, args) {
    raw  := args.TryGetWebMessageAsString()
    data := JSON.parse(raw)

    switch data["action"] {
        case "ready":       InitializeApp()
        case "run_script":  RunScript(data["scriptId"], data["params"])
        case "stop_script": StopScript()
        case "exit":        ExitApp()
    }
}

SendToUI(data) {
    global gWebView
    gWebView.PostWebMessageAsJson(JSON.stringify(data))
}

; ─── App bootstrap ────────────────────────────────────────────
InitializeApp() {
    global gScripts
    SendToUI(Map("type", "app_ready", "scripts", gScripts))
}

; ─── Dispatcher ───────────────────────────────────────────────
RunScript(scriptId, params) {
    global gRunning
    if gRunning {
        SendToUI(Map("type","error","message","Já existe um script em execução."))
        return
    }
    gRunning := true
    SendToUI(Map("type","status","message","Iniciando...","running",true))

    switch scriptId {
        case "remessa_protocolo": RunRemessaProtocolo(params)
        case "protocolar":        RunProtocolar(params)
        case "fechar_xml":        RunFecharXML(params)
        default:
            SendToUI(Map("type","error","message","Script desconhecido: " . scriptId))
            gRunning := false
    }
}

StopScript() {
    global gRunning
    gRunning := false
    SendToUI(Map("type","status","message","Execução interrompida.","running",false))
}
