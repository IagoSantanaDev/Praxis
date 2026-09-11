; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug

; ─── Application timing constants ────────────────────────────
AWAIT_POLL_MS             := 100       ; intervalo de polling de AwaitPromise
WEBVIEW2_ENV_TIMEOUT_MS   := 15000     ; timeout de WebView2.CreateEnvironment
WEBVIEW2_CTRL_TIMEOUT_MS  := 15000     ; timeout de WebView2.CreateController
RESIZE_DEBOUNCE_MS        := 50        ; debounce negativo de OnGuiResize
CLOSE_HANDLER_TIMEOUT_MS  := 60000     ; deadline para handler terminar ao fechar
POLL_EXIT_INTERVAL_MS     := 100       ; intervalo de PollExitAfterStop
UI_CLOSE_ACK_TIMEOUT_MS   := 2000      ; prazo para a UI confirmar o fechamento
