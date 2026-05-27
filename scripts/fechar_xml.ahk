#Requires AutoHotkey v2.0

; ============================================================================
; Projeto: Praxis
; Arquivo: fechar_xml.ahk
; Descrição: automação do fluxo de fechamento de remessa e geração de XML.
;
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
;
; Este arquivo integra o software proprietário Praxis.
; O acesso ao código-fonte não concede licença de uso, cópia, modificação,
; redistribuição, engenharia reversa, criação de obras derivadas ou
; exploração comercial sem autorização prévia e expressa por escrito.
;
; Consulte: LICENSE, COPYRIGHT, NOTICE.md, EULA.md, NDA.md,
; PRIVACY_LGPD.md e THIRD_PARTY_NOTICES.md.
; ============================================================================

; ════════════════════════════════════════════════════════════════
;  FECHAR E GERAR XML
; ════════════════════════════════════════════════════════════════
; Parâmetros da tela:
;   remessas         -> números das remessas separados por vírgula. Ex: 511458, 514015
;   data_entrega    -> data de entrega
;   data_vencimento -> data de vencimento
;
; A automação operacional no MV ainda depende dos títulos e ClassNN reais
; capturados pelo Window Spy.

RunFecharXML(params) {
    global gRunning

    remessas := FecharXML_ParseRemessas(params["remessas"])
    dataEntrega := Trim(params["data_entrega"])
    dataVencimento := Trim(params["data_vencimento"])

    if (remessas.Length = 0)
        return FecharXML_Abort("Informe o número das remessas. Ex: 511458, 514015")
    if (dataEntrega = "")
        return FecharXML_Abort("Informe a data de entrega.")
    if (dataVencimento = "")
        return FecharXML_Abort("Informe a data de vencimento.")

    SendToUI(Map("type", "log", "message", "Fechar e Gerar XML: " . remessas.Length . " remessa(s), entrega " . dataEntrega . ", vencimento " . dataVencimento . "."))
    return FecharXML_Abort("Parâmetros recebidos. Falta implementar a automação do MV para fechar e gerar XML com os controles do Window Spy.")
}

FecharXML_ParseRemessas(str) {
    result := []
    for _, item in StrSplit(str, ",") {
        remessa := Trim(item)
        if (remessa != "")
            result.Push(remessa)
    }
    return result
}

FecharXML_Abort(msg) {
    global gRunning
    SendToUI(Map("type", "error", "message", msg))
    SendToUI(Map("type", "status", "message", "Execução finalizada.", "running", false))
    gRunning := false
    return false
}
