; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug
#Include %A_LineFile%\..\..\MVSession.ahk
#Include %A_LineFile%\..\..\FFCV_ErrorTemplates.ahk
#Include %A_LineFile%\..\..\components\Popups.ahk
#Include %A_LineFile%\..\..\components\Dialogs.ahk

; ════════════════════════════════════════════════════════════════
;  FFCV CONTA POPUP — "INFORMAÇÕES DA CONTA" DENTRO DO FFCV
; ════════════════════════════════════════════════════════════════
;
; Encapsula toda lógica do popup "Informações da Conta" embarcado
; na janela Faturamento / Manutenção de Remessa do sistema MV 2000i.
;
; Responsabilidades:
;   - Abrir o popup via clique em "Inserir Conta" (Button10).
;   - Aguardar estabilidade do popup com sentinela ui60Drawn W323.
;   - Configurar os dropdowns (ComboBox) conforme tipo de conta.
;   - Enviar número da conta e aguardar resultado (modal ou campo limpo).
;   - Classificar erros de inserção via OCR/Dialogs.
;   - Fechar o popup após o lote de contas.
;
; Notas de automação:
;   - O popup não abre WinTitle próprio; detectar pelo painel
;     ui60Drawn W323 dentro da janela principal FFCV.
;   - Modais Oracle Forms não expõem mensagem pelo Window Spy/WinGetText.
;     A classificação confiável vem do OCR local ou do fluxo de popup.
; ════════════════════════════════════════════════════════════════

; ── Controles popup "Informações da Conta" ──────────────────────
; Validados por captura do usuário (macro 11).
; Constantes canonicas em MVConstants.ahk (MV_POPUP_*); aliases aqui
; preservam os callers sem duplicar valores.
FFCVP_BTN_ADICIONAR     := MV_BTN_ADICIONAR_CONTA  ; 1 - Inserir Conta
FFCVP_BTN_ADICIONAR_X   := 24
FFCVP_BTN_ADICIONAR_Y   := 458
FFCVP_CAMPO_CONTA       := MV_POPUP_CAMPO_CONTA
FFCVP_CAMPO_CONTA_X     := MV_POPUP_CAMPO_CONTA_X
FFCVP_CAMPO_CONTA_Y     := MV_POPUP_CAMPO_CONTA_Y
FFCVP_DROPDOWN_1        := MV_POPUP_DROPDOWN_TIPO
FFCVP_DROPDOWN_1_X      := MV_POPUP_DROPDOWN_TIPO_X
FFCVP_DROPDOWN_1_Y      := MV_POPUP_DROPDOWN_TIPO_Y
FFCVP_DROPDOWN_2        := MV_POPUP_DROPDOWN_SUB_TIPO
FFCVP_DROPDOWN_2_X      := MV_POPUP_DROPDOWN_SUB_TIPO_X
FFCVP_DROPDOWN_2_Y      := MV_POPUP_DROPDOWN_SUB_TIPO_Y
FFCVP_BTN_OK            := MV_POPUP_BTN_OK   ; modal de aviso/erro

; ── Esperas / timings (canonicos em MVConstants: MV_FIELD_*/MV_CONTA_*) ───
FFCVP_FIELD_FOCUS_SETTLE_MS := MV_FIELD_FOCUS_SETTLE_MS
FFCVP_FIELD_CLEAR_SETTLE_MS := MV_FIELD_CLEAR_SETTLE_MS
FFCVP_KEY_SETTLE_MS         := MV_KEY_SETTLE_MS
FFCVP_CONTA_READY_MIN_MS    := MV_CONTA_READY_MIN_MS
FFCVP_CONTA_FIELD_EMPTY_MIN_MS := MV_CONTA_FIELD_EMPTY_MIN_MS
FFCVP_CONTA_STABLE_MS       := MV_CONTA_STABLE_MS
FFCVP_CONTA_SUBMIT_TIMEOUT_MS := MV_CONTA_SUBMIT_TIMEOUT_MS

; ── Helper de logging interno ─────────────────────────────────
; Usa MV_Log de components/Controls.ahk (consolidado em 2026-06-26).

; ════════════════════════════════════════════════════════════════
;  API PÚBLICA
; ════════════════════════════════════════════════════════════════

