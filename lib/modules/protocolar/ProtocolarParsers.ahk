; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug
#Include ..\..\..\lib\globals\mv\MVSession.ahk
#Include ..\..\..\lib\globals\mv\ParseUtils.ahk

Protocolar_ExtractContasFromCsv(path, deduplicar := true, tipo := "Ambulatorial") {
    if !FileExist(path)
        throw Error("CSV de contas nao encontrado: " path)

    text := StrReplace(FileRead(path, "UTF-8"), "`r", "")
    lines := StrSplit(text, "`n")
    if (lines.Length < 2)
        throw Error("CSV de contas sem linhas de dados: " path)

    accountColumn := 0
    expectedColumn := Protocolar_GetCsvContaColumnName(tipo)
    header := MV_SplitSemicolonCsvLine(lines[1])
    for index, column in header {
        if (Protocolar_NormalizeCsvHeaderName(column) = expectedColumn) {
            accountColumn := index
            break
        }
    }
    if (accountColumn = 0)
        throw Error("Coluna " expectedColumn " nao encontrada no CSV: " path)

    MV_Log("Protocolar_ExtractContasFromCsv", "Coluna de contas usada: " expectedColumn ".", true)

    accounts := []
    seen := Map()
    for index, line in lines {
        if (index = 1 || Trim(line) = "")
            continue

        columns := MV_SplitSemicolonCsvLine(line)
        if (columns.Length < accountColumn)
            continue

        account := RegExReplace(Trim(columns[accountColumn]), "\D")
        if (account = "")
            continue
        if (deduplicar && seen.Has(account))
            continue

        seen[account] := true
        accounts.Push(account)
    }
    return accounts
}

Protocolar_GetCsvContaColumnName(tipo) {
    return Protocolar_IsHospitalar(tipo) ? "CONTA" : "CD_REG_AMB"
}

Protocolar_IsHospitalar(tipo) {
    normalized := StrLower(Trim(String(tipo)))
    return normalized = "hospitalar" || normalized = "internamento"
}

Protocolar_NormalizeCsvHeaderName(name) {
    name := StrReplace(name, Chr(0xFEFF), "")
    return StrUpper(Trim(name))
}

; ════════════════════════════════════════════════════════════════
;  PROTOCOLAR PARSERS
;  Lógica de parsing para o módulo Protocolar
; ════════════════════════════════════════════════════════════════

Protocolar_Abort(msg) {
    ; Delega para a canônica MV_Abort (MVSession.ahk) preservando o
    ; comportamento original (status "Execução finalizada.").
    return MV_Abort(msg, true)
}

; ── Classificação de popups do MV durante o envio de contas ───
; Regras de negócio recuperadas por engenharia reversa do Protocolar.exe
; original (o MV não documenta esse comportamento) — ver
; Protocolar_ProcessarConta (Protocolar.ahk) para o que cada uma significa
; operacionalmente e como é tratada.
PROTOCOLAR_MIN_PROTOCOLO_DIGITS := 7

; Normaliza o texto lido por OCR do popup para comparação: minúsculas, sem
; acento, colapsa variações de "nº"/"protoco1o" (erros comuns de OCR) e
; espaços repetidos.
Protocolar_NormalizeOcrText(text) {
    text := StrLower(Trim(RegExReplace(text, "[\r\n]+", " ")))
    text := RegExReplace(text, "\s+", " ")
    replacements := Map(
        "á", "a", "à", "a", "ã", "a", "â", "a", "ä", "a",
        "é", "e", "è", "e", "ê", "e", "ë", "e",
        "í", "i", "ì", "i", "î", "i", "ï", "i",
        "ó", "o", "ò", "o", "õ", "o", "ô", "o", "ö", "o",
        "ú", "u", "ù", "u", "û", "u", "ü", "u",
        "ç", "c"
    )
    for from, to in replacements
        text := StrReplace(text, from, to)
    text := StrReplace(text, "n.º", "n")
    text := StrReplace(text, "n°", "n")
    text := StrReplace(text, "nº", "n")
    text := StrReplace(text, "n.0", "n")
    text := StrReplace(text, "n.o", "n")
    text := StrReplace(text, "n 0", "n")
    text := StrReplace(text, "protocol0", "protocolo")
    text := StrReplace(text, "protoco1o", "protocolo")
    text := RegExReplace(text, "\bant[e3]5\b", "antes")
    text := RegExReplace(text, "\bant[e3]s\b", "antes")
    text := RegExReplace(text, "\batenc[a-z0-9]*\b", "atencao")
    text := RegExReplace(text, "\bcanta\b", "conta")
    text := RegExReplace(text, "\bcont4\b", "conta")
    text := RegExReplace(text, "\bconla\b", "conta")
    text := RegExReplace(text, "moviment[a-z0-9]*", "movimentacao")
    text := RegExReplace(text, "\s+", " ")
    return Trim(text)
}

; "[...] restante dos dados de movimentação antes de criar um novo
; registro [...]": o Enter anterior não foi processado pelo MV. Reenviar a
; MESMA conta resolve na quase totalidade dos casos observados.
Protocolar_IsPopupDadosIncompletos(loose) {
    return ((InStr(loose, "antes") && InStr(loose, "criar") && InStr(loose, "novo") && InStr(loose, "registro"))
        || (InStr(loose, "restante") && InStr(loose, "dados") && InStr(loose, "moviment"))
        || (InStr(loose, "novo") && InStr(loose, "registro") && InStr(loose, "moviment")))
}

