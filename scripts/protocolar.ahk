#Requires AutoHotkey v2.0

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

    remessas := Protocolar_ParseRemessas(params["remessas"])
    setorAtual := Trim(params["setor_atual"])
    setorEnvio := Trim(params["setor_envio"])

    if (remessas.Length = 0)
        return Protocolar_Abort("Informe o número das remessas. Ex: 511458, 514015")
    if (setorAtual = "")
        return Protocolar_Abort("Informe o setor atual. Ex: 34")
    if (setorEnvio = "")
        return Protocolar_Abort("Informe o setor de envio. Ex: 365")
    if (setorAtual = setorEnvio)
        return Protocolar_Abort("O setor atual e o setor de envio devem ser diferentes.")

    SendToUI(Map("type", "log", "message", "Protocolar: " . remessas.Length . " remessa(s) do setor " . setorAtual . " para o setor " . setorEnvio . "."))
    return Protocolar_Abort("Parâmetros recebidos. Falta implementar a automação do MV para Protocolar com os controles do Window Spy.")
}

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
