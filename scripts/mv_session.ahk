#Requires AutoHotkey v2.0

; ============================================================================
; Projeto: Praxis
; Arquivo: mv_session.ahk
; Descrição: utilitários de sessão, login e interação inicial com o MV2000i.
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
;  MV SESSION — módulo compartilhado
;  Substitua os valores marcados com ; << pelo Window Spy
; ════════════════════════════════════════════════════════════════

; ── Executável e janelas ──────────────────────────────────────
MV_EXE_PATH       := "C:\Caminho\Para\MV2000i.exe"   ; <<
MV_WIN_LOGIN      := "Identificação"                  ; <<
MV_WIN_PRINCIPAL  := "TÍTULO JANELA PRINCIPAL MV"     ; <<
MV_WIN_MOVDOC     := "TÍTULO JANELA MOV DOC"          ; <<
MV_WIN_FFCV       := "TÍTULO JANELA FFCV"             ; <<

; ── Controles da tela de login ────────────────────────────────
MV_LOGIN_USUARIO  := "CLASSNN_CAMPO_USUARIO"          ; <<
MV_LOGIN_SENHA    := "CLASSNN_CAMPO_SENHA"            ; <<
MV_LOGIN_BANCO    := "CLASSNN_CAMPO_BANCO"            ; << (se houver)
MV_LOGIN_CONFIRMA := "CLASSNN_BTN_CONFIRMAR"          ; <<

; ── Como abrir cada módulo a partir da janela principal ───────
; Preencha com Send, ControlClick, MenuSelect, etc.
; Deixe como função para facilitar a manutenção.
MV_AbrirMovDoc() {
    ; << Ex: MenuSelect(MV_WIN_PRINCIPAL, , "Módulos", "MOV DOC")
    ; << Ex: Send "!m" seguido da tecla do item
    ; << Ex: ControlClick "CLASSNN_BTN_MOVDOC", MV_WIN_PRINCIPAL
}

MV_AbrirFFCV() {
    ; << Ex: MenuSelect(MV_WIN_PRINCIPAL, , "Módulos", "FFCV")
}

; ── Polling ───────────────────────────────────────────────────
MV_POLL_MS      := 50    ; intervalo de checagem — não altere
MV_TIMEOUT_LOAD := 20    ; segundos para telas/módulos carregarem
MV_TIMEOUT_ACOE := 10    ; segundos para ações (popups, confirmações)
MV_DELAY_INPUT  := 80    ; ms obrigatório após input antes de checar resultado

; ════════════════════════════════════════════════════════════════
;  API PÚBLICA — use estas funções nos scripts
; ════════════════════════════════════════════════════════════════

; Garante que o MOV DOC está aberto e ativo.
; Retorna true se pronto, false se falhou.
MV_EnsureMovDoc() {
    if MV_WinReady(MV_WIN_MOVDOC) {
        WinActivate MV_WIN_MOVDOC
        return true
    }
    if !MV_EnsurePrincipal()
        return false
    MV_AbrirMovDoc()
    return MV_Poll(() => WinExist(MV_WIN_MOVDOC), MV_TIMEOUT_LOAD)
}

; Garante que o FFCV está aberto e ativo.
MV_EnsureFFCV() {
    if MV_WinReady(MV_WIN_FFCV) {
        WinActivate MV_WIN_FFCV
        return true
    }
    if !MV_EnsurePrincipal()
        return false
    MV_AbrirFFCV()
    return MV_Poll(() => WinExist(MV_WIN_FFCV), MV_TIMEOUT_LOAD)
}

; ════════════════════════════════════════════════════════════════
;  INTERNO — não chame diretamente nos scripts
; ════════════════════════════════════════════════════════════════

; Garante que a janela principal do MV está aberta (faz login se necessário).
MV_EnsurePrincipal() {
    if MV_WinReady(MV_WIN_PRINCIPAL)
        return true

    ; MV não está aberto — inicia
    if !MV_WinReady(MV_WIN_LOGIN) {
        Run MV_EXE_PATH
        if !MV_Poll(() => WinExist(MV_WIN_LOGIN), MV_TIMEOUT_LOAD)
            return false
    }

    return MV_DoLogin()
}

; Executa o login com as credenciais salvas em memória (gUser / gPass).
MV_DoLogin() {
    global gUser, gPass

    WinActivate MV_WIN_LOGIN
    if !MV_Poll(() => WinActive(MV_WIN_LOGIN), 5)
        return false

    ControlSetText gUser, MV_LOGIN_USUARIO, MV_WIN_LOGIN
    ControlSetText "",    MV_LOGIN_SENHA,   MV_WIN_LOGIN
    ControlSetText gPass, MV_LOGIN_SENHA,   MV_WIN_LOGIN

    ; Pequeno delay obrigatório — garante que o MV registrou o input
    ; antes do clique (não é espera de resultado, é estabilização de UI)
    Sleep MV_DELAY_INPUT

    ControlClick MV_LOGIN_CONFIRMA, MV_WIN_LOGIN,,,, "NA"

    ; Polling até a janela principal aparecer OU o login falhar
    ; (janela de login sumindo sem a principal = erro de credencial)
    deadline := A_TickCount + MV_TIMEOUT_LOAD * 1000
    Loop {
        if WinExist(MV_WIN_PRINCIPAL)
            return true
        if !WinExist(MV_WIN_LOGIN)
            return false   ; login sumiu sem abrir principal = estado inesperado
        if A_TickCount > deadline
            return false
        Sleep MV_POLL_MS
    }
}

; Checa se uma janela existe e não está minimizada.
MV_WinReady(title) {
    if !WinExist(title)
        return false
    return WinGetMinMax(title) != -1
}

; ── Polling genérico ─────────────────────────────────────────
; Executa condFn a cada MV_POLL_MS ms até retornar true ou timeout.
; condFn é uma função sem parâmetros: () => expressão_booleana
; Retorna true se a condição foi satisfeita, false se timeout.
MV_Poll(condFn, timeoutSecs) {
    deadline := A_TickCount + timeoutSecs * 1000
    Loop {
        if condFn()
            return true
        if A_TickCount > deadline
            return false
        Sleep MV_POLL_MS
    }
}

; Versão que aguarda qualquer uma de uma lista de janelas.
; Retorna o título que apareceu, ou "" se timeout.
MV_WaitAnyWindow(titles, timeoutSecs) {
    deadline := A_TickCount + timeoutSecs * 1000
    Loop {
        for title in titles {
            if WinExist(title)
                return title
        }
        if A_TickCount > deadline
            return ""
        Sleep MV_POLL_MS
    }
}
