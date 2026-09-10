; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug
#Include %A_LineFile%\..\..\MVSession.ahk
#Include %A_LineFile%\..\..\components\Dialogs.ahk

; ════════════════════════════════════════════════════════════════
;  MOV DOC SCREEN — PROTOCOLAÇÃO / BAIXA DE DOCUMENTOS
; ════════════════════════════════════════════════════════════════
;
; Encapsula toda lógica de automação da tela "Protocolação de Baixa
; de Documentos" do sistema MV 2000i.
;
; Responsabilidades:
;   - Abrir a tela Baixa de Documentos via atalho validado (Alt+mpb).
;   - Preencher e consultar um protocolo via clique + SendText.
;   - Coletar linhas visíveis da grid Oracle Forms (Home/Shift+End/Ctrl+C).
;   - Percorrer a grid em blocos de 4 linhas via clique + Down.
;   - Marcar checkbox "Recebido" (clique simples ou duplo conforme estado).
;   - Finalizar a baixa com F10 + F7.
;
; Notas de automação:
;   - Oracle Forms renumera Edit1/Edit2/Edit15 conforme estado da tela.
;     Não usar EditN como contrato — usar coordenadas client validadas.
;   - A grid MOV DOC não expõe texto confiável via ControlGetText.
;     Usar clique físico, Home, Shift+End e Ctrl+C com validação semântica.
;   - Modais Oracle Forms não expõem mensagem pelo Window Spy/WinGetText.
;     A classificação confiável vem do OCR local ou do fluxo de popup.
; ════════════════════════════════════════════════════════════════

; ── Janelas ───────────────────────────────────────────────────
; WIN_MOVDOC_BAIXA já existe em MVConstants.ahk como MV_WIN_MOVDOC_BAIXA.
; Usar MV_WIN_MOVDOC_BAIXA diretamente nos callers.
; Título do popup MOV DOC derivado de MV_CLASS_MODAL_FORMS (Dialogs.ahk já define
; DIALOG_MOVDOC_POPUP; manter alias local sem novo literal).
WIN_MOVDOC_POPUP := DIALOG_MOVDOC_POPUP

; ── Regiões em coordenadas Client ──────────────────────────────
; Não usar EditN como contrato: Oracle Forms renumera conforme estado.
; A grid não expõe texto confiável via ControlGetText — usar clique + Ctrl+C.
MOVDOC_PROTOCOLO_X := 21
MOVDOC_PROTOCOLO_Y := 106
MOVDOC_CONTA_X     := 252
MOVDOC_CONVENIO_X  := 491
MOVDOC_GRID_ROWS_Y := [222, 245, 268, 291]

; Checkbox Recebido: Button1 no MOV DOC Baixa.
; Regra validada: 0 ou "" → clique simples; 1 → duplo clique.
MOVDOC_CHECK_RECEBIDO_CLASS := "Button1"
MOVDOC_CHECK_RECEBIDO_X     := 718
MOVDOC_CHECK_RECEBIDO_Y     := 359

; ── Esperas e timings ──────────────────────────────────────────
; Timings canonicos em MVConstants (MV_FIELD_*); aliases compat.
MOVDOC_FIELD_FOCUS_SETTLE_MS := MV_FIELD_FOCUS_SETTLE_MS
MOVDOC_FIELD_CLEAR_SETTLE_MS := MV_FIELD_CLEAR_SETTLE_MS
MOVDOC_KEY_SETTLE_MS         := MV_KEY_SETTLE_MS

; ════════════════════════════════════════════════════════════════
;  Funções públicas
; ════════════════════════════════════════════════════════════════

MovDoc_AbrirTelaBaixa() {
    MV_ActivateModule(MV_WIN_MOVDOC_ANY)
    if !MV_WaitScreenStable(MV_WIN_MOVDOC_ANY, MV_MODULE_STABLE_MS, MV_TIMEOUT_LOAD * 1000)
        return false

    ; Atalho validado no macro 02: Manutenção → Protocolação → Baixa.
    if !MV_SendAndWait(MV_WIN_MOVDOC_ANY, "{Alt down}mpb{Alt up}", MV_TIMEOUT_LOAD * 1000,
        , "abertura da tela Baixa")
        return false
    return !!MV_WaitScreenStable(MV_WIN_MOVDOC_BAIXA, MV_TARGET_STABLE_MS, MV_TIMEOUT_LOAD * 1000)
}

