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
MV_WIN_MOVDOC_ENVIO   := "Protocolação de Envio de Documentos ahk_exe ifrun60.EXE"
MV_WIN_FFCV_REMESSA   := "MV2000i - Faturamento ahk_exe ifrun60.EXE"

; ── Relatório de atendimentos da remessa ─────────────────────
; Contrato compartilhado por todos os fluxos que imprimem remessa.
MV_WIN_RELATORIO_REMESSA   := "Relatório de Atendimentos da Remessa ahk_exe ifrun60.EXE"
MV_WIN_PROGRESSO_RELATORIO := "Andamento do Relatório ahk_exe RWRBE60.EXE"
MV_PROCESSO_RELATORIO      := "RWRBE60.EXE"
MV_BTN_IMPRIMIR_RELATORIO  := "Button2"

; ── Controles de popups conhecidos ────────────────────────────
MV_MODAL_OK_CLASS     := "Button1"
MV_CLASS_MODAL_FORMS  := "ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"

; ── Popup "Informações da Conta" (embarcado na janela FFCV) ───
; Sentinel: painel desenhado ui60Drawn W323 dentro da janela principal FFCV.
; Validados por captura do usuário (macro 11). Fonte unica — fazia parte
; de Popups.ahk/FfcvScreen.ahk/FfcvContaPopup.ahk em 3 copias identicas.
MV_POPUP_CONTA_SENTINEL_CLASS := "ui60Drawn W323"
MV_POPUP_CONTA_SENTINEL_X     := 432
MV_POPUP_CONTA_SENTINEL_Y     := 109
MV_POPUP_CAMPO_CONTA          := "Edit2"
MV_POPUP_CAMPO_CONTA_X        := 298
MV_POPUP_CAMPO_CONTA_Y        := 143
MV_POPUP_DROPDOWN_TIPO        := "ComboBox2"
MV_POPUP_DROPDOWN_TIPO_X      := 84
MV_POPUP_DROPDOWN_TIPO_Y      := 143
MV_POPUP_DROPDOWN_SUB_TIPO    := "ComboBox1"
MV_POPUP_DROPDOWN_SUB_TIPO_X  := 190
MV_POPUP_DROPDOWN_SUB_TIPO_Y  := 143
MV_POPUP_BTN_OK               := "Button1"   ; modal de aviso/erro do popup

; ── Botao "Inserir Conta" da Manutencao de Remessa ────────────
MV_BTN_ADICIONAR_CONTA := "Button10"
MV_BTN_ADICIONAR_CONTA_X := 24
MV_BTN_ADICIONAR_CONTA_Y := 458

; ── Mapeamento Tipo de Conta ───────────────────────────────────
; Fonte unica do codigo de tipo de conta. Conflito historico:
; test_macros/11 usava Emergencia->1, Internamento->2; lib sempre
; usou Internamento->1, Emergencia->2. Valor de negocio correto:
; Internamento=1, Emergencia=2, Ambulatorio=3.
MV_TIPO_CONTA := Map(
    "Internamento", 1,
    "Emergência",   2,
    "Ambulatório",  3)

; ── Timings de campo (Oracle Forms) ─────────────────────────────
; Familia unica das antigas FFCV_FIELD_*/MOVDOC_FIELD_*/FFCVP_FIELD_*/
; RP_FIELD_* (4 copias identicas com valor 100).
MV_FIELD_FOCUS_SETTLE_MS := 100
MV_FIELD_CLEAR_SETTLE_MS := 100
MV_KEY_SETTLE_MS         := 100

; ── Timings do popup de conta ───────────────────────────────────
; Familia unica das antigas FFCV_CONTA_*/FFCVP_CONTA_*/POPUP_STABLE_MS.
MV_CONTA_FOCUS_SETTLE_MS      := 100
MV_CONTA_CLEAR_SETTLE_MS      := 100
MV_CONTA_READY_MIN_MS         := 180
MV_CONTA_FIELD_EMPTY_MIN_MS   := 100
MV_CONTA_STABLE_MS            := 100
MV_CONTA_SUBMIT_TIMEOUT_MS    := 650

; ── Polling / estabilidade ────────────────────────────────────
MV_POLL_MS            := 100
; MV_TIMEOUT_LOAD (15s) aguarda o carregamento sem a espera excessiva de 100s
; MV_TIMEOUT_ACOE (10s) aguarda apenas o fechamento do modal já renderizado.
MV_TIMEOUT_LOAD       := 15
MV_TIMEOUT_ACOE       := 10
MV_DELAY_INPUT        := 100
MV_MODULE_STABLE_MS   := 600
MV_TARGET_STABLE_MS   := 600
