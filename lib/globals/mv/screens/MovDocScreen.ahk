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
    if !MV_WaitWindowStable(MV_WIN_MOVDOC_ANY, MV_MODULE_STABLE_MS, MV_TIMEOUT_LOAD)
        return false

    ; Atalho validado no macro 02: Manutenção → Protocolação → Baixa.
    Send "{Alt down}mpb{Alt up}"

    if !MV_Poll(() => WinExist(MV_WIN_MOVDOC_BAIXA), MV_TIMEOUT_LOAD)
        return false

    return MV_WaitWindowStable(MV_WIN_MOVDOC_BAIXA, MV_TARGET_STABLE_MS, MV_TIMEOUT_LOAD)
}

MovDoc_SetProtocoloByClick(protocolo) {
    if !MV_EnsureWindowActive(MV_WIN_MOVDOC_BAIXA, 2)
        return false

    Click(MOVDOC_PROTOCOLO_X + 40, MOVDOC_PROTOCOLO_Y + 10, 1)
    Sleep MOVDOC_KEY_SETTLE_MS
    SendText protocolo
    Sleep MOVDOC_KEY_SETTLE_MS
    return true
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
        if !MV_ClickControlAt(
            MV_WIN_MOVDOC_BAIXA,
            MOVDOC_CHECK_RECEBIDO_CLASS,
            MOVDOC_CHECK_RECEBIDO_X,
            MOVDOC_CHECK_RECEBIDO_Y
        )
            return false
    } else if (checked = 1) {
        if !MV_DoubleClickControlAt(
            MV_WIN_MOVDOC_BAIXA,
            MOVDOC_CHECK_RECEBIDO_CLASS,
            MOVDOC_CHECK_RECEBIDO_X,
            MOVDOC_CHECK_RECEBIDO_Y
        )
            return false
    } else {
        return false
    }

    Sleep MOVDOC_KEY_SETTLE_MS

    ; Fluxo validado: checkbox → F10 → clicar campo Protocolo → F7.
    Send "{F10}"
    Sleep MOVDOC_KEY_SETTLE_MS

    if !_FocusProtocolo()
        return false

    Sleep MOVDOC_KEY_SETTLE_MS
    Send "{F7}"
    Sleep MOVDOC_KEY_SETTLE_MS
    return true
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

        Sleep 100
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
    Click(MOVDOC_CONTA_X + 15, ultimoY + 8, 1)
    Sleep MOVDOC_KEY_SETTLE_MS

    Loop MOVDOC_GRID_ROWS_Y.Length {
        ThrowIfAppStopped()
        if Dialog_MovDocPopupVisible() {
            Dialog_DismissMovDocPopup()
            return Map("popup", true)
        }

        Send "{Down}"
        Sleep MOVDOC_KEY_SETTLE_MS
    }

    if Dialog_MovDocPopupVisible() {
        Dialog_DismissMovDocPopup()
        return Map("popup", true)
    }

    primeiroY := MOVDOC_GRID_ROWS_Y[1]
    Click(MOVDOC_CONTA_X + 15, primeiroY + 8, 1)
    Sleep MOVDOC_KEY_SETTLE_MS
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

    Click(MOVDOC_PROTOCOLO_X + 40, MOVDOC_PROTOCOLO_Y + 10, 1)
    return true
}

_LerCampoGrid(x, y, campo := "", fastTimeoutMs := 150, fallbackTimeoutMs := 300) {
    if !MV_EnsureWindowActive(MV_WIN_MOVDOC_BAIXA, 2)
        return ""

    Click(x + 15, y + 8, 1)
    Sleep MOVDOC_KEY_SETTLE_MS
    Send("{Home}{Shift down}{End}{Shift up}")

    valor := MV_CopyFocusedText(fastTimeoutMs)
    if MovDoc_GridValueValid(valor, campo)
        return valor

    valor := MV_CopyFocusedText(fallbackTimeoutMs)
    if MovDoc_GridValueValid(valor, campo)
        return valor

    return ""
}