MovDoc_SetProtocoloByClick(protocolo) {
    if !MV_EnsureWindowActive(MV_WIN_MOVDOC_BAIXA, 2)
        return false

    return !!MV_SetTextAndWait(MV_WIN_MOVDOC_BAIXA,
        MOVDOC_PROTOCOLO_X + 40, MOVDOC_PROTOCOLO_Y + 10, protocolo,
        MOVDOC_KEY_SETTLE_MS * 20,
        (hwnd, state) => InStr(MV_GetFocusedControlText(MV_WIN_MOVDOC_BAIXA), String(protocolo)) > 0,
        "protocolo preenchido")
}

MovDoc_LerGrid(protocolo, primeiraLinha?) {
    linhas := []
    vistos := Map()

    if (IsSet(primeiraLinha) && primeiraLinha is Map) {
        keyInicial := primeiraLinha["protocolo"] "|" primeiraLinha["conta"] "|" primeiraLinha["convenio"]
        vistos[keyInicial] := true
        linhas.Push(primeiraLinha)
    }

    _ColetarVisiveis(protocolo, linhas, vistos)

    maxIteracoes := 100
    semNovasConsecutivas := 0

    Loop maxIteracoes {
        ThrowIfAppStopped()
        result := _AvancarBloco()
        added := _ColetarVisiveis(protocolo, linhas, vistos)

        ; Popup de último registro é o sinal mais confiável: parar imediatamente.
        if result["popup"]
            break

        ; Oracle Forms pode atrasar atualização da grid; exigir dois blocos
        ; vazios seguidos evita parar cedo por leitura repetida/transitória.
        if (added = 0) {
            semNovasConsecutivas++
            if (semNovasConsecutivas >= 2)
                break
        } else {
            semNovasConsecutivas := 0
        }
    }

    return linhas
}

MovDoc_FinalizarBaixa() {
    checked := MV_ControlCheckedAt(
        MV_WIN_MOVDOC_BAIXA,
        MOVDOC_CHECK_RECEBIDO_CLASS,
        MOVDOC_CHECK_RECEBIDO_X,
        MOVDOC_CHECK_RECEBIDO_Y
    )

    if (checked = 0 || checked = "") {
        if !MV_ClickAndWait(MV_WIN_MOVDOC_BAIXA, MOVDOC_CHECK_RECEBIDO_CLASS,
            MOVDOC_CHECK_RECEBIDO_X, MOVDOC_CHECK_RECEBIDO_Y, 5000,
            (hwnd, state) => MV_ControlCheckedAt(MV_WIN_MOVDOC_BAIXA,
                MOVDOC_CHECK_RECEBIDO_CLASS, MOVDOC_CHECK_RECEBIDO_X,
                MOVDOC_CHECK_RECEBIDO_Y) = 1, "checkbox Recebido marcado")
            return false
    } else if (checked = 1) {
        beforeCheck := MV_CaptureScreenState(MV_WIN_MOVDOC_BAIXA)
        if !MV_DoubleClickControlAt(
            MV_WIN_MOVDOC_BAIXA,
            MOVDOC_CHECK_RECEBIDO_CLASS,
            MOVDOC_CHECK_RECEBIDO_X,
            MOVDOC_CHECK_RECEBIDO_Y
        )
            return false
        if !MV_WaitScreenChanged(beforeCheck, 5000, MV_WIN_MOVDOC_BAIXA)
            return false
        if !MV_WaitScreenStable(MV_WIN_MOVDOC_BAIXA, MV_TARGET_STABLE_MS, 5000)
            return false
    } else {
        return false
    }

    ; Fluxo validado: checkbox → F10 → clicar campo Protocolo → F7.
    if !MV_SendFunctionAndWait(MV_WIN_MOVDOC_BAIXA, "F10", 5000, , "baixa confirmada")
        return false

    if !_FocusProtocolo()
        return false

    return !!MV_SendFunctionAndWait(MV_WIN_MOVDOC_BAIXA, "F7", 5000, , "retorno ao próximo protocolo")
}

MovDoc_WaitFirstGridLineReady(protocolo, &primeiraLinhaValida) {
    global
    startedAt := A_TickCount
    deadline := startedAt + 12000

    Loop {
        ThrowIfAppStopped()
        conta := _LerCampoGrid(MOVDOC_CONTA_X, MOVDOC_GRID_ROWS_Y[1], "conta", 150, 300)
        convenio := _LerCampoGrid(MOVDOC_CONVENIO_X, MOVDOC_GRID_ROWS_Y[1], "convenio", 150, 300)

        if (conta != "" && convenio != "" && conta != protocolo && convenio != protocolo) {
            Notify("MOV DOC: primeira linha legível após F8 em " (A_TickCount - startedAt) "ms.")
            primeiraLinhaValida := Map("protocolo", protocolo, "conta", conta, "convenio", convenio)
            return true
        }

        if (A_TickCount >= deadline)
            return false

        Sleep MV_POLL_MS
    }
}

