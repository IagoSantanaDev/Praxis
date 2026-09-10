; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
;
; Verificação de integridade dos recursos externos do runtime.
; Incluído por main.ahk (EXE compilado) e por cli-check.ahk (dev mode).
;
; Contrato de saída (docs/DISTRIBUTION.md):
;   0  — integridade intacta (ou dev mode: check skipped)
;   70 — recurso ausente ou alterado (EXIT_FAILURE estendido)
;
; Pré-requisitos de parse-time (feitos pelos callers):
;   #Include lib\app\AppState.ahk                     (declara gIntegrityExpectedFiles)
;   #Include *i build\generated\Praxis_IntegrityManifest.ahk  (reatribui o Map com hashes reais)

LogWrite(msg) {
    logDir := A_MyDocuments "\Praxis"
    if !DirExist(logDir)
        DirCreate logDir

    logPath := logDir "\praxis-integrity.log"
    FileAppend msg "`n", logPath
}

IntegrityDoCheck() {
    global gIntegrityExpectedFiles
    if !A_IsCompiled {
        LogWrite("[INTEGRITY] dev-mode: check skipped")
        return
    }
    if !(gIntegrityExpectedFiles is Map) || gIntegrityExpectedFiles.Count = 0 {
        LogWrite("[INTEGRITY] manifest missing — FAIL")
        ExitApp 70
    }
    failures := []
    for relativePath, expectedHash in gIntegrityExpectedFiles {
        ; Skip manifest metadata entries — these are not file paths
        if (relativePath = "fileCount" || relativePath = "manifestVersion")
            continue
        normalizedPath := StrReplace(relativePath, "/", "\")
        fullPath := A_ScriptDir "\" normalizedPath
        if !FileExist(fullPath) {
            failures.Push(relativePath " absent")
            continue
        }
        ; tempFile declarado FORA do try e cleanup em finally: garante
        ; FileDelete mesmo se FileRead/StrSplit/RegExMatch lancarem (H2).
        ; A_Index no nome evita colisao quando varios arquivos sao processados.
        tempFile := A_Temp "\praxis_integrity_" A_TickCount "_" A_Index ".tmp"
        try {
            cmd := A_ComSpec " /C certutil -hashfile " Chr(34) fullPath Chr(34) " SHA256 > " Chr(34) tempFile Chr(34) " 2>&1"
            RunWait cmd, , "Hide"
            content := FileRead(tempFile, "UTF-8")
            ; fileMatched rastreia se uma linha SHA256 valida foi encontrada.
            ; Sem isso, certutil que falha silenciosamente (exit 0 sem output,
            ; antivirus bloqueando, arquivo em uso) passa o for sem break nem
            ; push — arquivo e reportado como OK sem ter sido verificado.
            fileMatched := false
            for line in StrSplit(content, "`n", "`r") {
                candidate := RegExReplace(Trim(line), "\s", "")
                if RegExMatch(candidate, "i)^[0-9a-f]{64}$") {
                    fileMatched := true
                    if StrLower(candidate) != StrLower(expectedHash)
                        failures.Push(relativePath " modified")
                    break
                }
            }
            if !fileMatched
                failures.Push(relativePath " hash-extract-failed")
        } catch as e {
            ; Catch local (auditoria 2026-06-27): garante que falha de FileRead em
            ; UM arquivo nao aborta o `for` inteiro. Relatorio de integridade deve
            ; listar TODOS os arquivos com problema, nao so o primeiro.
            failures.Push(relativePath " read-failed: " e.Message)
        } finally {
            try FileDelete tempFile
        }
    }
    if failures.Length > 0 {
        msg := "Integrity FAIL: - " _Join(failures, " - ")
        LogWrite("[INTEGRITY] " msg)
        ExitApp 70
    }
    LogWrite("[INTEGRITY] all files OK")
}

_Join(items, sep) {
    out := ""
    for i, v in items
        out .= (i > 1 ? sep : "") v
    return out
}