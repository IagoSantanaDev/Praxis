; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_ScriptDir%\_mv_control_probe.ahk
#Include %A_ScriptDir%\..\lib\FFCV_ErrorTemplates.ahk

; Configuração conservadora para computadores rápidos e lentos.
; Evitar prioridade alta: o Oracle Forms também precisa de CPU para reagir aos eventos.
ListLines(false)
SetKeyDelay(10, 10)
SetMouseDelay(-1)
SetDefaultMouseSpeed(0)
SetControlDelay(-1)

; TESTE 11 - FFCV integrado: criar/buscar remessa + inserir conta + imprimir relatório
;
; Objetivo:
; - Reproduzir o fluxo FFCV validado no macro 03.
; - Acrescentar os botões mapeados por Window Spy:
;   - Inserir Conta:      Button10 @ Client 24,458
;   - Relatório/Imprimir: Button7  @ Client 567,458
;   - Entregar Remessa:   Button6  @ Client 464,458 (localização apenas neste macro)
; - Testar o popup embarcado "Informações da Conta" sem depender de WinTitle novo.
;
; Segurança:
; - DO_ACTION := false só localiza controles e não executa ações reais.
; - Para executar, coloque DO_ACTION := true e ligue uma etapa por vez.
; - Não use Screen x/y; todos os pontos abaixo são Client do Window Spy.

; ════════════════════════════════════════════════════════════════
;  FLAGS DE SEGURANÇA - ligue uma etapa por vez
; ════════════════════════════════════════════════════════════════

DO_ACTION                  := false
DO_OPEN                    := false ; abre FFCV por atalho local se não estiver aberto
DO_LOGIN                   := false ; só use se TEST_USER/TEST_PASS estiverem preenchidos localmente
DO_NAV                     := false ; Lançamentos -> Manutenção de Remessa
DO_LOAD_CONVENIO           := false ; F7 -> convênio -> F8 -> Tab x3
DO_SELECT_OR_CREATE_REMESSA := false ; TEST_REMESSA vazio cria; preenchido busca
DO_INSERT_ACCOUNT          := false ; abre Inserir Conta, configura dropdowns, envia todas as contas de TEST_CONTAS
DO_PRINT_RELATORIO         := false ; abre relatório de atendimentos e pressiona Enter para imprimir

; ════════════════════════════════════════════════════════════════
;  DADOS DE TESTE
; ════════════════════════════════════════════════════════════════

TEST_USER := ""
TEST_PASS := ""
TEST_CONVENIO := "450"
TEST_REMESSA := "511053" ; vazio cria nova; preenchido busca existente
TEST_TIPO_CONTA := "Ambulatório" ; Emergência / Internamento / Ambulatório

TEST_CONTA := ""

TEST_CONTAS := ["Prot. 3250671 | Conta 12963141 | Convênio 450",
    "Prot. 3250671 | Conta 12963659 | Convênio 450",
    "Prot. 3250671 | Conta 12963851 | Convênio 450",
    "Prot. 3250671 | Conta 12963753 | Convênio 450",
    "Prot. 3250671 | Conta 12963684 | Convênio 450",
    "Prot. 3250671 | Conta 12963610 | Convênio 450",
    "Prot. 3250671 | Conta 12965753 | Convênio 450",
    "Prot. 3250671 | Conta 12964852 | Convênio 450",
    "Prot. 3250671 | Conta 12965919 | Convênio 450",
    "Prot. 3250671 | Conta 12965486 | Convênio 450",
    "Prot. 3250671 | Conta 12964817 | Convênio 450",
    "Prot. 3250671 | Conta 12964661 | Convênio 450",
    "Prot. 3250671 | Conta 12964218 | Convênio 450",
    "Prot. 3250671 | Conta 12964192 | Convênio 450",
    "Prot. 3250671 | Conta 12964718 | Convênio 450",
    "Prot. 3250671 | Conta 12964473 | Convênio 450",
    "Prot. 3250671 | Conta 12965953 | Convênio 450",
    "Prot. 3250671 | Conta 12965844 | Convênio 450",
    "Prot. 3250671 | Conta 12964203 | Convênio 450",
    "Prot. 3250671 | Conta 12963809 | Convênio 450",
    "Prot. 3250671 | Conta 12962917 | Convênio 450",
    "Prot. 3250671 | Conta 12963683 | Convênio 450",
    "Prot. 3250671 | Conta 12963708 | Convênio 450",
    "Prot. 3250671 | Conta 12963793 | Convênio 450",
    "Prot. 3250671 | Conta 12964935 | Convênio 450",
    "Prot. 3250671 | Conta 12964524 | Convênio 450",
    "Prot. 3250671 | Conta 12964660 | Convênio 450",
    "Prot. 3250671 | Conta 12964705 | Convênio 450",
    "Prot. 3250671 | Conta 12946973 | Convênio 450",
    "Prot. 3250671 | Conta 12960205 | Convênio 450",
    "Prot. 3250671 | Conta 12967984 | Convênio 450",
    "Prot. 3250671 | Conta 12953676 | Convênio 450",
    "Prot. 3250671 | Conta 12953680 | Convênio 450",
    "Prot. 3250671 | Conta 12965638 | Convênio 450",
    "Prot. 3250671 | Conta 12968003 | Convênio 450",
    "Prot. 3250671 | Conta 12967776 | Convênio 450",
    "Prot. 3250671 | Conta 12967769 | Convênio 450",
    "Prot. 3250671 | Conta 12967696 | Convênio 450",
    "Prot. 3250671 | Conta 12967870 | Convênio 450",
    "Prot. 3250671 | Conta 12968046 | Convênio 450",
    "Prot. 3250671 | Conta 12967961 | Convênio 450",
    "Prot. 3250671 | Conta 12968001 | Convênio 450",
    "Prot. 3250671 | Conta 12967665 | Convênio 450",
    "Prot. 3250671 | Conta 12968052 | Convênio 450",
    "Prot. 3250671 | Conta 12967951 | Convênio 450",
    "Prot. 3250671 | Conta 12968016 | Convênio 450",
    "Prot. 3250671 | Conta 12967882 | Convênio 450",
    "Prot. 3250671 | Conta 12969197 | Convênio 450",
    "Prot. 3250671 | Conta 12968536 | Convênio 450",
    "Prot. 3250671 | Conta 12969007 | Convênio 450",
    "Prot. 3250671 | Conta 12968975 | Convênio 450",
    "Prot. 3250671 | Conta 12967090 | Convênio 450",
    "Prot. 3250671 | Conta 12967044 | Convênio 450",
    "Prot. 3250671 | Conta 12967110 | Convênio 450",
    "Prot. 3250671 | Conta 12967675 | Convênio 450",
    "Prot. 3250671 | Conta 12966663 | Convênio 450",
    "Prot. 3250671 | Conta 12960578 | Convênio 450",
    "Prot. 3250671 | Conta 12961420 | Convênio 450"]