MovDoc_GridValueValid(valor, campo := "") {
    valor := Trim(valor)
    if (valor = "")
        return false
    if !RegExMatch(valor, "^\d+$")
        return false
    if (campo = "convenio" && StrLen(valor) >= 4)
        return false
    if (campo = "conta" && StrLen(valor) < 5)
        return false
    return true
}

; ════════════════════════════════════════════════════════════════
;  Funções internas (privadas do módulo)
; ════════════════════════════════════════════════════════════════

_AvancarBloco() {
    ultimoY := MOVDOC_GRID_ROWS_Y[MOVDOC_GRID_ROWS_Y.Length]
    if !MV_ClickAtAndWait(MV_WIN_MOVDOC_BAIXA, MOVDOC_CONTA_X + 15, ultimoY + 8, 5000,
        , "última linha da grade selecionada")
        return Map("popup", false, "erro", "grade nao confirmou selecao da ultima linha")

    Loop MOVDOC_GRID_ROWS_Y.Length {
        ThrowIfAppStopped()
        if Dialog_MovDocPopupVisible() {
            Dialog_DismissMovDocPopup()
            return Map("popup", true)
        }

        if !MV_SendAndWait(MV_WIN_MOVDOC_BAIXA, "{Down}", 5000,
            , "avanço de linha da grade")
            return Map("popup", false, "erro", "grade nao confirmou avanço de linha")
    }

    if Dialog_MovDocPopupVisible() {
        Dialog_DismissMovDocPopup()
        return Map("popup", true)
    }

    primeiroY := MOVDOC_GRID_ROWS_Y[1]
    if !MV_ClickAtAndWait(MV_WIN_MOVDOC_BAIXA, MOVDOC_CONTA_X + 15, primeiroY + 8, 5000,
        , "primeira linha da grade selecionada")
        return Map("popup", false, "erro", "grade nao confirmou selecao da primeira linha")
    return Map("popup", false)
}

_ColetarVisiveis(protocolo, linhas, vistos) {
    added := 0

    for _, rowY in MOVDOC_GRID_ROWS_Y {
        conta := _LerCampoGrid(MOVDOC_CONTA_X, rowY, "conta")
        convenio := _LerCampoGrid(MOVDOC_CONVENIO_X, rowY, "convenio")

        if (conta = protocolo || convenio = protocolo || conta = "" || convenio = "")
            continue

        if (conta = convenio)
            conta := _LerCampoGrid(MOVDOC_CONTA_X, rowY, "conta")

        if (conta = "" || convenio = "")
            continue

        key := protocolo "|" conta "|" convenio
        if vistos.Has(key)
            continue

        vistos[key] := true
        linhas.Push(Map("protocolo", protocolo, "conta", conta, "convenio", convenio))
        added++
    }

    return added
}

_FocusProtocolo() {
    if !MV_EnsureWindowActive(MV_WIN_MOVDOC_BAIXA, 2)
        return false

    return !!MV_ClickAtAndWait(MV_WIN_MOVDOC_BAIXA,
        MOVDOC_PROTOCOLO_X + 40, MOVDOC_PROTOCOLO_Y + 10, 5000,
        , "campo Protocolo focado")
}

_LerCampoGrid(x, y, campo := "", fastTimeoutMs := 150, fallbackTimeoutMs := 300) {
    if !MV_EnsureWindowActive(MV_WIN_MOVDOC_BAIXA, 2)
        return ""

    if !MV_ClickAtAndWait(MV_WIN_MOVDOC_BAIXA, x + 15, y + 8, fastTimeoutMs,
        , "célula da grade focada")
        return ""
    if !MV_SendAndWait(MV_WIN_MOVDOC_BAIXA, "{Home}{Shift down}{End}{Shift up}", fastTimeoutMs,
        , "texto da célula selecionado")
        return ""

    valor := MV_CopyFocusedText(fastTimeoutMs)
    if MovDoc_GridValueValid(valor, campo)
        return valor

    valor := MV_CopyFocusedText(fallbackTimeoutMs)
    if MovDoc_GridValueValid(valor, campo)
        return valor

    return ""
}
