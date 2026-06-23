; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug

; ════════════════════════════════════════════════════════════════
;  PROTOCOLAR PARSERS
;  Lógica de parsing para o módulo Protocolar
; ════════════════════════════════════════════════════════════════

Protocolar_ParseRemessas(str) {
    result := []
    for _, item in StrSplit(str, ",") {
        remessa := Trim(item)
        if (remessa != "")
            result.Push(remessa)
    }
    return result
}

Protocolar_Abort(msg) {
    global gRunning
    SendToUI(Map("type", "error", "message", msg))
    SendToUI(Map("type", "status", "message", "Execução finalizada.", "running", false))
    gRunning := false
    return false
}
