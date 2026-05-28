#Requires AutoHotkey v2.0

; Cadastro compartilhado de erros visuais do FFCV Inserir Conta.
;
; Como adicionar novo erro:
; 1) Deixe o modal Forms aberto no MV.
; 2) Faça um crop APENAS da frase do erro e salve em:
;      images\Nome_Do_Erro_Texto.png
; 3) Adicione um Map em FFCV_ErrorTemplates(), mantendo tipo/descricao/img.
; 4) Rode test_macros\13_ffcv_error_popup_detect.ahk para validar.
;
; Observação: WinGetText/Window Spy normalmente expõem só &OK nesses modais.
; O contrato confiável é template visual dentro da janela modal.

FFCV_ErrorTemplates_ProjectRoot() {
    dir := A_ScriptDir
    if RegExMatch(dir, "\\(test_macros|scripts|lib)$")
        return RegExReplace(dir, "\\(test_macros|scripts|lib)$", "")
    return dir
}

FFCV_ErrorTemplates() {
    root := FFCV_ErrorTemplates_ProjectRoot()
    templates := []

    contaJaDigitada := root "\images\Erro_Conta_Ja_Digitada_Texto.png"
    if FileExist(contaJaDigitada) {
        templates.Push(Map(
            "tipo", "conta_ja_digitada",
            "descricao", "Conta já digitada / redigite",
            "img", contaJaDigitada
        ))
    }

    contaAberta := root "\images\Erro_Conta_Aberta_Texto.png"
    if FileExist(contaAberta) {
        templates.Push(Map(
            "tipo", "conta_aberta",
            "descricao", "Conta aberta",
            "img", contaAberta
        ))
    }

    contaJaEmRemessa := root "\images\Erro_Conta_Ja_Em_Remessa_Texto.png"
    if FileExist(contaJaEmRemessa) {
        templates.Push(Map(
            "tipo", "conta_em_remessa",
            "descricao", "Conta já em remessa",
            "img", contaJaEmRemessa
        ))
    }

    agrupamentoDiferente := root "\images\Erro_Conta_De_Agrupamento_Diferente_Texto.png"
    if FileExist(agrupamentoDiferente) {
        templates.Push(Map(
            "tipo", "agrupamento_diferente",
            "descricao", "Agrupamento de conta diferente",
            "img", agrupamentoDiferente
        ))
    }

    tipoDiferente := root "\images\Erro_Conta_De_Tipo_Diferente_Texto.png"
    if FileExist(tipoDiferente) {
        templates.Push(Map(
            "tipo", "conta_tipo_diferente,
            "descricao", "Conta de tipo diferente",
            "img", tipoDiferente
        ))
    }

    return templates
}

FFCV_ClassifyErrorModal(winTitle := "ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE", variation := 50) {
    ; Não tentar ler texto do modal: Oracle Forms expõe só botões como &OK.
    ; O título/classe detecta que houve erro; a mensagem vem apenas do template visual.
    for _, tpl in FFCV_ErrorTemplates() {
        imagePath := tpl["img"]
        if FFCV_ErrorTemplateVisible(imagePath, winTitle, variation)
            return Map("tipo", tpl["tipo"], "descricao", tpl["descricao"], "fonte", "template visual", "texto", "", "img", imagePath)
    }

    return Map("tipo", "erro_desconhecido", "descricao", "Erro modal não classificado", "fonte", "sem template correspondente", "texto", "", "img", "")
}

FFCV_ErrorTemplateVisible(imagePath, winTitle := "ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE", variation := 100) {
    if !FileExist(imagePath)
        return false

    screenWidth := A_ScreenWidth
    screenHeight := A_ScreenHeight

    CoordMode "Pixel", "Screen"
    ; Não usar *Trans sem cor: em AHK v2 isso torna a busca frágil e pode falhar em silêncio.
    searchOptions := "*" variation " " imagePath
    if WinExist(winTitle) {
        try WinGetPos &wx, &wy, &ww, &wh, winTitle
        catch
            wx := 0, wy := 0, ww := screenWidth, wh := screenHeight

        x1 := wx > 20 ? wx - 20 : 0
        y1 := wy > 20 ? wy - 20 : 0
        x2 := Min(wx + ww + 20, screenWidth)
        y2 := Min(wy + wh + 20, screenHeight)

        try return ImageSearch(&x, &y, x1, y1, x2, y2, searchOptions)
        catch
            return false
    }

    ; Sem modal conhecido, faça uma única busca global como fallback de diagnóstico.
    try return ImageSearch(&x, &y, 0, 0, screenWidth, screenHeight, searchOptions)
    catch
        return false
}

FFCV_SafeWinGetText(winTitle) {
    try text := WinGetText(winTitle)
    catch as e
        return "<erro WinGetText: " e.Message ">"

    text := Trim(text)
    if (text = "" || text = "&OK" || text = "&Sim`r`n&Não" || text = "&Não`r`n&Sim")
        return text "`n<observação: Oracle Forms pode desenhar a mensagem em ui60Drawn; WinGetText pode expor só botões.>"
    return text
}
