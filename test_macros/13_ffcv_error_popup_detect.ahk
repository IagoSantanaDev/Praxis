; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_ScriptDir%\..\lib\FFCV_ErrorTemplates.ahk

; TESTE 13 - Detectar/classificar erro do modal Forms na inserção FFCV
;
; Uso:
; 1) Deixe aberto o modal de erro que aparece após enviar uma conta no popup "Informações da Conta".
; 2) Rode este arquivo.
; 3) Ele compara os templates cadastrados em lib\FFCV_ErrorTemplates.ahk.
; 4) Salva relatório em test_macros\ultimo_erro_ffcv.txt e copia para clipboard.
;
; Para adicionar novo erro:
; - Salve um crop da frase do erro direto em images\.
; - Adicione o Map correspondente em lib\FFCV_ErrorTemplates.ahk.
; - Rode este macro de novo para validar.
;
; Segurança: por padrão não fecha modal.

SetTitleMatchMode 2
DetectHiddenText true
SetControlDelay 0
SetWinDelay 0
SetKeyDelay 0, 0

WIN_MODAL := "ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"
DO_DISMISS_MODAL := false
VARIATION := 50
MODAL_OK_CLASS := "Button1"

report := "SUÍTE: FFCV - detectar erro visual do modal de inserção`n"
        . "Timestamp: " FormatTime(, "yyyy-MM-dd HH:mm:ss") "`n"
        . "Alvo: " WIN_MODAL "`n"
        . "DO_DISMISS_MODAL=" DO_DISMISS_MODAL " VARIATION=" VARIATION "`n`n"

if !WinExist(WIN_MODAL) {
    report .= "❌ Nenhum modal Forms do Oracle/MV está aberto.`n"
    report .= "Abra o erro de inserção de conta no FFCV e rode novamente.`n"
    SaveAndShow(report)
    ExitApp
}

try title := WinGetTitle(WIN_MODAL)
catch as e
    title := "<erro título: " e.Message ">"
try className := WinGetClass(WIN_MODAL)
catch as e
    className := "<erro classe: " e.Message ">"
try processName := WinGetProcessName(WIN_MODAL)
catch as e
    processName := "<erro processo: " e.Message ">"
try WinGetPos &wx, &wy, &ww, &wh, WIN_MODAL
catch {
    wx := "?", wy := "?", ww := "?", wh := "?"
}

report .= "JANELA`n"
report .= "Title: " title "`n"
report .= "Class: " className "`n"
report .= "Process: " processName "`n"
report .= "Rect screen: x=" wx " y=" wy " w=" ww " h=" wh "`n`n"

report .= "OBSERVAÇÃO`n"
report .= "O texto do modal Forms não é lido: Oracle Forms normalmente expõe só botões como &OK. A classificação abaixo usa apenas templates visuais.`n`n"

report .= "TEMPLATES CADASTRADOS`n"
templates := FFCV_ErrorTemplates()
if (templates.Length = 0) {
    report .= "⚠️ Nenhum template cadastrado em lib\\FFCV_ErrorTemplates.ahk.`n"
} else {
    for idx, tpl in templates {
        exists := FileExist(tpl["img"])
        visible := exists ? FFCV_ErrorTemplateVisible(tpl["img"], WIN_MODAL, VARIATION) : false
        report .= idx ". tipo=" tpl["tipo"] " | descricao=" tpl["descricao"] "`n"
        report .= "   img=" tpl["img"] "`n"
        report .= "   arquivo=" (exists ? "existe" : "NÃO EXISTE") " | visível=" (visible ? "SIM" : "não") "`n"
    }
}

classified := FFCV_ClassifyErrorModal(WIN_MODAL, VARIATION)
report .= "`nCLASSIFICAÇÃO FINAL`n"
report .= "tipo=" classified["tipo"] "`n"
report .= "descricao=" classified["descricao"] "`n"
report .= "fonte=" classified["fonte"] "`n"
if (classified["img"] != "")
    report .= "template=" classified["img"] "`n"

if DO_DISMISS_MODAL {
    report .= "`nAÇÃO`n"
    if ClickFirstControl(WIN_MODAL, MODAL_OK_CLASS)
        report .= "✅ Button1 clicado para fechar modal.`n"
    else
        report .= "❌ Não consegui clicar Button1 do modal.`n"
} else {
    report .= "`nAÇÃO`nModo seguro: modal não foi fechado. Coloque DO_DISMISS_MODAL := true se quiser validar fechamento.`n"
}

SaveAndShow(report)

ClickFirstControl(winTitle, classNN) {
    try hwnds := WinGetControlsHwnd(winTitle)
    catch
        return false

    for hwnd in hwnds {
        try ctrlClass := ControlGetClassNN(hwnd)
        catch
            continue
        if (ctrlClass = classNN) {
            ControlClick hwnd,,,,, "NA"
            return true
        }
    }
    return false
}

SaveAndShow(content) {
    logPath := A_ScriptDir "\ultimo_erro_ffcv.txt"
    try FileDelete logPath
    FileAppend content, logPath, "UTF-8"
    A_Clipboard := content
    MsgBox content "`n`nCopiado para o clipboard e salvo em:`n" logPath, "Erro FFCV", "Iconi"
}
