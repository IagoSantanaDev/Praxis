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
    header := Protocolar_SplitSemicolonCsvLine(lines[1])
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

        columns := Protocolar_SplitSemicolonCsvLine(line)
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

Protocolar_SplitSemicolonCsvLine(line) {
    return MV_SplitSemicolonCsvLine(line)
}

; ════════════════════════════════════════════════════════════════
;  PROTOCOLAR PARSERS
;  Lógica de parsing para o módulo Protocolar
; ════════════════════════════════════════════════════════════════

; Protocolar_ParseRemessas delega para a canônica ParseListaCsv (globals/mv/ParseUtils.ahk).
Protocolar_ParseRemessas(str) {
    return ParseListaCsv(str)
}

Protocolar_Abort(msg) {
    ; Delega para a canônica MV_Abort (MVSession.ahk) preservando o
    ; comportamento original (status "Execução finalizada.").
    return MV_Abort(msg, true)
}
