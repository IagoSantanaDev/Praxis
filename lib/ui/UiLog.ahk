; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug
#Include %A_LineFile%\..\UiBridge.ahk

; ─── Notificacoes visuais (log / progress / done) ─────────────

; ─── Logging MV ─────────────────────────────────────────────
; Mantém a API usada pelos módulos MV, mas encaminha para o logger
; canônico do Dispatcher em vez de descartar diagnósticos.
Log_Info(msg) {
    DispatchLog("info", "mv_log", Map("message", String(msg)))
}

Log_Warn(msg) {
    DispatchLog("warn", "mv_log", Map("message", String(msg)))
}

Log_Error(msg) {
    DispatchLog("error", "mv_log", Map("message", String(msg)))
}

; ─── Notificacoes visuais (log / progress / done) ─────────────

Notify(msg) {
    SendToUI(Map("type", "log", "message", msg))
}

Progress(v) {
    static lastProgress := ""
    normalized := Max(0, Min(100, Round(v)))
    if (lastProgress != "" && normalized = lastProgress)
        return
    lastProgress := normalized
    SendToUI(Map("type", "progress", "value", normalized))
}

Done(msg) {
    SendToUI(Map("type", "done", "message", msg))
}
