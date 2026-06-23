; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug

; ─── Dependencies ─────────────────────────────────────────────
; App.ahk e AppState.ahk ja sao incluidos por main.ahk antes deste arquivo.
#Include ..\..\lib\modules\remessa_protocolo\RPRegistry.ahk
#Include ..\..\lib\modules\protocolar\ProtocolarRegistry.ahk
#Include ..\..\lib\modules\fechar_xml\FecharXml.ahk
#Include ..\..\lib\vendor\JSON.ahk

; ─── Dispatcher: AHK → JS bridge ─────────────────────────────
; Log estruturado: campo 'type' permite filtrar no praxis.log via "type:dispatcher"

; Identificador de script: kebab/snake case, minusculas, digitos, underscore, slash.
; Usado para validar script_id e nomes de arquivos. Centralizado aqui para que
; regex mude em um lugar so caso os requisitos evoluam.
IDENTIFIER_REGEX := "^[a-z0-9_/-]+$"

GetLogPath() {
    global gWorkDir

    if IsSet(gWorkDir) && Trim(gWorkDir) != "" {
        try {
            if !DirExist(gWorkDir)
                DirCreate gWorkDir
            return gWorkDir . "\praxis.log"
        } catch as e {
            OutputDebug "[Dispatcher] GetLogPath fallback: " . e.Message
        }
    }

    return A_ScriptDir . "\praxis.log"
}

DispatchLog(level, message, extra?) {
    level   := FormatLogValue(level)
    message := FormatLogValue(message)

    logEntry := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        . " | type:dispatcher | level:" . level
        . " | " . message

    if IsSet(extra) {
        for k, v in extra
            logEntry .= " | " . FormatLogValue(k) . ":" . FormatLogValue(v)
    }

    try {
        FileAppend logEntry . "`n", GetLogPath(), "UTF-8"
    } catch as e {
        ; Nao chama DispatchLog aqui para evitar loop infinito se o log falhar.
        OutputDebug "[Dispatcher] DispatchLog falhou: " . e.Message
    }
}

FormatLogValue(v) {
    if IsObject(v) {
        try v := JSON.stringify(v)
        catch
            return "<object>"
    }

    v := String(v)
    v := StrReplace(v, "`r", "\r")
    v := StrReplace(v, "`n", "\n")
    v := StrReplace(v, "|", "\|")

    if (StrLen(v) > 500)
        v := SubStr(v, 1, 500) . "...<truncated>"

    return v
}

SendToUI(data) {
    global gWebView
    try {
        if !IsObject(gWebView)
            throw Error("gWebView indisponivel.")
        gWebView.PostWebMessageAsJson(JSON.stringify(data))
        return true
    } catch as e {
        DispatchLog("warn", "ui_send_failed", Map("error", e.Message))
        return false
    }
}

; ─── Dispatcher: App bootstrap ────────────────────────────────
InitializeApp() {
    global gScripts
    try {
        ValidateScriptHandlers(gScripts, GetScriptHandlers())
        DispatchLog("info", "app_initialized", Map("script_count", gScripts.Length))
        SendToUI(Map("type", "app_ready", "scripts", gScripts))
    } catch as e {
        DispatchLog("error", "app_initialize_failed", Map("error", e.Message))
        SendToUI(Map("type","error","message","Falha ao inicializar app: " . e.Message,"running",false))
    }
}

