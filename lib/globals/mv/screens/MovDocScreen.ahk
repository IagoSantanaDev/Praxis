; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug
#Include ..\..\..\..\lib\globals\mv\MVSession.ahk
#Include ..\components\Dialogs.ahk

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
; Manter ref local para uso interno e compatibilidade.
WIN_MOVDOC_POPUP := "Forms ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"

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
; Padrão validado no macro 11: micro-settle suficiente para
; estabilidade sem sleeps longos em campos Oracle Forms.
MOVDOC_FIELD_FOCUS_SETTLE_MS := 100
MOVDOC_FIELD_CLEAR_SETTLE_MS := 100
MOVDOC_KEY_SETTLE_MS         := 100

; ════════════════════════════════════════════════════════════════
;  Funções públicas
; ════════════════════════════════════════════════════════════════

/*
MovDoc_AbrirTelaBaixa()
    Abre a tela Baixa de Documentos via atalho Alt+mpb.
    Sempre abre uma nova instância; não reutiliza Baixa já aberta.
    Retorna true se a janela ficou estável, false em timeout.
*/
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

/*
MovDoc_SetProtocoloByClick(protocolo)
    Ativa a janela Baixa de Documentos, clica no campo Protocolo
    (coordenadas client) e envia o texto do protocolo.
    Retorna true se o clique e envio foram aceitos, false em falha.
*/
MovDoc_SetProtocoloByClick(protocolo) {
    if !WinExist(MV_WIN_MOVDOC_BAIXA)
        return false

    WinActivate MV_WIN_MOVDOC_BAIXA
    if !MV_Poll(() => WinActive(MV_WIN_MOVDOC_BAIXA), 2)
        return false

    Click(MOVDOC_PROTOCOLO_X + 40, MOVDOC_PROTOCOLO_Y + 10, 1)
    Sleep MOVDOC_KEY_SETTLE_MS
    SendText protocolo
    Sleep MOVDOC_KEY_SETTLE_MS
    return true
}

/*
MovDoc_LerGrid(protocolo, primeiraLinha?)
    Percorre a grid do MOV DOC a partir da primeira linha já lida.
    Coleta blocos de 4 linhas visíveis via Home/Shift+End/Ctrl+C.
    Para quando detecta popup de fim de registro ou 2 blocos vazios.
    Retorna array de Map("protocolo", "conta", "convenio").
    @param primeiraLinha  Map com campos da primeira linha (opcional).
*/
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

/*
MovDoc_FinalizarBaixa()
    Marca o checkbox Recebido (clique simples ou duplo conforme estado),
    envia F10 para salvar e F7 para preparar nova consulta.
    Retorna true se todas as ações foram aceitas, false em falha.
*/
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

/*
MovDoc_WaitFirstGridLineReady(protocolo, &primeiraLinhaValida)
    Espera até que a primeira linha da grid contenha conta e convênio
    válidos (diferentes do protocolo), indicando que F8 populou a grid.
    Retorna true com primeiraLinhaValida preenchida ou false em timeout (12s).
    @param primeiraLinhaValida  Output variable; recebe Map("protocolo","conta","convenio").
*/
MovDoc_WaitFirstGridLineReady(protocolo, &primeiraLinhaValida) {
    global
    startedAt := A_TickCount
    deadline := startedAt + 12000

    Loop {
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

/*
MovDoc_GridValueValid(valor, campo)
    Validação semântica de valores lidos da grid.
    Descarta vazio, não numérico, e regras de tamanho por campo.
    @param valor  String lido via Ctrl+C.
    @param campo  "conta" ou "convenio" para regra de tamanho.
    @return true se válido, false caso contrário.
*/
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

/*
_AvancarBloco()
    Clica na última linha visível, envia Down N vezes (N = tamanho
    do bloco), detecta popup de fim e clica na primeira linha.
    Retorna Map("popup", true|false).
*/
_AvancarBloco() {
    ultimoY := MOVDOC_GRID_ROWS_Y[MOVDOC_GRID_ROWS_Y.Length]
    Click(MOVDOC_CONTA_X + 15, ultimoY + 8, 1)
    Sleep MOVDOC_KEY_SETTLE_MS

    Loop MOVDOC_GRID_ROWS_Y.Length {
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

/*
_ColetarVisiveis(protocolo, linhas, vistos)
    Lê conta e convênio das 4 coordenadas de linha visíveis.
    Filtra por protocolo e deduplica via Map vistos.
    Adiciona entradas em linhas e retorna contagem de adicionados.
    @return Integer com número de linhas adicionadas.
*/
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

/*
_FocusProtocolo()
    Ativa a janela Baixa e clica no campo Protocolo para preparar F7.
    Retorna true se o clique foi aceito, false em falha.
*/
_FocusProtocolo() {
    if !WinExist(MV_WIN_MOVDOC_BAIXA)
        return false

    WinActivate MV_WIN_MOVDOC_BAIXA
    if !MV_Poll(() => WinActive(MV_WIN_MOVDOC_BAIXA), 2)
        return false

    Click(MOVDOC_PROTOCOLO_X + 40, MOVDOC_PROTOCOLO_Y + 10, 1)
    return true
}

/*
_LerCampoGrid(x, y, campo, fastTimeoutMs, fallbackTimeoutMs)
    Clica na célula da grid, seleciona texto com Home/Shift+End,
    copia via Ctrl+C e valida semanticamente.
    Tenta duas vezes (fast + fallback) antes de retornar "".
    @return String com valor do campo ou "" em falha.
*/
_LerCampoGrid(x, y, campo := "", fastTimeoutMs := 150, fallbackTimeoutMs := 300) {
    if !WinExist(MV_WIN_MOVDOC_BAIXA)
        return ""

    WinActivate MV_WIN_MOVDOC_BAIXA
    if !MV_Poll(() => WinActive(MV_WIN_MOVDOC_BAIXA), 2)
        return ""

    Click(x + 15, y + 8, 1)
    Sleep MOVDOC_KEY_SETTLE_MS
    Send("{Home}{Shift down}{End}{Shift up}")

    valor := _CopySelecionado(fastTimeoutMs)
    if MovDoc_GridValueValid(valor, campo)
        return valor

    valor := _CopySelecionado(fallbackTimeoutMs)
    if MovDoc_GridValueValid(valor, campo)
        return valor

    return ""
}

/*
_CopySelecionado(timeoutMs)
    Limpa clipboard, envia Ctrl+C, aguarda texto estar disponível.
    @return String do clipboard ou "" em timeout.
*/
_CopySelecionado(timeoutMs := 500) {
    A_Clipboard := ""
    Send("^c")
    if !ClipWait(timeoutMs / 1000)
        return ""
    return Trim(A_Clipboard)
}
