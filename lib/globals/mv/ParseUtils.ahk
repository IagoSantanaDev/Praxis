; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug

; ════════════════════════════════════════════════════════════════
;  MV PARSE UTILS — helpers de parsing compartilhados
; ════════════════════════════════════════════════════════════════
; Fonte única para parsing de listas CSV simples dos módulos MV.

; Divide uma string separada por vírgula em lista limpa (Trim + descarta vazios).
; Canônica da família de parsers de lista dos módulos MV.
ParseListaCsv(str) {
    result := []
    for _, item in StrSplit(str, ",") {
        item := Trim(item)
        if (item != "")
            result.Push(item)
    }
    return result
}

MV_SplitSemicolonCsvLine(line) {
    fields := []
    current := ""
    quoted := false
    index := 1

    while (index <= StrLen(line)) {
        char := SubStr(line, index, 1)
        if (char = Chr(34)) {
            if (quoted && SubStr(line, index + 1, 1) = Chr(34)) {
                current .= Chr(34)
                index += 2
                continue
            }
            quoted := !quoted
        } else if (char = ";" && !quoted) {
            fields.Push(current)
            current := ""
        } else {
            current .= char
        }
        index += 1
    }

    fields.Push(current)
    return fields
}

MV_JoinArray(items, separator := ", ") {
    result := ""
    for _, item in items
        result .= (result = "" ? "" : separator) item
    return result
}

MV_OptionEnabled(params, key, defaultValue := false) {
    if !params.Has(key) || Trim(String(params[key])) = ""
        return defaultValue

    value := StrLower(Trim(String(params[key])))
    return !(value = "false" || value = "0" || value = "nao" || value = "não")
}