ValidateScriptHandlers(scripts, handlers) {
    if !(scripts is Array)
        throw Error("ValidateScriptHandlers: scripts deve ser Array.")

    if !(handlers is Map)
        throw Error("ValidateScriptHandlers: handlers deve ser Map.")

    scriptIds := Map()

    for script in scripts {
        if !(script is Map)
            throw Error("ValidateScriptHandlers: script deve ser Map.")

        id := Trim(script["id"])
        scriptIds[id] := true

        if !handlers.Has(id)
            throw Error("Script registrado sem handler: " . id)
    }

    for handlerId, handler in handlers {
        handlerId := Trim(handlerId)

        if !scriptIds.Has(handlerId)
            throw Error("Handler sem script registrado: " . handlerId)

        if !(handler is Map)
            throw Error("Handler deve ser Map: " . handlerId)

        if !handler.Has("name")
            throw Error("Handler sem name: " . handlerId)

        if (Trim(handler["name"]) = "")
            throw Error("Handler com name vazio: " . handlerId)

        if !handler.Has("fn")
            throw Error("Handler sem fn: " . handlerId)

        fn := handler["fn"]

        if !HasMethod(fn, "Call")
            throw Error("Handler fn nao chamavel: " . handlerId)
    }
}

; ─── Dispatcher: Script execution ────────────────────────────
RunScript(scriptId, params) {
    if IsObject(scriptId) {
        DispatchLog("warn", "route_invalid_request", Map("reason", "invalid_script_id_object"))
        SendToUI(Map("type","error","message","Requisicao invalida: script_id invalido.","running",IsAppRunning()))
        return
    }

    scriptId := Trim(scriptId)

    if (scriptId = "") {
        DispatchLog("warn", "route_invalid_request", Map("reason", "empty_script_id"))
        SendToUI(Map("type","error","message","Requisicao invalida: script_id ausente.","running",IsAppRunning()))
        return
    }

    if !RegExMatch(scriptId, IDENTIFIER_REGEX) {
        DispatchLog("warn", "route_invalid_request", Map("reason", "bad_script_id", "script_id", scriptId))
        SendToUI(Map("type","error","message","Requisicao invalida: script_id malformado.","running",IsAppRunning()))
        return
    }

    if !(params is Map) {
        DispatchLog("warn", "route_invalid_request", Map("reason", "invalid_params", "script_id", scriptId))
        SendToUI(Map("type","error","message","Requisicao invalida: params deve ser Map.","running",IsAppRunning()))
        return
    }

    DispatchLog("info", "route_request", Map("script_id", scriptId))

    if IsAppClosing() {
        DispatchLog("warn", "route_rejected", Map("reason", "app_closing", "script_id", scriptId))
        SendToUI(Map("type","error","message","Aplicativo esta fechando.","running",IsAppRunning()))
        return
    }

    handlers := GetScriptHandlers()

    if !handlers.Has(scriptId) {
        DispatchLog("warn", "route_not_found", Map("script_id", scriptId))
        SendToUI(Map("type","error","message","Script desconhecido: " . scriptId,"running",false))
        return
    }

    if IsAppRunning() {
        DispatchLog("warn", "route_rejected", Map("reason", "already_running", "script_id", scriptId))
        SendToUI(Map("type","error","message","Ja existe um script em execucao.","running",true))
        return
    }

    try {
        params := ValidateRunParams(scriptId, params)
    } catch as e {
        DispatchLog("warn", "route_invalid_params", Map("script_id", scriptId, "error", e.Message))
        SendToUI(Map("type","error","message","Parametros invalidos: " . e.Message,"running",false))
        return
    }

    if !TryBeginAppRun() {
        DispatchLog("warn", "route_rejected", Map("reason", "already_running", "script_id", scriptId))
        SendToUI(Map("type","error","message","Ja existe um script em execucao.","running",true))
        return
    }

    DispatchLog("info", "route_start", Map("script_id", scriptId))

    uiFinalSent := false

    try {
        SendToUI(Map("type","status","message","Iniciando...","running",true))

        handler := handlers[scriptId]
        RunScriptHandler(scriptId, handler["name"], handler["fn"], params)

        SendToUI(Map("type","status","message","Concluido.","running",false))
        uiFinalSent := true
    } catch as e {
        if (e is AppStoppedError) {
            DispatchLog("info", "route_stopped", Map("script_id", scriptId))
            SendToUI(Map("type","status","message",e.Message,"running",false))
            uiFinalSent := true
            return
        }

        DispatchLog("error", "route_failed", Map("script_id", scriptId, "error", e.Message))
        SendToUI(Map("type","error","message","Erro interno: " . e.Message,"running",false))
        uiFinalSent := true
    } finally {
        EndAppRun()

        if !uiFinalSent
            SendToUI(Map("type","status","running",false))
    }
}