FFCV_RUN := MV_Test_ProjectRoot() "\atalhos\FFCV.lnk"
WIN_LOGIN := "Identificação ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"
WIN_FFCV := "MV2000i - Faturamento ahk_exe ifrun60.EXE"
WIN_REMESSA := "MV2000i - Faturamento ahk_exe ifrun60.EXE"
WIN_RELATORIO := "Relatório de Atendimentos da Remessa ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"
WIN_MODAL := "ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"

; Botões da tela Manutenção de Remessa.
BTN_INSERIR_CONTA_CLASS := "Button10"
BTN_INSERIR_CONTA_X     := 24
BTN_INSERIR_CONTA_Y     := 458

BTN_IMPRIMIR_CLASS := "Button7"
BTN_IMPRIMIR_X     := 567
BTN_IMPRIMIR_Y     := 458

BTN_ENTREGAR_CLASS := "Button6"
BTN_ENTREGAR_X     := 464
BTN_ENTREGAR_Y     := 458

; Popup embarcado "Informações da Conta".
POPUP_SENTINEL_CLASS := "ui60Drawn W323"
POPUP_SENTINEL_X     := 432
POPUP_SENTINEL_Y     := 109

POPUP_DROPDOWN_1_CLASS := "ComboBox2"
POPUP_DROPDOWN_1_X     := 84
POPUP_DROPDOWN_1_Y     := 143

POPUP_DROPDOWN_2_CLASS := "ComboBox1"
POPUP_DROPDOWN_2_X     := 190
POPUP_DROPDOWN_2_Y     := 143

POPUP_CAMPO_CONTA_CLASS := "Edit2"
POPUP_CAMPO_CONTA_X     := 298
POPUP_CAMPO_CONTA_Y     := 143

MODAL_OK_CLASS := "Button1"

; Modal de erro ao inserir conta tem título/controle, mas a mensagem é desenhada em ui60Drawn.
; WinGetText/Window Spy podem expor só &OK; por isso classificamos por templates visuais.
; Cadastre/remova templates em lib\FFCV_ErrorTemplates.ahk.
ERROR_TEMPLATES := FFCV_ErrorTemplates()

; Polling rápido: reage assim que o modal aparecer, sem Sleep fixo longo.
; O teto fica abaixo de 1s; aumente só se o PC/MV estiver lento.
POLL_INTERVAL_MS          := 100
OPEN_POPUP_WAIT_MS        := 5000
MODAL_WAIT_AFTER_ENTER_MS := 650
NO_MODAL_DECISION_MS      := 180
POST_MODAL_SETTLE_MS      := 120
POST_ACCOUNT_SETTLE_MS    := 100
ACCOUNT_FIELD_FOCUS_MS    := 100
ACCOUNT_CLEAR_SETTLE_MS   := 100
ACCOUNT_EMPTY_READY_MS    := 100
STOP_ON_ACCOUNT_BLOCKER   := true

contasTeste := ParseContasTeste(TEST_CONTAS)

