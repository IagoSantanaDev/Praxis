; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug

; ════════════════════════════════════════════════════════════════
;  STRING UTILS — primitivas de string reutilizadas por mais de um módulo
; ════════════════════════════════════════════════════════════════
; Home canônica para helpers de string sem regra de negócio própria,
; conforme a área "globals/shared" já prevista em docs/README (LEGO:
; primitivas pequenas antes de blocos estruturais/fluxos específicos).

; ParseCsvList: separa uma string por vírgula, remove espaços de cada item
; e descarta itens vazios. Extraída em 2026-09 de duas cópias idênticas
; (RPParsers.ahk:ParseProtocolos e ProtocolarParsers.ahk:Protocolar_ParseRemessas),
; que a UI alimenta com listas de números de protocolo/remessa digitadas
; pelo usuário separadas por vírgula.
; @return Array de strings, na ordem original, sem itens vazios.
ParseCsvList(str) {
    result := []
    for _, item in StrSplit(str, ",") {
        trimmed := Trim(item)
        if (trimmed != "")
            result.Push(trimmed)
    }
    return result
}