FfcvContaPopup_AbrirEConfigurar(tipoConta) {
    ; Garantir que o FFCV está ativo antes de clicar.
    if !MV_EnsureFFCV() {
        MV_Log("FfcvContaPopup_AbrirEConfigurar", "FFCV nao ficou ativo", false)
        return false
    }

    ; Clicar em "1 - Inserir Conta".
    if !MV_ClickControlAt(MV_WIN_FFCV_ANY, FFCVP_BTN_ADICIONAR, FFCVP_BTN_ADICIONAR_X, FFCVP_BTN_ADICIONAR_Y) {
        MV_Log("FfcvContaPopup_AbrirEConfigurar", "nao consegui clicar em Inserir Conta", false)
        return false
    }

    ; Aguardar popup ficar pronto.
    ready := FfcvContaPopup_WaitReady(5000)
    if !ready["ok"] {
        MV_Log("FfcvContaPopup_AbrirEConfigurar", ready["erro"], false)
        return false
    }

    ; Se modal Forms aparecer antes do popup (tela travada), tratar.
    if Dialog_ActiveModalTitle() != "" && !Popup_ContaVisible() {
        if !MV_Poll(() => Dialog_ActiveModalTitle() = "" || Popup_ContaVisible(), 1200) {
            MV_Log("FfcvContaPopup_AbrirEConfigurar",
                "modal Forms antes do popup e nao resolvido", false)
            return false
        }
    }

    ; Garantir FFCV ativo para sequência de Tab/Down.
    if !MV_EnsureFFCV() {
        MV_Log("FfcvContaPopup_AbrirEConfigurar", "FFCV nao ativo para atalhos do popup", false)
        return false
    }

    ; Aguardar estabilidade mínima antes de configurar dropdowns.
    stable := FfcvContaPopup_WaitStable(300)
    if !stable["ok"] {
        MV_Log("FfcvContaPopup_AbrirEConfigurar", stable["erro"], false)
        return false
    }

    ; Configurar dropdowns pelo tipo de conta (sequência de Tab/Down validada no macro 11).
    if !FfcvContaPopup_ConfigurarDropdowns(tipoConta) {
        MV_Log("FfcvContaPopup_AbrirEConfigurar",
            "FfcvContaPopup_ConfigurarDropdowns falhou para tipo=" tipoConta, false)
        return false
    }

    MV_Log("FfcvContaPopup_AbrirEConfigurar",
        "popup configurado tipo=" tipoConta, true)
    return true
}

FfcvContaPopup_ConfigurarDropdowns(tipoConta) {
    if !MV_EnsureFFCV()
        return false

    if (tipoConta = "Internamento") {
        Send "{Tab 3}"
        Sleep FFCVP_KEY_SETTLE_MS
        Send "{Down 2}"
        Sleep FFCVP_KEY_SETTLE_MS
        Send "{Tab}"
        Sleep FFCVP_KEY_SETTLE_MS
        Send "{Tab 2}"
        Sleep FFCVP_KEY_SETTLE_MS
    } else if (tipoConta = "Emergência" || tipoConta = "Ambulatório") {
        Send "{Tab 3}"
        Sleep FFCVP_KEY_SETTLE_MS
        Send "{Down 2}"
        Sleep FFCVP_KEY_SETTLE_MS
        Send "{Tab 2}"
        Sleep FFCVP_KEY_SETTLE_MS
        Send "{Up 2}"
        Sleep FFCVP_KEY_SETTLE_MS
        Send "{Tab}"
        Sleep FFCVP_KEY_SETTLE_MS
    } else {
        MV_Log("FfcvContaPopup_ConfigurarDropdowns",
            "tipo desconhecido=" tipoConta, false)
        return false
    }

    return true
}

FfcvContaPopup_EnviarConta(numConta) {
    result := FfcvContaPopup_LimparCampoEEnviar(numConta)
    if !result["ok"]
        return Map("status", "blocker", "erro", result["erro"], "texto", "", "report", result["report"])

    outcome := FfcvContaPopup_WaitSubmitOutcome(FFCVP_CONTA_SUBMIT_TIMEOUT_MS, numConta)
    return outcome
}

FfcvContaPopup_LimparCampoEEnviar(numConta) {
    if !Popup_ContaVisible()
        return Map("ok", false, "erro", "Popup de conta nao esta visivel.", "report",
            " Popup de conta nao esta visivel antes de limpar/enviar a conta " numConta ".\n")

    if !MV_EnsureFFCV()
        return Map("ok", false, "erro", "FFCV nao ficou ativa.", "report",
            " FFCV nao ficou ativa antes de limpar/enviar a conta " numConta ".\n")

    Click(FFCVP_CAMPO_CONTA_X + 15, FFCVP_CAMPO_CONTA_Y + 8, 1)
    Sleep FFCVP_FIELD_FOCUS_SETTLE_MS
    Send("{Home}{Shift down}{End}{Shift up}{Backspace}")
    Sleep FFCVP_FIELD_CLEAR_SETTLE_MS
    SendText numConta
    Send "{Enter}"

    return Map("ok", true, "erro", "", "report",
        " Campo da conta clicado, limpo, conta digitada e Enter enviado: " numConta "\n")
}