report := "SUÍTE: FFCV integrado - remessa + conta + impressão`n"
        . "DO_ACTION=" DO_ACTION " DO_OPEN=" DO_OPEN " DO_LOGIN=" DO_LOGIN " DO_NAV=" DO_NAV " DO_LOAD_CONVENIO=" DO_LOAD_CONVENIO " DO_SELECT_OR_CREATE_REMESSA=" DO_SELECT_OR_CREATE_REMESSA " DO_INSERT_ACCOUNT=" DO_INSERT_ACCOUNT " DO_PRINT_RELATORIO=" DO_PRINT_RELATORIO "`n"
        . "TEST_CONVENIO=" TEST_CONVENIO " TEST_REMESSA=" (TEST_REMESSA = "" ? "(criar nova)" : TEST_REMESSA) " TEST_TIPO_CONTA=" TEST_TIPO_CONTA " contas=" contasTeste.Length " [" JoinContas(contasTeste) "]`n`n"

if WinExist(WIN_FFCV) {
    report .= "✅ FFCV detectado por título amplo.`n"
    WinActivate WIN_FFCV
} else {
    report .= "⚠️ FFCV não detectado.`n"
    if DO_ACTION && DO_OPEN {
        if !FileExist(FFCV_RUN) {
            report .= "❌ Atalho FFCV não encontrado: " FFCV_RUN "`n"
            MV_Test_ShowReport(report)
            ExitApp
        }
        Run FFCV_RUN
        report .= "▶️ Run FFCV executado por atalho local.`n"
        if !T_Poll(() => WinExist(WIN_LOGIN) || WinExist(WIN_FFCV), 20)
            report .= "❌ Login/FFCV não apareceu após abrir.`n"
    }
}

if WinExist(WIN_LOGIN) {
    report .= "ℹ️ Janela Identificação detectada.`n"
    if DO_ACTION && DO_LOGIN {
        if (Trim(TEST_USER) = "" || TEST_PASS = "") {
            report .= "❌ DO_LOGIN ligado, mas TEST_USER/TEST_PASS estão vazios.`n"
            MV_Test_ShowReport(report)
            ExitApp
        }
        WinActivate WIN_LOGIN
        WinWaitActive WIN_LOGIN,, 2
        CoordMode("Mouse", "Client")
        Click(170, 118, 1)
        Sleep ACCOUNT_FIELD_FOCUS_MS
        SendText TEST_USER
        Sleep ACCOUNT_FIELD_FOCUS_MS
        Click(307, 119, 1)
        Sleep ACCOUNT_FIELD_FOCUS_MS
        SendText TEST_PASS
        Sleep ACCOUNT_FIELD_FOCUS_MS
        Send "{Enter}"
        report .= "✅ Login enviado por coordenadas Client validadas da Identificação.`n"
        T_Poll(() => WinExist(WIN_FFCV), 20)
    }
}

if !DO_ACTION {
    report .= "`nModo seguro: localizando controles conhecidos na janela FFCV atual.`n"
    if WinExist(WIN_FFCV) {
        controls := [
            Map("name", "BTN_INSERIR_CONTA", "class", BTN_INSERIR_CONTA_CLASS, "x", BTN_INSERIR_CONTA_X, "y", BTN_INSERIR_CONTA_Y, "action", "locate"),
            Map("name", "BTN_IMPRIMIR",      "class", BTN_IMPRIMIR_CLASS,      "x", BTN_IMPRIMIR_X,      "y", BTN_IMPRIMIR_Y,      "action", "locate"),
            Map("name", "BTN_ENTREGAR",      "class", BTN_ENTREGAR_CLASS,      "x", BTN_ENTREGAR_X,      "y", BTN_ENTREGAR_Y,      "action", "locate"),
            Map("name", "POPUP_SENTINEL",    "class", POPUP_SENTINEL_CLASS,    "x", POPUP_SENTINEL_X,    "y", POPUP_SENTINEL_Y,    "action", "locate"),
            Map("name", "POPUP_CAMPO_CONTA", "class", POPUP_CAMPO_CONTA_CLASS, "x", POPUP_CAMPO_CONTA_X, "y", POPUP_CAMPO_CONTA_Y, "action", "locate")
        ]
        for _, spec in controls
            report .= MV_Test_RunOne(WIN_FFCV, spec, false, 20) "`n"
    } else {
        report .= "ℹ️ FFCV não está aberto; nada para localizar.`n"
    }
    report .= "`nPara executar o fluxo, coloque DO_ACTION := true e ligue etapas uma por vez.`n"
    MV_Test_ShowReport(report)
    ExitApp
}

if DO_NAV {
    if !WinExist(WIN_FFCV) {
        report .= "❌ FFCV não está aberto para navegar.`n"
        MV_Test_ShowReport(report)
        ExitApp
    }
    WinActivate WIN_FFCV
    Send "{Alt down}lm{Alt up}{Enter}"
    if T_Poll(() => WinExist(WIN_REMESSA), 20)
        report .= "✅ Tela Manutenção de Remessa detectada.`n"
    else
        report .= "❌ Tela Manutenção de Remessa não detectada.`n"
}

