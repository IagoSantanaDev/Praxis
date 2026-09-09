; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug

; ════════════════════════════════════════════════════════════════
;  MV PARSE UTILS — helpers de parsing compartilhados
; ════════════════════════════════════════════════════════════════
; Fonte única para parsing de listas CSV simples. Consolidado de
; Protocolar_ParseRemessas (ProtocolarParsers.ahk) e ParseProtocolos
; (RPParsers.ahk), que eram cópias idênticas (2026-09-09).

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