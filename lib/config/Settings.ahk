#Requires AutoHotkey v2.0
#Warn All, OutputDebug
; ============================================================
; Praxis Settings Configuration
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.
; ============================================================

; ─── Settings reader/writer ────────────────────────────────────
; Wrapper centralizado para IniRead/IniWrite sobre config.ini.
; Garante tipagem consistente e fallbacks corretos em toda a codebase.
;
; Config_ReadSetting  — lê um valor; retorna defaultValue se a chave não existir.
; Config_WriteSetting — escreve um valor; atualiza o cache local.
;
; O arquivo de configuração (config.ini) reside no mesmo diretório do script.
; ============================================================

; Cache estático para Config_ReadSetting: [section "|" key] -> value
; Evita múltiplas leituras de config.ini durante a execução.
global gSettingsCache := Map()

; ─── Lê uma configuração de config.ini ─────────────────────────
; Parâmetros:
;   section     - seção do config.ini
;   key         - chave dentro da seção
;   defaultValue- valor retornado se section/key não existir
;
; Retorna:
;   String com o valor lido ou defaultValue.
; ============================================================
Config_ReadSetting(section, key, defaultValue) {
    global gSettingsCache
    cacheKey := section "|" key

    ; Busca no cache estático primeiro
    if gSettingsCache.Has(cacheKey)
        return gSettingsCache[cacheKey]

    iniPath := A_ScriptDir "\config.ini"
    value := IniRead(iniPath, section, key, defaultValue)

    ; Armazena no cache (inclusive o default para próximas leituras)
    gSettingsCache[cacheKey] := value
    return value
}

; ─── Escreve uma configuração em config.ini ────────────────────
; Parâmetros:
;   section - seção do config.ini
;   key     - chave dentro da seção
;   value   - valor a gravar
;
; Retorna:
;   Nada. Lança Error se a escrita falhar.
; ============================================================
Config_WriteSetting(section, key, value) {
    global gSettingsCache
    iniPath := A_ScriptDir "\config.ini"
    IniWrite(value, iniPath, section, key)

    ; Atualiza o cache para manter consistência com o arquivo
    cacheKey := section "|" key
    gSettingsCache[cacheKey] := value
}
