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
global gUser       := ""
global gPass       := ""
global gWorkDir    := ""
global gAccessAuthorized := false
global gAccessValidateUrl := "https://praxis.squareweb.app/v1/access/validate"
global gIntegrityExpectedFiles := Map()
global gIntegritySilentMode := false
#Include *i build\generated\Praxis_IntegrityManifest.ahk

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
    global gMainGui, gController, gWebView, gWorkDir

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

    uiPath := A_ScriptDir "\ui\index.html"
    gWebView.Navigate("file:///" . StrReplace(uiPath, "\", "/"))

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
        case "ready":           CheckSavedAccessCode()
        case "validate_access": HandleValidateAccess(data.Has("code") ? data["code"] : "")
        case "save_creds":      HandleSaveCredentials(data["user"], data["pass"])
        case "run_script":      RunScript(data["scriptId"], data["params"])
        case "stop_script":     StopScript()
        case "exit":            ExitApp()
    }
}

SendToUI(data) {
    global gWebView
    gWebView.PostWebMessageAsJson(JSON.stringify(data))
}

; ─── Access gate ──────────────────────────────────────────────
CheckSavedAccessCode() {
    global gAccessAuthorized

    cfgPath := A_ScriptDir "\config.ini"
    encCode := IniRead(cfgPath, "Access", "EncCode", "")
    if (encCode = "") {
        ShowAccessGate()
        return
    }

    code := DecryptDPAPI(encCode)
    if (code = "") {
        ShowAccessGate("Não consegui ler o código salvo. Informe novamente.")
        return
    }

    result := ValidateAccessCode(code)
    if result["ok"] {
        gAccessAuthorized := true
        CheckSavedCredentials()
        return
    }

    gAccessAuthorized := false
    ShowAccessGate("Código de acesso salvo inválido ou expirado. Informe novamente.")
}

ShowAccessGate(message := "") {
    global gAccessAuthorized
    gAccessAuthorized := false
    SendToUI(Map("type", "show_access", "message", message))
}

HandleValidateAccess(code) {
    global gAccessAuthorized

    code := Trim(code)
    if (code = "") {
        ShowAccessGate("Digite o código de acesso.")
        return
    }

    result := ValidateAccessCode(code)
    if result["ok"] {
        SaveAccessCode(code)
        gAccessAuthorized := true
        CheckSavedCredentials()
        return
    }

    gAccessAuthorized := false
    ShowAccessGate(result["message"])
}

SaveAccessCode(code) {
    cfgPath := A_ScriptDir "\config.ini"
    IniWrite EncryptDPAPI(code), cfgPath, "Access", "EncCode"
}

ValidateAccessCode(code) {
    global gAccessValidateUrl

    try {
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.SetTimeouts(5000, 5000, 10000, 10000)
        http.Open("POST", gAccessValidateUrl, false)
        http.SetRequestHeader("Content-Type", "application/json")
        http.SetRequestHeader("Accept", "application/json")
        http.Send(JSON.stringify(Map("code", code)))

        status := http.Status
        body := http.ResponseText
        parsed := body != "" ? JSON.parse(body) : Map()

        if (status >= 200 && status < 300 && parsed.Has("authorized") && parsed["authorized"] = true)
            return Map("ok", true, "message", "Acesso autorizado.")

        message := "Código de acesso inválido."
        if (parsed.Has("error") && parsed["error"] is Map && parsed["error"].Has("message") && parsed["error"]["message"] != "")
            message := parsed["error"]["message"]
        return Map("ok", false, "message", message)
    } catch as e {
        return Map("ok", false, "message", "Não foi possível validar o acesso. Verifique a conexão e tente novamente.")
    }
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
    if (gPass = "") {
        SendToUI(Map("type","show_login","message","Não consegui ler a senha salva. Informe novamente."))
        return
    }
    SendToUI(Map("type","login_ok","user",user,"scripts",gScripts))
}

