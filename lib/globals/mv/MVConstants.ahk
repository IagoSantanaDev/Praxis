; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug

; ════════════════════════════════════════════════════════════════
;  MV CONSTANTS — constantes centralizadas do módulo MV
; ════════════════════════════════════════════════════════════════

; ── Janelas ───────────────────────────────────────────────────
; Para detecção inicial, nunca exigir subtela exata.
; O usuário pode ter deixado MOV DOC/FFCV aberto em qualquer tela interna.
MV_WIN_MOVDOC_ANY     := "Movimentação ahk_exe ifrun60.EXE"
MV_WIN_FFCV_ANY       := "Faturamento ahk_exe ifrun60.EXE"

; Títulos específicos só devem ser usados depois de navegar para a tela esperada.
MV_WIN_MOVDOC_BAIXA   := "Protocolação de Baixa de Documentos ahk_exe ifrun60.EXE"
MV_WIN_FFCV_REMESSA   := "MV2000i - Faturamento ahk_exe ifrun60.EXE"

; ── Controles de popups conhecidos ────────────────────────────
MV_MODAL_OK_CLASS     := "Button1"
MV_CLASS_MODAL_FORMS  := "ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"

; ── Polling / estabilidade ────────────────────────────────────
MV_POLL_MS            := 100
; MV_TIMEOUT_LOAD (15s) aguarda o carregamento sem a espera excessiva de 100s
; MV_TIMEOUT_ACOE (10s) aguarda apenas o fechamento do modal já renderizado.
MV_TIMEOUT_LOAD       := 15
MV_TIMEOUT_ACOE       := 10
MV_DELAY_INPUT        := 100
MV_MODULE_STABLE_MS   := 600
MV_TARGET_STABLE_MS   := 600
