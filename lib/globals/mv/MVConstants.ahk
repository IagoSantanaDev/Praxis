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

; ── Caixa de mensagem genérica do MV ("Mensagem ao Usuário do MV 2000") ──
; Título usado pelo MV para popups de aviso/confirmação em vários módulos
; (Sim/Não de fechamento no FFCV, popup de bloqueio no Protocolar/MOV DOC).
; Fonte única — existia como WIN_FFCV_DATAS_OK (morta) e WIN_XML_POPUP_SIMNAO
; em FfcvScreen.ahk, além de um literal hardcoded em Protocolar.ahk.
MV_WIN_MENSAGEM_USUARIO := "Mensagem ao Usuário do MV 2000"

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

MV_TipoContaCodigo(tipoConta) {
    normalized := StrLower(Trim(String(tipoConta)))
    canonicalName := normalized = "internamento" ? "Internamento"
        : normalized = "emergencia" || normalized = "emergência" ? "Emergência"
        : normalized = "ambulatorio" || normalized = "ambulatório" ? "Ambulatório"
        : ""

    if (canonicalName = "" || !MV_TIPO_CONTA.Has(canonicalName))
        throw Error("Tipo de conta invalido: " tipoConta ". Use Internamento, Emergencia ou Ambulatorio.")
    return String(MV_TIPO_CONTA[canonicalName])
}

; MV_KEY_SETTLE_MS: micro-settle padrão (100ms) após uma tecla/clique antes de
; checar o efeito. Fonte única — absorve MV_CONTA_FIELD_EMPTY_MIN_MS e
; MV_CONTA_STABLE_MS (FfcvContaPopup/Popups), que eram o mesmo valor com
; nomes de domínio só para o popup de conta, sem significado distinto do
; conceito genérico de settle.
MV_KEY_SETTLE_MS         := 100

; ── Timings do popup de conta ───────────────────────────────────
; Familia unica das antigas FFCV_CONTA_*/FFCVP_CONTA_*/POPUP_STABLE_MS.
MV_CONTA_READY_MIN_MS         := 180
MV_CONTA_SUBMIT_TIMEOUT_MS    := 650

; ── Polling / estabilidade ────────────────────────────────────
MV_POLL_MS            := 100
MV_DEFAULT_TIMEOUT_MS := 30000
MV_ACTION_TIMEOUT_MS := 3000
MV_TRANSITION_TIMEOUT_MS := 5000
FFCV_XML_QUERY_MIN_WAIT_MS := 1200
MV_REPORT_WINDOW_TIMEOUT_SECS := 60
MV_SAVE_DIALOG_TIMEOUT_SECS := 45
MV_INFO_DIALOG_TIMEOUT_SECS := 30
MV_FILE_APPEAR_TIMEOUT_SECS := 30
MV_DEFAULT_TIMEOUT_SECS := 20
MV_WINDOW_ACTIVATE_TIMEOUT_SECS := 3
MV_MOVDOC_FOCUS_TIMEOUT_SECS := 2
MV_DIALOG_BUTTON_TIMEOUT_SECS := 5
MV_CLIPBOARD_TIMEOUT_MS := 600
MV_CLIPBOARD_NATIVE_TIMEOUT_SECS := 1
MV_CONTA_MODAL_WAIT_MS := 1200
MV_CONTA_READY_SETTLE_MS := 300
MV_MOVDOC_GRID_TIMEOUT_MS := 12000
MV_GRID_FAST_READ_TIMEOUT_MS := 150
MV_GRID_FALLBACK_READ_TIMEOUT_MS := 300
MV_SCREEN_RESET_TIMEOUT_MS := 1000
MV_USER_POPUP_TIMEOUT_MS := 400
MV_ORACLE_STABLE_MS   := 800
FFCV_FINAL_STABLE_MS         := 800
FFCV_FINAL_ACTION_TIMEOUT_MS := 30000
; MV_TIMEOUT_LOAD (15s) aguarda o carregamento sem a espera excessiva de 100s
; MV_TIMEOUT_ACOE (10s) aguarda apenas o fechamento do modal já renderizado.
MV_TIMEOUT_LOAD       := 15
MV_TIMEOUT_ACOE       := 10
; MV_TARGET_STABLE_MS: janela padrão (600ms) de "tela parada" usada por
; MV_WaitScreenStable/MV_WaitWindowStable/MV_WaitScreenChangedAndStable —
; tanto como default de parâmetro quanto como valor explícito nos call sites
; que abrem um módulo (MOV DOC/FFCV) e esperam a tela estabilizar. Fonte
; única — absorve MV_DEFAULT_STABLE_MS e MV_MODULE_STABLE_MS, que eram o
; mesmo valor sem finalidade distinta (o primeiro só existia como default de
; parâmetro; o segundo era o mesmo conceito aplicado à abertura de módulo).
MV_TARGET_STABLE_MS   := 600

; ── Coincidências numéricas mantidas separadas de propósito ───
; FFCV_XML_QUERY_MIN_WAIT_MS (1200) e MV_CONTA_MODAL_WAIT_MS (1200);
; MV_CONTA_READY_SETTLE_MS (300) e MV_GRID_FALLBACK_READ_TIMEOUT_MS (300);
; MV_ORACLE_STABLE_MS (800) e FFCV_FINAL_STABLE_MS (800);
; MV_INFO_DIALOG_TIMEOUT_SECS (30) e MV_FILE_APPEAR_TIMEOUT_SECS (30);
; MV_DEFAULT_TIMEOUT_MS (30000) e FFCV_FINAL_ACTION_TIMEOUT_MS (30000).
; Cada par tem hoje o mesmo valor por coincidência, não pela mesma
; finalidade: são orçamentos de tempo de fases/domínios diferentes (ex.:
; espera mínima de query XML vs. espera de modal de conta; settle de grid do
; MOV DOC vs. settle do popup de conta; timeout de dialog de UI vs. timeout
; de aparecimento de arquivo em disco). Mantidos como constantes distintas
; para permitir ajuste independente futuro sem acoplar fases não relacionadas.