if DO_LOAD_CONVENIO {
    WinActivate WIN_FFCV
    Sleep 100
    Send "{F7}"
    Sleep ACCOUNT_FIELD_FOCUS_MS
    SendText TEST_CONVENIO
    Sleep ACCOUNT_FIELD_FOCUS_MS
    Send "{F8}"
    Sleep ACCOUNT_FIELD_FOCUS_MS
    Send "{Tab 3}"
    report .= "✅ F7 → convênio → F8 → Tab x3 enviado com micro-settle.`n"
}

if DO_SELECT_OR_CREATE_REMESSA {
    if (Trim(TEST_REMESSA) != "") {
        Sleep 100
        Send "{F7}"
        Sleep ACCOUNT_FIELD_FOCUS_MS
        SendText TEST_REMESSA
        Sleep ACCOUNT_FIELD_FOCUS_MS
        Send "{F8}"
        Sleep ACCOUNT_FIELD_FOCUS_MS
        report .= "✅ Busca de remessa existente enviada com micro-settle: " TEST_REMESSA "`n"
    } else {
        Sleep 100
        hoje := FormatTime(, "dd/MM/yyyy")
        Send "{F6}"
        Sleep ACCOUNT_FIELD_FOCUS_MS
        SendText hoje
        Sleep ACCOUNT_FIELD_FOCUS_MS
        Send "{Tab 3}"
        Sleep ACCOUNT_FIELD_FOCUS_MS
        SendText T_TipoContaCodigo(TEST_TIPO_CONTA)
        Sleep ACCOUNT_FIELD_FOCUS_MS
        Send "{F10}"
        Sleep ACCOUNT_FIELD_FOCUS_MS
        report .= "✅ Nova remessa enviada com micro-settle: data=" hoje " tipo=" TEST_TIPO_CONTA " código=" T_TipoContaCodigo(TEST_TIPO_CONTA) "`n"
    }
}

if DO_INSERT_ACCOUNT {
    report .= InserirContasNaRemessa(contasTeste, TEST_TIPO_CONTA)
}

if DO_PRINT_RELATORIO {
    report .= ImprimirRelatorioAtendimentos()
}

MV_Test_ShowReport(report)

T_TipoContaCodigo(tipoConta) {
    switch tipoConta {
        case "Emergência": return "1"
        case "Internamento": return "2"
        case "Ambulatório": return "3"
        default: return ""
    }
}

InserirContasNaRemessa(contas, tipoConta) {
    msg := "`n▶️ Inserindo " contas.Length " conta(s)...`n"
    if (contas.Length = 0)
        return msg "❌ Nenhuma conta válida encontrada em TEST_CONTAS/TEST_CONTA.`n"

    okCount := 0
    erroCount := 0
    blockerCount := 0

    setup := AbrirConfigurarPopupContas(tipoConta)
    msg .= setup["report"]
    if !setup["ok"]
        return msg "⛔ Não foi possível preparar o popup de contas; lote não iniciado.`n"

    for idx, conta in contas {
        result := InserirContaNoPopupAberto(conta, idx, contas.Length)
        msg .= result["report"]

        if (result["status"] = "ok")
            okCount++
        else if (result["status"] = "erro")
            erroCount++
        else
            blockerCount++

        if result["blocker"] {
            msg .= "⛔ Parando lote para não avançar com estado incerto. Última conta NÃO deve ser considerada enviada: " conta "`n"
            if STOP_ON_ACCOUNT_BLOCKER
                break
        }
    }

    msg .= "`nRESUMO INSERÇÃO: ok=" okCount " erro/modal=" erroCount " bloqueio=" blockerCount " total=" contas.Length "`n"

    if (blockerCount = 0) {
        closeResult := CloseContaPopupAndWait()
        msg .= closeResult["report"]
        report .= ImprimirRelatorioAtendimentos()
        if !closeResult["ok"]
            msg .= "⛔ Lote terminou, mas não consegui fechar o popup de contas com Alt+2.`n"
    }

    return msg
}

AbrirConfigurarPopupContas(tipoConta) {
    msg := "▶️ Abrindo popup Informações da Conta uma única vez para o lote...`n"

    if !EnsureFFCVActive()
        return Map("ok", false, "report", msg "❌ FFCV não ficou ativa antes de clicar em Inserir Conta.`n")

    WinActivate WIN_FFCV
    Sleep 100

    if !ClickBySpec(WIN_FFCV, BTN_INSERIR_CONTA_CLASS, BTN_INSERIR_CONTA_X, BTN_INSERIR_CONTA_Y)
        return Map("ok", false, "report", msg "❌ Não consegui clicar em Inserir Conta.`n")

    popupReady := WaitContaPopupReady(OPEN_POPUP_WAIT_MS)
    msg .= popupReady["report"]

    if !popupReady["ok"]
        return Map("ok", false, "report", msg)

    if ModalVisivel() && !PopupContaVisivel()
        return Map("ok", false, "report", msg "⚠️ Modal apareceu antes do popup. Conteúdo textual acessível:`n" SafeWinGetText(WIN_MODAL) "`n")

    if !EnsureFFCVActive()
        return Map("ok", false, "report", msg "❌ FFCV não ficou ativa antes dos atalhos do popup.`n")

    stable := WaitContaPopupStable(300)
    msg .= stable["report"]

    if !stable["ok"]
        return Map("ok", false, "report", msg)

    ; Configura dropdowns uma única vez. O popup permanece aberto para todas as contas.
    if (tipoConta = "Internamento") {
        Send("{Tab 3}")
        Sleep 100
        Send("{Down 2}")
        Sleep 100
        Send("{Tab}")
        Sleep 100
        Send("{Tab 2}")
        Sleep 100
        msg .= "✅ Internamento detectado: comando de Up ignorado.`n"
    }
    else if (tipoConta = "Emergência" || tipoConta = "Ambulatório") {
        Send("{Tab 3}")
        Sleep 100
        Send("{Down 2}")
        Sleep 100
        Send("{Tab 2}")
        Sleep 100
        Send("{Up 2}")
        Sleep 100
        Send("{Tab}")
        Sleep 100
        msg .= "✅ Ajustado com Up x2 para " tipoConta ".`n"
    }

    return Map("ok", true, "report", msg "✅ Popup configurado e mantido aberto para o lote.`n")
}