; "[...] documento com protocolo pendente [...]": a conta já tem um
; protocolo aberto (de uma tentativa anterior). A ação correta é baixar
; esse protocolo em vez de tentar criar um novo envio para ela — extrai o
; número do protocolo do texto do popup.
Protocolar_ExtrairProtocoloPendente(loose, minDigits := PROTOCOLAR_MIN_PROTOCOLO_DIGITS) {
    if !InStr(loose, "pendente")
        return ""
    if !(InStr(loose, "devolu") || InStr(loose, "receb") || InStr(loose, "document"))
        return ""
    if (minDigits < 4)
        minDigits := 4
    protocoloPattern := "(\d{" minDigits ",})"
    if RegExMatch(loose, "protoc[a-z0-9]*\s*(?:n|n\.|n0|no|numero|num)?\s*[\.:º°o0]*\s*" protocoloPattern, &m)
        return m[1]
    pos := RegExMatch(loose, "protoc[a-z0-9]*", &p)
    if pos {
        after := SubStr(loose, pos)
        if RegExMatch(after, protocoloPattern, &m)
            return m[1]
    }
    return ""
}

; "[...] setor recebido diferente do setor atual informado [...]": a conta
; está fisicamente em outro setor. Extrai o setor onde ela realmente está,
; corrigindo dígitos mal lidos pelo OCR quando o contexto é consistente
; (ver Protocolar_CorrigirSetorPorContexto).
Protocolar_ExtrairSetorRecebido(loose, setorEnvioEsperado, setorAtual) {
    hasConta := InStr(loose, "conta") || InStr(loose, "canta") || InStr(loose, "cont4")
    if !(InStr(loose, "setor") && InStr(loose, "diferente") && hasConta)
        return ""

    candidato := ""
    if RegExMatch(loose, "setor\s*(?:recebido|recebida|recebid0|receb1do|receb|receh|recen|reced)[a-z0-9]*\s*[:;.,\-]?\s*(\d{1,4})", &m)
        candidato := m[1]

    if (candidato = "") {
        pos := RegExMatch(loose, "setor\s*(?:receb|receh|recen|reced)[a-z0-9]*", &mSetor)
        if !pos
            pos := RegExMatch(loose, "receb[a-z0-9]*", &mSetor)
        if pos {
            trecho := SubStr(loose, pos)
            contaPos := InStr(trecho, "conta")
            if !contaPos
                contaPos := InStr(trecho, "canta")
            if contaPos
                trecho := SubStr(trecho, 1, contaPos - 1)
            if RegExMatch(trecho, "\b(\d{1,4})\b", &m)
                candidato := m[1]
        }
    }

    if (candidato = "") {
        ini := InStr(loose, "diferente")
        fim := InStr(loose, "conta")
        if !fim
            fim := InStr(loose, "canta")
        if (ini && fim && fim > ini) {
            trecho := SubStr(loose, ini, fim - ini)
            nums := []
            posNum := 1
            while (posNum := RegExMatch(trecho, "\b\d{1,4}\b", &m, posNum)) {
                nums.Push(m[0])
                posNum += StrLen(m[0])
            }
            if (nums.Length > 0)
                candidato := nums[nums.Length]
        }
    }

    if (candidato = "")
        return ""
    return Protocolar_CorrigirSetorPorContexto(candidato, setorEnvioEsperado, setorAtual, loose)
}

; Só substitui o setor lido pelo setor de envio configurado quando a
; distância é de exatamente 1 dígito (erro plausível de OCR, não um setor
; genuinamente diferente) E o contexto ao redor confirma (menciona o setor
; atual antes de "diferente", mais "setor"/"receb" no texto). Fora dessas
; condições, mantém o valor lido — errar para "não corrigir" é mais seguro
; que corrigir um setor que era, de fato, diferente.
Protocolar_CorrigirSetorPorContexto(candidato, setorEnvioEsperado, setorAtual, loose) {
    candidato := RegExReplace(candidato, "\D")
    if (candidato = "")
        return ""
    esperado := RegExReplace(setorEnvioEsperado, "\D")
    atual := RegExReplace(setorAtual, "\D")
    if (esperado = "" || candidato = esperado)
        return candidato
    if (StrLen(candidato) = StrLen(esperado) && Protocolar_DigitDistance(candidato, esperado) = 1) {
        antesDiferente := loose
        posDif := InStr(loose, "diferente")
        if posDif
            antesDiferente := SubStr(loose, 1, posDif - 1)
        if ((atual = "" || RegExMatch(antesDiferente, "\b" atual "\b")) && InStr(loose, "setor") && InStr(loose, "receb")) {
            MV_Log("Protocolar_CorrigirSetorPorContexto",
                "setor recebido corrigido por contexto/OCR: lido=" candidato " usando setor envio configurado=" esperado, true)
            return esperado
        }
    }
    return candidato
}

Protocolar_DigitDistance(a, b) {
    if (StrLen(a) != StrLen(b))
        return 999
    dist := 0
    Loop StrLen(a) {
        if (SubStr(a, A_Index, 1) != SubStr(b, A_Index, 1))
            dist++
    }
    return dist
}
