; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug
#Include ..\..\..\lib\globals\mv\MVSession.ahk
#Include ..\..\..\lib\globals\mv\FFCV_ErrorTemplates.ahk

; ════════════════════════════════════════════════════════════════
;  REMESSA POR PROTOCOLO — parsers
; ════════════════════════════════════════════════════════════════

RP_RecordTiming(timings, label, startedAt, extra := "") {
    elapsedMs := A_TickCount - startedAt
    timings.Push(Map("label", label, "ms", elapsedMs, "extra", extra))
    Notify("⏱ " label ": " RP_FormatDuration(elapsedMs) (extra != "" ? " | " extra : ""))
    return elapsedMs
}

ParseProtocolos(str) {
    result := []
    for _, p in StrSplit(str, ",") {
        p := Trim(p)
        if (p != "")
            result.Push(p)
    }
    return result
}

ContarContas(protocolContas) {
    total := 0
    for _, contas in protocolContas
        total += contas.Length
    return total
}

RP_ConvenioMajoritario(linhas) {
    counts := Map()
    ordem := []

    for _, linha in linhas {
        convenio := linha["convenio"]
        if !counts.Has(convenio) {
            counts[convenio] := 0
            ordem.Push(convenio)
        }
        counts[convenio] += 1
    }

    escolhido := ""
    maior := 0
    for _, convenio in ordem {
        if (counts[convenio] > maior) {
            maior := counts[convenio]
            escolhido := convenio
        }
    }
    return escolhido
}

RP_FiltrarContasPorConvenio(linhas, convenioEscolhido, erros) {
    protocolContas := Map()

    for _, linha in linhas {
        protocolo := linha["protocolo"]
        conta := linha["conta"]
        convenio := linha["convenio"]

        if (convenio != convenioEscolhido) {
            erros.Push(Map("protocolo", protocolo, "conta", conta, "descricao", "Convênio diferente: " convenio))
            continue
        }

        if !protocolContas.Has(protocolo)
            protocolContas[protocolo] := []
        protocolContas[protocolo].Push(Map("conta", conta, "convenio", convenio))
    }

    return protocolContas
}

RP_FormatDuration(ms) {
    if (ms < 1000)
        return ms "ms"

    totalSecs := Round(ms / 1000, 1)
    if (totalSecs < 60)
        return totalSecs "s"

    mins := Floor(totalSecs / 60)
    secs := Round(Mod(totalSecs, 60), 1)
    return mins "min " secs "s"
}

RP_FormatTimingReport(timings) {
    report := "⏱ Tempos da execução:`n"
    for _, item in timings {
        extra := item["extra"] != "" ? " | " item["extra"] : ""
        report .= "  - " item["label"] ": " RP_FormatDuration(item["ms"]) extra "`n"
    }
    return report
}