InserirContaNoPopupAberto(conta, idx := 1, total := 1) {
    msg := "`n▶️ Inserindo conta " conta " (" idx "/" total ") no popup já aberto...`n"

    envio := LimparCampoContaEnviar(conta)
    msg .= envio["report"]
    if !envio["ok"]
        return Map("status", "blocker", "blocker", true, "report", msg)

    outcome := WaitContaSubmitOutcome(MODAL_WAIT_AFTER_ENTER_MS, conta)
    msg .= outcome["report"]

    if (outcome["status"] = "modal") {
        modalReport := DismissActiveModalAndWait()
        msg .= modalReport["report"]
        if !modalReport["ok"]
            return Map("status", "blocker", "blocker", true, "report", msg)

        if !T_PollMs(() => PopupContaVisivel(), OPEN_POPUP_WAIT_MS)
            return Map("status", "blocker", "blocker", true, "report", msg "❌ Modal foi fechado, mas o popup de conta não voltou/estabilizou.`n")

        return Map("status", "erro", "blocker", false, "report", msg "⚠️ Conta tratada como erro/modal (" outcome["erro"]["descricao"] ") e popup mantido aberto: " conta "`n")
    }

    if (outcome["status"] != "ready")
        return Map("status", "blocker", "blocker", true, "report", msg "❌ Não houve estado estável após Enter; conta NÃO deve ser considerada enviada: " conta "`n")

    return Map("status", "ok", "blocker", false, "report", msg "✅ Conta sem modal; popup mantido aberto para próxima conta: " conta "`n")
}

LimparCampoContaEnviar(conta) {
    if !PopupContaVisivel()
        return Map("ok", false, "report", "❌ Popup de conta não está visível antes de limpar/enviar a conta " conta ".`n")

    if !EnsureFFCVActive()
        return Map("ok", false, "report", "❌ FFCV não ficou ativa antes de limpar/enviar a conta " conta ".`n")

    ; Regra validada: Ctrl+A não é confiável no Oracle Forms.
    ; Fast path: manter clique físico, mas reduzir Sleeps; segurança fica na espera pós-Enter.
    CoordMode("Mouse", "Client")
    Click(POPUP_CAMPO_CONTA_X + 15, POPUP_CAMPO_CONTA_Y + 8, 1)
    Sleep ACCOUNT_FIELD_FOCUS_MS
    Send("{Home}{Shift down}{End}{Shift up}{Backspace}")
    Sleep ACCOUNT_CLEAR_SETTLE_MS
    SendText(conta)
    Send("{Enter}")

    return Map("ok", true, "report", "✅ Campo da conta clicado, limpo, conta digitada e Enter enviado: " conta "`n")
}

ImprimirRelatorioAtendimentos() {
    msg := "`n▶️ Abrindo relatório de atendimentos...`n"
    if !ClickBySpec(WIN_FFCV, BTN_IMPRIMIR_CLASS, BTN_IMPRIMIR_X, BTN_IMPRIMIR_Y)
        return msg "❌ Não consegui clicar em Relatório Atend.`n"

    if !T_Poll(() => WinExist(WIN_RELATORIO), 10)
        return msg "❌ Janela Relatório de Atendimentos da Remessa não apareceu.`n"

    WinActivate WIN_RELATORIO
    Sleep 100
    Send "{Enter}"
    msg .= "✅ Enter enviado no relatório para imprimir/confirmar botão padrão.`n"
    return msg
}

ModalVisivel() {
    return WinExist(WIN_MODAL)
}

EnsureFFCVActive(timeoutSecs := 3) {
    if !WinExist(WIN_FFCV)
        return false

    WinActivate WIN_FFCV
    return WinWaitActive(WIN_FFCV,, timeoutSecs) != 0
}