RunScriptHandler(scriptId, handlerName, handlerFn, params) {
    DispatchLog("info", "route_match", Map("script_id", scriptId, "handler", handlerName))
    handlerFn.Call(params)
}

GetScriptHandlers() {
    static handlers := Map(
        "remessa_protocolo", Map("name", "RunRemessaProtocolo", "fn", RunRemessaProtocolo),
        "protocolar",        Map("name", "RunProtocolar",        "fn", RunProtocolar),
        "fechar_xml",        Map("name", "RunFecharXML",         "fn", RunFecharXML)
    )

    return handlers
}

GetScriptSpec(scriptId) {
    global gScripts

    for script in gScripts {
        if (script["id"] = scriptId)
            return script
    }

    return ""
}

ValidateRunParams(scriptId, params) {
    spec := GetScriptSpec(scriptId)

    if !IsObject(spec)
        throw ValueError("Catalogo nao contem script: " . scriptId, -1, scriptId)

    cleanParams := Map()

    for paramSpec in spec["params"] {
        paramId := paramSpec["id"]

        hasValue := params.Has(paramId)
        raw := hasValue ? params[paramId] : ""
        value := ""

        if hasValue {
            if IsObject(raw)
                throw TypeError("Param deve ser valor escalar", -1, raw)

            value := Trim(String(raw))
        }

        if (paramSpec["obrigatorio"] && value = "")
            throw ValueError("Parametro obrigatorio ausente: " . paramId, -1, paramId)

        if (value != "") {
            if (paramSpec["tipo"] = "select")
                ValidateSelectParam(paramSpec, paramId, value)
            else if (paramSpec["tipo"] = "date")
                ValidateDateParam(paramSpec, paramId, value)
        }

        if hasValue || paramSpec["obrigatorio"]
            cleanParams[paramId] := value
    }

    return cleanParams
}

ValidateSelectParam(paramSpec, paramId, value) {
    for opcao in paramSpec["opcoes"] {
        if (value = opcao)
            return
    }

    throw ValueError("Opcao invalida em " . paramId . ": " . value, -1, value)
}

ValidateDateParam(paramSpec, paramId, value) {
    format := paramSpec["format"]

    if (format != "yyyy-MM-dd")
        throw ValueError("Formato de data nao suportado em " . paramId . ": " . format, -1, format)

    if !IsIsoDate(value)
        throw ValueError("Data invalida em " . paramId . ": " . value, -1, value)
}

IsIsoDate(value) {
    if !RegExMatch(value, "^(\d{4})-(\d{2})-(\d{2})$", &m)
        return false

    y  := Integer(m[1])
    mo := Integer(m[2])
    d  := Integer(m[3])

    if (mo < 1 || mo > 12)
        return false

    days := [31,28,31,30,31,30,31,31,30,31,30,31]
    maxDay := days[mo]

    if (mo = 2 && IsLeapYear(y))
        maxDay := 29

    return d >= 1 && d <= maxDay
}

IsLeapYear(y) {
    return (Mod(y, 4) = 0 && Mod(y, 100) != 0) || Mod(y, 400) = 0
}

StopScript() {
    wasRunning := IsAppRunning()

    if !wasRunning {
        DispatchLog("info", "route_stop_ignored", Map("reason", "not_running"))
        SendToUI(Map("type","status","message","Nenhuma execucao em andamento.","running",false))
        return
    }

    if IsStopRequested() {
        DispatchLog("info", "route_stop_ignored", Map("reason", "already_requested"))
        SendToUI(Map("type","status","message","Interrupcao ja solicitada.","running",true))
        return
    }

    RequestAppStop()
    DispatchLog("info", "route_stop", Map("was_running", true))
    SendToUI(Map("type","status","message","Interrompendo...","running",true))
}
