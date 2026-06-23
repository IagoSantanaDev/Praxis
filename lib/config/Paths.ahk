#Requires AutoHotkey v2.0
#Warn All, OutputDebug
; ============================================================
; Praxis Path Configuration
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.
; ============================================================

; ─── Canonical path resolver ──────────────────────────────────
; Retorna paths canônicos da aplicação a partir de um nome simbólico.
; Garante consistência de caminhos em toda a codebase.
;
; Parâmetros:
;   name - Nome simbólico do path:
;          "WorkDir"    -> diretório de trabalho configurado (padrão: A_MyDocuments\Praxis)
;          "VendorDir" -> vendor/
;          "ScriptsDir"-> scripts/
;          "UiDir"     -> ui/
;          "GlobalsDir"-> globals/
;          "ModulesDir"-> modules/
;          "ConfigDir" -> config/
;          "LibDir"    -> lib/
;          "BuildDir"  -> build/
;
; Retorna:
;   String com o path absoluto. Lança Error se name for inválido.
; ============================================================

Config_GetPath(name) {
    static cache := Map()

    ; Cache para evitar múltiplas leituras de config.ini
    if cache.Has(name)
        return cache[name]

    baseDir := A_ScriptDir

    switch name {
        case "WorkDir":
            ; Lê do config.ini configurado pelo installer; fallback para padrão
            path := IniRead(baseDir "\config.ini", "Paths", "WorkDir",
                            A_MyDocuments "\Praxis")
            ; Garante que o diretório existe
            if !InStr(path, ".\") and !FileExist(path) {
                try DirCreate(path)
            }

        case "VendorDir":
            path := baseDir "\lib\vendor"

        case "ScriptsDir":
            path := baseDir "\scripts"

        case "UiDir":
            path := baseDir "\lib\ui"

        case "GlobalsDir":
            path := baseDir "\lib\globals"

        case "ModulesDir":
            path := baseDir "\lib\modules"

        case "ConfigDir":
            path := baseDir "\lib\config"

        case "LibDir":
            path := baseDir "\lib"

        case "BuildDir":
            path := baseDir "\build"

        default:
            throw Error("Config_GetPath: nome desconhecido '" . name . "'", -1)
    }

    cache[name] := path
    return path
}

; ─── Convenience aliases via globals ───────────────────────────
; Para retrocompatibilidade com código que usa gWorkDir diretamente.
; Inicializado sob demanda na primeira chamada.
global gWorkDir := ""