WaitContaPopupReady(timeoutMs) {
    startedAt := A_TickCount

    Loop {
        if ModalVisivel() {
            elapsed := A_TickCount - startedAt
            return Map("ok", true, "modal", true, "elapsed", elapsed, "report", "ℹ️ Modal detectado " elapsed "ms após Inserir Conta, antes do popup.`n")
        }

        if PopupContaVisivel() {
            elapsed := A_TickCount - startedAt
            return Map("ok", true, "modal", false, "elapsed", elapsed, "report", "ℹ️ Popup Informações da Conta detectado em " elapsed "ms.`n")
        }

        if (A_TickCount - startedAt >= timeoutMs) {
            return Map("ok", false, "modal", false, "elapsed", A_TickCount - startedAt, "report", "❌ Popup Informações da Conta não apareceu após Inserir Conta em " timeoutMs "ms. Verifique sentinela ui60Drawn no ponto Client " POPUP_SENTINEL_X "," POPUP_SENTINEL_Y " e campo de conta no ponto " POPUP_CAMPO_CONTA_X "," POPUP_CAMPO_CONTA_Y ".`n")
        }

        Sleep POLL_INTERVAL_MS
    }
}

WaitContaPopupStable(stableMs := 300, timeoutMs := 1200) {
    startedAt := A_TickCount
    stableSince := 0

    Loop {
        if ModalVisivel()
            return Map("ok", false, "report", "⚠️ Modal apareceu enquanto aguardava estabilidade do popup de conta.`n")

        if PopupContaVisivel() {
            if (stableSince = 0)
                stableSince := A_TickCount

            if (A_TickCount - stableSince >= stableMs)
                return Map("ok", true, "report", "✅ Popup de conta estável por " stableMs "ms antes dos atalhos.`n")
        } else {
            stableSince := 0
        }

        if (A_TickCount - startedAt >= timeoutMs)
            return Map("ok", false, "report", "❌ Popup de conta não estabilizou por " stableMs "ms dentro de " timeoutMs "ms.`n")

        Sleep POLL_INTERVAL_MS
    }
}

WaitReadyForNextAccount(timeoutMs) {
    if ModalVisivel() {
        result := DismissActiveModalAndWait()
        return result["ok"]
    }

    ; Com a regra nova, o popup de conta pode permanecer aberto durante todo o lote.
    return true
}

WaitContaSubmitOutcome(timeoutMs, submittedConta := "") {
    startTick := A_TickCount
    deadline := startTick + timeoutMs
    stableSince := 0
    emptySince := 0

    Loop {
        if ModalVisivel() {
            erro := ClassificarModalErro()
            return Map("status", "modal", "erro", erro, "report", "ℹ️ Modal de erro detectado após Enter: " erro["descricao"] " [" erro["fonte"] "]`nTexto acessível pelo AHK:`n" erro["texto"] "`n")
        }

        fieldText := GetContaFieldText()
        if (submittedConta != "" && fieldText != submittedConta && fieldText = "") {
            if (emptySince = 0)
                emptySince := A_TickCount
            if (A_TickCount - emptySince >= ACCOUNT_EMPTY_READY_MS)
                return Map("status", "ready", "report", "✅ Campo esvaziou após " Round((A_TickCount - startTick) / 1000, 2) "s; liberado para próxima conta.`n")
        } else {
            emptySince := 0
        }

        if PopupContaVisivel() {
            if (stableSince = 0)
                stableSince := A_TickCount

            if (A_TickCount - startTick >= NO_MODAL_DECISION_MS && A_TickCount - stableSince >= POST_ACCOUNT_SETTLE_MS)
                return Map("status", "ready", "report", "✅ Nenhum modal após " Round((A_TickCount - startTick) / 1000, 2) "s; popup está estável para próxima conta.`n")
        } else {
            stableSince := 0
        }

        if (A_TickCount > deadline) {
            if (stableSince != 0 && A_TickCount - stableSince >= POST_ACCOUNT_SETTLE_MS)
                return Map("status", "ready", "report", "✅ Nenhum modal após " Round((A_TickCount - startTick) / 1000, 2) "s; popup está estável para próxima conta.`n")
            return Map("status", "timeout", "report", "❌ Timeout aguardando modal ou popup estável após Enter.`n")
        }

        Sleep POLL_INTERVAL_MS
    }
}

GetContaFieldText() {
    hwnd := FindControlByClassPrefixAtPoint(WIN_FFCV, "Edit", POPUP_CAMPO_CONTA_X, POPUP_CAMPO_CONTA_Y, 35)
    if !hwnd
        return ""
    try return Trim(ControlGetText(hwnd))
    catch
        return ""
}

DismissActiveModalAndWait() {
    msg := ""
    if !ModalVisivel()
        return Map("ok", true, "report", msg)

    ; Aguarda o Button1 aparecer; durante renderização o modal pode existir antes dos controles.
    if !T_PollMs(() => FirstControlByClass(WIN_MODAL, MODAL_OK_CLASS) != 0, OPEN_POPUP_WAIT_MS)
        return Map("ok", false, "report", "❌ Modal existe, mas o botão OK não ficou disponível em " OPEN_POPUP_WAIT_MS "ms.`n")

    if !ClickFirstByClass(WIN_MODAL, MODAL_OK_CLASS)
        return Map("ok", false, "report", "❌ Não consegui clicar OK do modal.`n")

    if !T_PollMs(() => !ModalVisivel(), OPEN_POPUP_WAIT_MS)
        return Map("ok", false, "report", "❌ Cliquei OK, mas o modal não fechou em " OPEN_POPUP_WAIT_MS "ms.`n")

    Sleep POST_MODAL_SETTLE_MS
    return Map("ok", true, "report", "✅ OK do modal clicado e janela fechada/estabilizada.`n")
}

