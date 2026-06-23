; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug
#Include %A_LineFile%\..\UiBridge.ahk

; ─── Notificacoes visuais (log / progress / done) ─────────────

; ─── Logging stubs ──────────────────────────────────────────
; Log_Info, Log_Warn e Log_Error sao chamados em diversos modulos MV via #Include
; mas nunca definidos. stubs aqui satisfazem #Warn e mantem retrocompatibilidade.
Log_Info(msg) {
    ; no-op: todas as chamadas estao dentro de try{}.
}

Log_Warn(msg) {
    ; no-op: todas as chamadas estao dentro de try{}.
}

Log_Error(msg) {
    ; no-op: todas as chamadas estao dentro de try/catch.
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