/*
FfcvContaPopup_WaitSubmitOutcome(timeoutMs, submittedConta)
    Aguarda o resultado do envio de uma conta (Enter).
    Possíveis estados:
      - "modal": modal Forms de erro detectado; classificação disponível em outcome["erro"].
      - "ready": popup estável e campo limpo; liberado para próxima conta.
      - "timeout": tempo esgotado sem resolução clara.
    @param timeoutMs      Timeout em milissegundos.
    @param submittedConta  Número da conta enviada (para detecção de campo limpo).
    @return Map("status", string, "erro", Map|string, "texto", string, "report", string).
*/
FfcvContaPopup_WaitSubmitOutcome(timeoutMs, submittedConta := "") {
    startTick := A_TickCount
    deadline := startTick + timeoutMs
    stableSince := 0
    emptySince := 0

    Loop {
        ; Verificar modal Forms (erro de inserção).
        popup := Dialog_ActiveModalTitle()
        if (popup != "") {
            erro := Dialog_ClassifyErroContaModal()
            return Map("status", "modal", "erro", erro, "texto", "", "report",
                " Modal Forms detectado apos Enter: " erro.Get("descricao", "?") " [" erro.Get("fonte", "?") "]\n")
        }

        ; Verificar se o campo da conta foi esvaziado (inserção bem-sucedida).
        fieldText := FfcvContaPopup_GetCampoContaText()
        if (submittedConta != "" && fieldText != submittedConta && fieldText = "") {
            if (emptySince = 0)
                emptySince := A_TickCount
            if (A_TickCount - emptySince >= FFCVP_CONTA_FIELD_EMPTY_MIN_MS)
                return Map("status", "ready", "erro", "", "texto", "", "report",
                    " Campo esvaziou apos " Round((A_TickCount - startTick) / 1000, 2) "s; liberado para proxima conta.\n")
        } else {
            emptySince := 0
        }

        ; Verificar estabilidade do popup (nenhuma ação visível = pronto para próxima).
        if Popup_ContaVisible() {
            if (stableSince = 0)
                stableSince := A_TickCount
            if (A_TickCount - startTick >= FFCVP_CONTA_READY_MIN_MS
                && A_TickCount - stableSince >= FFCVP_CONTA_STABLE_MS)
                return Map("status", "ready", "erro", "", "texto", "", "report",
                    " Nenhum modal apos " Round((A_TickCount - startTick) / 1000, 2) "s; popup estavel para proxima conta.\n")
        } else {
            stableSince := 0
        }

        if (A_TickCount > deadline) {
            if (stableSince != 0 && A_TickCount - stableSince >= FFCVP_CONTA_STABLE_MS)
                return Map("status", "ready", "erro", "", "texto", "", "report",
                    " Nenhum modal apos " Round((A_TickCount - startTick) / 1000, 2) "s; popup estavel para proxima conta.\n")
            return Map("status", "timeout", "erro", "Timeout aguardando modal ou popup estavel apos Enter.", "texto", "", "report",
                " Timeout aguardando modal ou popup estavel apos Enter.\n")
        }

        Sleep 15
    }
}

FfcvContaPopup_GetCampoContaText() {
    hwnd := Popup_FindControlByClassPrefixAtPoint(
        MV_WIN_FFCV_ANY, "Edit",
        FFCVP_CAMPO_CONTA_X, FFCVP_CAMPO_CONTA_Y, 35)
    if !hwnd
        return ""
    try return Trim(ControlGetText(hwnd))
    catch
        return ""
}

FfcvContaPopup_WaitReady(timeoutMs) {
    startedAt := A_TickCount

    ; Aguardar sentinela visível + primeiro controle de conta.
    ready := MV_Poll(() => Popup_ContaVisible(), timeoutMs / 1000)
    if !ready
        return Map("ok", false, "erro", "Popup de conta nao ficou visivel apos clique em Inserir Conta.", "elapsed", A_TickCount - startedAt)

    ; Micro-settle: aguardar estabilidade mínima do popup.
    Sleep FFCVP_CONTA_STABLE_MS
    return Map("ok", true, "erro", "", "elapsed", A_TickCount - startedAt)
}

FfcvContaPopup_WaitStable(timeoutMs) {
    startedAt := A_TickCount
    deadline := startedAt + timeoutMs
    stableSince := 0

    Loop {
        if Popup_ContaVisible() {
            if (stableSince = 0)
                stableSince := A_TickCount
            if (A_TickCount - stableSince >= FFCVP_CONTA_STABLE_MS)
                return Map("ok", true, "erro", "")
        } else {
            stableSince := 0
        }

        if (A_TickCount >= deadline)
            return Map("ok", false, "erro", "Popup de conta nao estabilizou em " timeoutMs "ms apos abrir.")

        Sleep 20
    }
}

FfcvContaPopup_Close(timeoutMs := 5000) {
    Send "{Alt down}2{Alt up}"
    Sleep FFCVP_KEY_SETTLE_MS

    startedAt := A_TickCount
    deadline := startedAt + timeoutMs

    Loop {
        if !Popup_ContaVisible() {
            Sleep FFCVP_CONTA_STABLE_MS
            if !Popup_ContaVisible() {
                MV_Log("FfcvContaPopup_Close",
                    "popup fechado em " (A_TickCount - startedAt) "ms", true)
                return true
            }
        }

        if (A_TickCount >= deadline) {
            MV_Log("FfcvContaPopup_Close",
                "timeout apos " timeoutMs "ms", false)
            return false
        }

        Sleep 50
    }
}