CloseContaPopupAndWait() {
    ; Regra: manter o popup aberto durante o lote e fechar com Alt+2 somente ao final.
    if !PopupContaVisivel()
        return Map("ok", true, "report", "✅ Popup de conta já estava fechado ao final do lote.`n")

    if !EnsureFFCVActive()
        return Map("ok", false, "report", "❌ FFCV não ficou ativa para fechar o popup de conta ao final do lote.`n")

    Send "!2"

    if !T_PollMs(() => !PopupContaVisivel() && !ModalVisivel(), OPEN_POPUP_WAIT_MS)
        return Map("ok", false, "report", "❌ Alt+2 enviado ao final do lote, mas popup/modal não estabilizou fechado em " OPEN_POPUP_WAIT_MS "ms.`n")

    Sleep POST_ACCOUNT_SETTLE_MS
    return Map("ok", true, "report", "✅ Alt+2 enviado ao final do lote; popup de conta fechado.`n")
}

ClassificarModalErro() {
    texto := SafeWinGetText(WIN_MODAL)
    lower := StrLower(texto)

    ; Caso algum ambiente exponha texto via AHK/UIA no futuro, classifica pelo texto antes do visual.
    if InStr(lower, "já foi digitada") || InStr(lower, "ja foi digitada") || InStr(lower, "redigite")
        return Map("tipo", "conta_ja_digitada", "descricao", "Conta já digitada / redigite", "fonte", "texto", "texto", texto)

    for _, tpl in ERROR_TEMPLATES {
        if ErrorTemplateVisible(tpl["img"])
            return Map("tipo", tpl["tipo"], "descricao", tpl["descricao"], "fonte", "template visual", "texto", texto)
    }

    return Map("tipo", "erro_desconhecido", "descricao", "Erro modal não classificado", "fonte", "modal sem texto acessível", "texto", texto)
}

ErrorTemplateVisible(imagePath, variation := 35) {
    if !FileExist(imagePath)
        return false

    try WinGetPos &wx, &wy, &ww, &wh, WIN_MODAL
    catch
        return false

    CoordMode "Pixel", "Screen"
    try return ImageSearch(&x, &y, wx, wy, wx + ww, wy + wh, "*" variation " " imagePath)
    catch
        return false
}

SafeWinGetText(winTitle) {
    try text := WinGetText(winTitle)
    catch as e
        return "<erro WinGetText: " e.Message ">"

    text := Trim(text)
    if (text = "" || text = "&OK" || text = "&Sim`r`n&Não" || text = "&Não`r`n&Sim")
        return text "`n<observação: Oracle Forms desenha a mensagem em ui60Drawn; WinGetText/Window Spy podem expor só botões.>"
    return text
}

FirstControlByClass(winTitle, classNN) {
    try hwnds := WinGetControlsHwnd(winTitle)
    catch
        return 0

    for hwnd in hwnds {
        try ctrlClass := ControlGetClassNN(hwnd)
        catch
            continue
        if (ctrlClass = classNN)
            return hwnd
    }
    return 0
}

PopupContaVisivel() {
    sentinel := FindControlByClassPrefixAtPoint(WIN_FFCV, "ui60Drawn", POPUP_SENTINEL_X, POPUP_SENTINEL_Y, 35)
    if !sentinel
        return false
    campo := MV_Test_FindControlByClientPoint(WIN_FFCV, POPUP_CAMPO_CONTA_CLASS, POPUP_CAMPO_CONTA_X, POPUP_CAMPO_CONTA_Y, 35).Get("hwnd", 0)
    if !campo
        campo := FindControlByClassPrefixAtPoint(WIN_FFCV, "Edit", POPUP_CAMPO_CONTA_X, POPUP_CAMPO_CONTA_Y, 50)

    if !campo
        campo := FindControlByClassPrefixAtPoint(WIN_FFCV, "ComboBox", POPUP_DROPDOWN_1_X, POPUP_DROPDOWN_1_Y, 40)

    if !campo
        campo := FindControlByClassPrefixAtPoint(WIN_FFCV, "ComboBox", POPUP_DROPDOWN_2_X, POPUP_DROPDOWN_2_Y, 40)

    return campo != 0
}

FindControlByClassPrefixAtPoint(winTitle, classPrefix, targetX, targetY, tolerance := 35) {
    try hwnds := WinGetControlsHwnd(winTitle)
    catch
        return 0

    bestHwnd := 0
    bestDist := 999999

    for hwnd in hwnds {
        try ctrlClass := ControlGetClassNN(hwnd)
        catch
            continue

        if (SubStr(ctrlClass, 1, StrLen(classPrefix)) != classPrefix)
            continue

        try ControlGetPos(&cx, &cy, &cw, &ch, hwnd, winTitle)
        catch
            continue

        if (targetX >= cx && targetX <= cx + cw && targetY >= cy && targetY <= cy + ch)
            return hwnd

        centerX := cx + (cw / 2)
        centerY := cy + (ch / 2)
        dist := Sqrt((targetX - centerX) ** 2 + (targetY - centerY) ** 2)
        if (dist < bestDist) {
            bestDist := dist
            bestHwnd := hwnd
        }
    }

    return (bestHwnd && bestDist <= tolerance) ? bestHwnd : 0
}

