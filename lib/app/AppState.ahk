#Requires AutoHotkey v2.0
#Warn All, OutputDebug
; ============================================================
; Praxis Application State
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.
; Proprietary and confidential. All rights reserved.

; Centraliza os globais de estado do Praxis e é incluído no início para disponibilizá-los aos demais módulos.
; ============================================================

; ─── Application lifecycle ───────────────────────────────────
global gRunning := false
global gStopRequested := false

; ─── Close coordination ─────────────────────────────────────────
; gExitAfterStop e gExitDeadline são globais compartilhados entre App.ahk e Dispatcher.ahk,
; permitindo controlar o shutdown e bloquear novas execuções durante o fechamento.
global gExitAfterStop := false
global gExitDeadline  := 0

; ─── Runtime integrity ───────────────────────────────────────
; O manifesto é incluído após as declarações, garantindo que o Map esteja inicializado.
; gIntegritySilentMode foi removida por não ser utilizada.
global gIntegrityExpectedFiles := Map()

; ─── Lifecycle helpers ─────────────────────────────────────────
IsAppRunning() {
    global gRunning
    return gRunning
}

SetAppRunning(state) {
    global gRunning
    gRunning := !!state
}

; TryBeginAppRun controla atomicamente gRunning com Critical, 
; impedindo execuções simultâneas e retornando true se iniciar ou
; false se já estiver em execução..
TryBeginAppRun() {
    Critical "On"
    try {
        if IsAppRunning()
            return false

        SetAppRunning(true)
        ClearAppStop()
        return true
    } finally {
        Critical "Off"
    }
}

; EndAppRun: encerra execucao e limpa flag de stop em transicao atomica.
EndAppRun() {
    Critical "On"
    try {
        SetAppRunning(false)
        ClearAppStop()
    } finally {
        Critical "Off"
    }
}

IsStopRequested() {
    global gStopRequested
    return gStopRequested
}

RequestAppStop() {
    global gStopRequested
    Critical "On"
    try {
        gStopRequested := true
    } finally {
        Critical "Off"
    }
}

ClearAppStop() {
    global gStopRequested
    Critical "On"
    try {
        gStopRequested := false
    } finally {
        Critical "Off"
    }
}

class AppStoppedError extends Error {
}

ThrowIfAppStopped() {
    if IsStopRequested()
        throw AppStoppedError("Execucao interrompida pelo usuario.")
}

; IsAppClosing: true entre OnAppClose e o fim de PollExitAfterStop.
; Usado pelo Dispatcher para rejeitar RunScript durante a janela de shutdown.
IsAppClosing() {
    global gExitAfterStop
    return gExitAfterStop
}

RequestAppClose() {
    global gExitAfterStop
    Critical "On"
    try {
        gExitAfterStop := true
    } finally {
        Critical "Off"
    }
}

ClearAppClose() {
    global gExitAfterStop, gExitDeadline
    Critical "On"
    try {
        gExitAfterStop := false
        gExitDeadline  := 0
    } finally {
        Critical "Off"
    }
}
