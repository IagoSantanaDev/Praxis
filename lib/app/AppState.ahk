#Requires AutoHotkey v2.0
#Warn All, OutputDebug
; ============================================================
; Praxis Application State
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.
; Proprietary and confidential. All rights reserved.
;
; Central state globals for the Praxis application.
; This module is included early via #Include *i to ensure
; state is available to all subsequent includes.
; ============================================================

; ─── Application lifecycle ───────────────────────────────────
global gRunning := false
global gStopRequested := false

; ─── Close coordination ─────────────────────────────────────────
; gExitAfterStop e gExitDeadline sao compartilhados entre App.ahk (que arma
; OnAppClose/PollExitAfterStop) e Dispatcher.ahk (que consulta IsAppClosing()
; para rejeitar RunScript durante a janela de shutdown). Declarados aqui para
; ficarem disponiveis em todos os entry points (main.ahk e cli-check.ahk).
global gExitAfterStop := false
global gExitDeadline  := 0

; ─── Runtime integrity ───────────────────────────────────────
; Loaded as #Include *i from build/generated/Praxis_IntegrityManifest.ahk
; after these declarations so the Map is already initialized.
; Auditoria 2026-06-27 (M5): gIntegritySilentMode removida (declarada mas
; nunca referenciada — LogWrite de cli-check.ahk sempre executa independente).
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

; TryBeginAppRun: transicao atomica check-then-set de gRunning.
; Usa Critical para serializar entre threads AHK no mesmo processo.
; Retorna true se conseguiu iniciar; false se ja havia execucao ativa.
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