ParseContasTeste(contasText, fallbackConta := "") {
    result := []
    vistos := Map()
    text := ""

    ; TRAVA DE COMPATIBILIDADE: Se for uma Array, junta todas as linhas com quebra de linha `n
    if (contasText is Array) {
        for _, item in contasText {
            text .= item "`n"
        }
    } else {
        text := Trim(contasText)
    }

    ; Se o texto principal continuar vazio, recorre ao fallback
    if (Trim(text) = "") {
        if (fallbackConta is Array) {
            for _, item in fallbackConta
                text .= item "`n"
        } else {
            text := Trim(fallbackConta)
        }
    }

    ; Normaliza separadores comuns mantendo linhas
    text := StrReplace(text, "`r", "`n")
    text := RegExReplace(text, "`n+", "`n")

    for _, rawLine in StrSplit(text, "`n") {
        line := Trim(rawLine)
        if (line = "")
            continue

        ; Se vier do MOV DOC como "protocolo | conta | convenio", a conta é a segunda coluna numérica
        if InStr(line, "|") {
            nums := ExtractNumbers(line)
            if (nums.Length >= 2) {
                AddConta(result, vistos, nums[2])
                continue
            }
        }

        ; Para linhas sem pipe, aceita números separados por vírgula, ponto-e-vírgula, espaço etc.
        nums := ExtractNumbers(line)
        for _, n in nums {
            AddConta(result, vistos, n)
        }
    }
    return result
}


ExtractNumbers(text) {
    nums := []
    pos := 1
    while pos := RegExMatch(text, "\d{6,}", &m, pos) {
        nums.Push(m[0])
        pos += StrLen(m[0])
    }
    return nums
}

AddConta(result, vistos, conta) {
    conta := Trim(conta)
    if (conta = "" || vistos.Has(conta))
        return
    vistos[conta] := true
    result.Push(conta)
}

JoinContas(contas) {
    text := ""
    for idx, conta in contas {
        if (idx > 1)
            text .= ","
        text .= conta
    }
    return text
}

IsMapped(classNN, x, y) {
    return !(classNN = "" || classNN = "CLASSNN" || x = "" || y = "")
}

FocusBySpec(winTitle, classNN, x, y) {
    if !IsMapped(classNN, x, y)
        return false
    found := MV_Test_FindControlByClientPoint(winTitle, classNN, x + 0, y + 0, 20)
    hwnd := found.Get("hwnd", 0)
    if !hwnd {
        try {
            WinActivate winTitle
            WinWaitActive winTitle,, 2
            CoordMode("Mouse", "Client")
            Click x, y, 1
            return true
        } catch {
            return false
        }
    }
    try {
        ControlFocus hwnd
        return true
    } catch {
        try {
            WinActivate winTitle
            WinWaitActive winTitle,, 2
            CoordMode("Mouse", "Client")
            Click x, y, 1
            return true
        } catch {
            return false
        }
    }
}

ClickBySpec(winTitle, classNN, x, y) {
    if !IsMapped(classNN, x, y)
        return false
    found := MV_Test_FindControlByClientPoint(winTitle, classNN, x + 0, y + 0, 20)
    hwnd := found.Get("hwnd", 0)
    if !hwnd {
        try {
            WinActivate winTitle
            WinWaitActive winTitle,, 2
            CoordMode("Mouse", "Client")
            Click x, y, 1
            return true
        } catch {
            return false
        }
    }
    try {
        ControlClick hwnd,,,,, "NA"
        return true
    } catch {
        try {
            WinActivate winTitle
            WinWaitActive winTitle,, 2
            CoordMode("Mouse", "Client")
            Click x, y, 1
            return true
        } catch {
            return false
        }
    }
}

ClickFirstByClass(winTitle, classNN) {
    try hwnds := WinGetControlsHwnd(winTitle)
    catch
        return false

    for hwnd in hwnds {
        try ctrlClass := ControlGetClassNN(hwnd)
        catch
            continue
        if (ctrlClass = classNN) {
            ControlClick hwnd,,,,, "NA"
            return true
        }
    }
    return false
}

T_PollMs(condFn, timeoutMs, intervalMs := 0) {
    if (intervalMs <= 0)
        intervalMs := POLL_INTERVAL_MS
    deadline := A_TickCount + timeoutMs
    Loop {
        if condFn()
            return true
        if A_TickCount > deadline
            return false
        Sleep intervalMs
    }
}

T_Poll(condFn, timeoutSecs) {
    deadline := A_TickCount + timeoutSecs * 1000
    Loop {
        if condFn()
            return true
        if A_TickCount > deadline
            return false
        Sleep POLL_INTERVAL_MS
    }
}
