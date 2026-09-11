; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug

#Include %A_LineFile%\..\..\app\Dispatcher.ahk

global gWebView

; ─── JS → AHK ─────────────────────────────────────────────────
OnJsMessage(handler, args) {
    raw  := args.TryGetWebMessageAsString()
    data := JSON.parse(raw)

    switch data["action"] {
        case "ready":       InitializeApp()
        case "run_script":  RunScript(data["scriptId"], data["params"])
        case "stop_script": StopScript()
        case "exit":        OnAppClose("")
    }
}
