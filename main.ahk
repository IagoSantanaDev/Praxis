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
global gUser       := ""
global gPass       := ""
global gWorkDir    := ""

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
AppInit()

AppInit() {
    global gMainGui, gController, gWebView, gWorkDir

    ; Lê o WorkDir configurado pelo installer
    gWorkDir := IniRead(A_ScriptDir "\config.ini", "Paths", "WorkDir",
                        A_MyDocuments "\RPA MV2000i")

    gMainGui := Gui("+Resize +MinSize640x460", "RPA MV2000i")
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

    uiPath := A_ScriptDir "\ui\index.html"
    gWebView.Navigate("file:///" . StrReplace(uiPath, "\", "/"))

    SyncViewBounds()
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
        case "ready":       CheckSavedCredentials()
        case "save_creds":  HandleSaveCredentials(data["user"], data["pass"])
        case "run_script":  RunScript(data["scriptId"], data["params"])
        case "stop_script": StopScript()
        case "exit":        ExitApp()
    }
}

SendToUI(data) {
    global gWebView
    gWebView.PostWebMessageAsJson(JSON.stringify(data))
}

; ─── Auth ─────────────────────────────────────────────────────
CheckSavedCredentials() {
    cfgPath := A_ScriptDir "\config.ini"
    user    := IniRead(cfgPath, "Auth", "User",    "")
    encPass := IniRead(cfgPath, "Auth", "EncPass", "")

    if (user = "" || encPass = "") {
        SendToUI(Map("type","show_login","user",""))
        return
    }

    global gUser, gPass
    gUser := user
    gPass := DecryptDPAPI(encPass)
    SendToUI(Map("type","login_ok","user",user,"scripts",gScripts))
}

HandleSaveCredentials(user, pass) {
    SaveCredentials(user, pass)
    global gUser, gPass
    gUser := user
    gPass := pass
    SendToUI(Map("type","login_ok","user",user,"scripts",gScripts))
}

SaveCredentials(user, pass) {
    cfgPath := A_ScriptDir "\config.ini"
    IniWrite user,               cfgPath, "Auth", "User"
    IniWrite EncryptDPAPI(pass), cfgPath, "Auth", "EncPass"
}

EncryptDPAPI(plainText) {
    safe := StrReplace(plainText, "'", "''")
    return RunPS("ConvertTo-SecureString '" . safe . "' -AsPlainText -Force | ConvertFrom-SecureString")
}

DecryptDPAPI(encrypted) {
    return RunPS("(New-Object System.Management.Automation.PSCredential('x',"
               . "(ConvertTo-SecureString '" . encrypted . "'))).GetNetworkCredential().Password")
}

RunPS(command) {
    tmp := A_Temp "\rpa_ps_out.txt"
    ps1 := A_Temp "\rpa_ps_cmd.ps1"

    if FileExist(tmp)
        FileDelete tmp
    if FileExist(ps1)
        FileDelete ps1

    safeTmp := StrReplace(tmp, "'", "''")
    psScript := "$ErrorActionPreference = 'Stop'`n"
             . command . " | Out-File -FilePath '" . safeTmp . "' -Encoding UTF8`n"
    FileAppend psScript, ps1, "UTF-8"

    psCmd := "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"" . ps1 . "`""
    RunWait psCmd,, "Hide"

    result := FileExist(tmp) ? Trim(FileRead(tmp)) : ""
    if FileExist(tmp)
        FileDelete tmp
    if FileExist(ps1)
        FileDelete ps1
    return result
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