HandleSaveCredentials(user, pass) {
    global gAccessAuthorized
    if !gAccessAuthorized {
        ShowAccessGate("Valide o código de acesso antes de informar credenciais.")
        return
    }

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
    ; DPAPI de usuário atual + entropia de aplicação. Não grava segredo em arquivo temporário.
    if (plainText = "")
        return ""

    dataBytes := StrPut(plainText, "UTF-16") * 2
    data := Buffer(dataBytes, 0)
    StrPut(plainText, data, "UTF-16")

    entropy := DPAPIEntropyBuffer()
    blobIn := DPAPIBlob(data.Ptr, data.Size)
    blobEntropy := DPAPIBlob(entropy.Ptr, entropy.Size)
    blobOut := DPAPIEmptyBlob()

    if !DllCall("Crypt32\CryptProtectData", "Ptr", blobIn.Ptr, "Ptr", 0, "Ptr", blobEntropy.Ptr, "Ptr", 0, "Ptr", 0, "UInt", 0x1, "Ptr", blobOut.Ptr, "Int")
        throw Error("Falha ao proteger segredo local com DPAPI.")

    outPtr := NumGet(blobOut, DPAPIBlobPtrOffset(), "Ptr")
    outLen := NumGet(blobOut, 0, "UInt")
    try {
        return Base64Encode(outPtr, outLen)
    } finally {
        DllCall("Kernel32\LocalFree", "Ptr", outPtr, "Ptr")
    }
}

DecryptDPAPI(encrypted) {
    ; Retorna vazio em falha para forçar nova digitação sem expor detalhe sensível.
    if (encrypted = "")
        return ""

    try {
        encryptedBytes := Base64Decode(encrypted)
        entropy := DPAPIEntropyBuffer()
        blobIn := DPAPIBlob(encryptedBytes.Ptr, encryptedBytes.Size)
        blobEntropy := DPAPIBlob(entropy.Ptr, entropy.Size)
        blobOut := DPAPIEmptyBlob()

        if !DllCall("Crypt32\CryptUnprotectData", "Ptr", blobIn.Ptr, "Ptr", 0, "Ptr", blobEntropy.Ptr, "Ptr", 0, "Ptr", 0, "UInt", 0x1, "Ptr", blobOut.Ptr, "Int")
            return ""

        outPtr := NumGet(blobOut, DPAPIBlobPtrOffset(), "Ptr")
        try {
            return StrGet(outPtr, "UTF-16")
        } finally {
            DllCall("Kernel32\LocalFree", "Ptr", outPtr, "Ptr")
        }
    } catch as e {
        return ""
    }
}

DPAPIEntropyBuffer() {
    entropyText := "Praxis|local-secret|dpapi-v2|IagoSantanaLima"
    entropyBytes := StrPut(entropyText, "UTF-8")
    entropy := Buffer(entropyBytes, 0)
    StrPut(entropyText, entropy, "UTF-8")
    return entropy
}

DPAPIBlob(dataPtr, dataLen) {
    offset := DPAPIBlobPtrOffset()
    blob := Buffer(offset + A_PtrSize, 0)
    NumPut("UInt", dataLen, blob, 0)
    NumPut("Ptr", dataPtr, blob, offset)
    return blob
}

DPAPIEmptyBlob() {
    offset := DPAPIBlobPtrOffset()
    return Buffer(offset + A_PtrSize, 0)
}

DPAPIBlobPtrOffset() {
    return A_PtrSize = 8 ? 8 : 4
}

Base64Encode(dataPtr, dataLen) {
    flags := 0x40000001 ; CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF
    chars := 0
    if !DllCall("Crypt32\CryptBinaryToStringW", "Ptr", dataPtr, "UInt", dataLen, "UInt", flags, "Ptr", 0, "UInt*", &chars, "Int")
        throw Error("Falha ao calcular Base64 DPAPI.")

    out := Buffer(chars * 2, 0)
    if !DllCall("Crypt32\CryptBinaryToStringW", "Ptr", dataPtr, "UInt", dataLen, "UInt", flags, "Ptr", out.Ptr, "UInt*", &chars, "Int")
        throw Error("Falha ao gerar Base64 DPAPI.")

    return StrGet(out.Ptr, "UTF-16")
}

Base64Decode(value) {
    bytes := 0
    if !DllCall("Crypt32\CryptStringToBinaryW", "Str", value, "UInt", 0, "UInt", 1, "Ptr", 0, "UInt*", &bytes, "Ptr", 0, "Ptr", 0, "Int")
        throw Error("Valor DPAPI inválido.")

    out := Buffer(bytes, 0)
    if !DllCall("Crypt32\CryptStringToBinaryW", "Str", value, "UInt", 0, "UInt", 1, "Ptr", out.Ptr, "UInt*", &bytes, "Ptr", 0, "Ptr", 0, "Int")
        throw Error("Falha ao decodificar valor DPAPI.")

    return out
}

; ─── Dispatcher ───────────────────────────────────────────────
RunScript(scriptId, params) {
    global gRunning, gAccessAuthorized
    if !gAccessAuthorized {
        ShowAccessGate("Valide o código de acesso antes de executar automações.")
        return
    }
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
