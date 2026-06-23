; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug

global gEmbeddedOcrReferencesBase64 := ""
global gEmbeddedOcrProbeBase64 := ""
#Include *i ..\..\..\build\generated\Praxis_OcrReferences.ahk
#Include *i ..\..\..\build\generated\Praxis_OcrProbe.ahk

; Cadastro compartilhado de erros do FFCV Inserir Conta por OCR.
;
; Como adicionar novo erro:
; 1) Deixe o modal Forms aberto no MV.
; 2) Faça um crop APENAS da frase do erro e salve em:
;      images\Nome_Do_Erro_Texto.png
; 3) Adicione o texto canônico em tools\build-ocr-error-references.ps1.
; 4) Rode tools\build-ocr-error-references.ps1 para atualizar globals\mv\FFCV_ErrorReferences.json.
; 5) Rode o teste OCR contra images\ e depois test_macros\14_ocr_probe.ahk com o modal real aberto.
;
; Observação: WinGetText/Window Spy normalmente expõem só &OK nesses modais.
; O contrato confiável é OCR local do Windows na área client da janela modal.

FFCV_OCR_LANGUAGE := "pt-BR"
FFCV_OCR_SCALE := 2
FFCV_OCR_MATCH_THRESHOLD := 0.35

DirGetParent(dir) {
    local parentDir
    SplitPath dir, , &parentDir
    return parentDir
}

FFCV_ErrorTemplates_ProjectRoot() {
    ; Procura config.ini na raiz do projeto como marcador.
    ; Sobe no máximo 4 níveis acima do script para encontrar a raiz.
    dir := A_ScriptDir
    loop 4 {
        if FileExist(dir "\config.ini")
            return dir
        parent := DirGetParent(dir)
        if (parent = dir)
            break ; reached filesystem root
        dir := parent
    }
    ; Fallback: retorna o diretório pai mais provável (1 nível acima de globals/ ou lib/)
    return DirGetParent(A_ScriptDir)
}

FFCV_ErrorReferencesPath() {
    return FFCV_ErrorTemplates_ProjectRoot() "\lib\globals\mv\FFCV_ErrorReferences.json"
}

FFCV_OcrProbeScriptPath() {
    return FFCV_ErrorTemplates_ProjectRoot() "\tools\ocr-probe.ps1"
}

FFCV_LoadErrorReferences() {
    static cached := ""
    if IsObject(cached)
        return cached

    global gEmbeddedOcrReferencesBase64

    path := FFCV_ErrorReferencesPath()
    raw := ""
    sourceLabel := path

    if (A_IsCompiled && Trim(gEmbeddedOcrReferencesBase64) != "") {
        raw := Base64DecodeUtf8(gEmbeddedOcrReferencesBase64)
        sourceLabel := "embedded:FFCV_ErrorReferences.json"
    } else {
        if !FileExist(path) {
            cached := Map("ok", false, "error", "arquivo de referências OCR não encontrado: " path, "items", [])
            return cached
        }

        try raw := FileRead(path, "UTF-8")
        catch as e {
            cached := Map("ok", false, "error", "falha ao ler referências OCR: " e.Message, "items", [], "path", sourceLabel)
            return cached
        }
    }

    try {
        raw := RegExReplace(raw, "^\x{FEFF}")
        parsed := JSON.parse(raw)
        items := []
        if parsed.Has("references") {
            for _, ref in parsed["references"] {
                if ref.Get("ok", false)
                    items.Push(ref)
            }
        }
        if (items.Length = 0) {
            cached := Map("ok", false, "error", "nenhuma referência OCR válida em: " sourceLabel, "items", [])
            return cached
        }
        cached := Map(
            "ok", true,
            "error", "",
            "items", items,
            "generatedAt", parsed.Get("generatedAt", ""),
            "sourceDir", parsed.Get("sourceDir", ""),
            "path", sourceLabel
        )
        return cached
    } catch as e {
        cached := Map("ok", false, "error", "falha ao processar referências OCR: " e.Message, "items", [], "path", sourceLabel)
        return cached
    }
}

FFCV_ClassifyErrorModal(winTitle := MV_CLASS_MODAL_FORMS, variation := 50) {
    global FFCV_OCR_LANGUAGE, FFCV_OCR_MATCH_THRESHOLD
    ; variation é mantido apenas por compatibilidade com chamadas antigas.
    _ := variation

    references := FFCV_LoadErrorReferences()
    if !references["ok"]
        return FFCV_UnknownOcrResult("referências OCR indisponíveis: " references["error"])

    region := FFCV_ResolveOcrRegion(winTitle)
    if !region["ok"]
        return FFCV_UnknownOcrResult("região OCR indisponível: " region["error"])

    popupOcr := FFCV_RunOcrScreen(region["x"], region["y"], region["w"], region["h"], FFCV_OCR_LANGUAGE)
    if !popupOcr["ok"]
        return FFCV_UnknownOcrResult("OCR falhou: " popupOcr.Get("error", "erro não informado"), popupOcr.Get("fullText", ""))

    popupText := popupOcr.Get("fullText", "")
    if (Trim(popupText) = "")
        return FFCV_UnknownOcrResult("OCR executou, mas não leu texto no modal", popupText, popupOcr)

    classification := FFCV_ClassifyTextByReferences(popupText, references["items"])
    best := classification["best"]
    if (!best.Has("tipo") || best["score"] < FFCV_OCR_MATCH_THRESHOLD) {
        scoreText := best.Has("score") ? Format("{1:.2f}", best["score"]) : "sem score"
        return FFCV_UnknownOcrResult("OCR sem referência suficiente: score=" scoreText " threshold=" FFCV_OCR_MATCH_THRESHOLD, popupText, popupOcr)
    }

    root := FFCV_ErrorTemplates_ProjectRoot()
    sourceFile := best.Get("sourceFile", "")
    imagePath := sourceFile != "" ? root "\images\" sourceFile : ""
    return Map(
        "tipo", best["tipo"],
        "descricao", best["descricao"],
        "fonte", "ocr Windows.Media.Ocr",
        "texto", popupText,
        "img", imagePath,
        "score", best["score"],
        "ocrLanguage", popupOcr.Get("language", ""),
        "ocrRequestedLanguage", popupOcr.Get("requestedLanguage", ""),
        "ocrFallbackUsed", popupOcr.Get("fallbackUsed", false),
        "ocrLineCount", popupOcr.Get("lineCount", 0),
        "ocrRegion", region
    )
}

FFCV_UnknownOcrResult(reason, text := "", ocrPayload := "") {
    result := Map(
        "tipo", "erro_desconhecido",
        "descricao", "Erro modal não classificado",
        "fonte", reason,
        "texto", text,
        "img", ""
    )
    if IsObject(ocrPayload) {
        result["ocrLanguage"] := ocrPayload.Get("language", "")
        result["ocrRequestedLanguage"] := ocrPayload.Get("requestedLanguage", "")
        result["ocrFallbackUsed"] := ocrPayload.Get("fallbackUsed", false)
        result["ocrLineCount"] := ocrPayload.Get("lineCount", 0)
    }
    return result
}

FFCV_ResolveOcrRegion(winTitle) {
    if !WinExist(winTitle)
        return Map("ok", false, "error", "modal Forms não encontrado: " winTitle)

    try WinGetClientPos &cx, &cy, &cw, &ch, winTitle
    catch as e
        return Map("ok", false, "error", "WinGetClientPos falhou: " e.Message)

    if (cw <= 0 || ch <= 0)
        return Map("ok", false, "error", "área client vazia: w=" cw " h=" ch)

    return Map("ok", true, "x", Round(cx), "y", Round(cy), "w", Round(cw), "h", Round(ch))
}

FFCV_RunOcrScreen(x, y, w, h, language) {
    global FFCV_OCR_SCALE
    args := " -X " x " -Y " y " -Width " w " -Height " h " -Scale " FFCV_OCR_SCALE
    return FFCV_RunOcrProbe(args, language)
}

FFCV_RunOcrProbe(arguments, language) {
    global gEmbeddedOcrProbeBase64

    jsonPath := A_Temp "\praxis_ffcv_ocr_" A_TickCount "_" Random(1000, 9999) ".json"
    tempScriptPath := ""

    if (A_IsCompiled && Trim(gEmbeddedOcrProbeBase64) != "") {
        tempScriptPath := A_Temp "\praxis_ffcv_ocr_" A_TickCount "_" Random(1000, 9999) ".ps1"
        try {
            decodedScript := Base64DecodeUtf8(gEmbeddedOcrProbeBase64)
            try FileDelete tempScriptPath
            FileAppend(decodedScript, tempScriptPath, "UTF-8")
            command := "powershell.exe -NoProfile -ExecutionPolicy Bypass -File " FFCV_Quote(tempScriptPath)
                . arguments
                . " -OutputJsonPath " FFCV_Quote(jsonPath)
        } catch as e {
            try FileDelete tempScriptPath
            return Map("ok", false, "error", "Falha ao preparar OCR embutido: " e.Message)
        }
    } else {
        psScript := FFCV_OcrProbeScriptPath()
        if !FileExist(psScript)
            return Map("ok", false, "error", "Script OCR não encontrado: " psScript)

        command := "powershell.exe -NoProfile -ExecutionPolicy Bypass -File " FFCV_Quote(psScript)
            . arguments
            . " -OutputJsonPath " FFCV_Quote(jsonPath)
    }

    if (language != "")
        command .= " -Language " FFCV_Quote(language)

    try {
        exitCode := RunWait(command, , "Hide")
    } catch as e {
        return Map("ok", false, "error", "Falha ao iniciar OCR: " e.Message)
    } finally {
        if (tempScriptPath != "") {
            try FileDelete tempScriptPath
        }
    }

    if !FileExist(jsonPath)
        return Map("ok", false, "error", "OCR não gerou JSON. ExitCode=" exitCode)

    try {
        raw := FileRead(jsonPath, "UTF-8")
        parsed := JSON.parse(raw)
        if !parsed.Has("ok")
            parsed["ok"] := false
        if (exitCode != 0 && parsed.Get("error", "") = "")
            parsed["error"] := "PowerShell retornou exitCode=" exitCode
        return parsed
    } catch as e {
        return Map("ok", false, "error", "Falha ao ler JSON OCR: " e.Message)
    } finally {
        try FileDelete jsonPath
    }
}

FFCV_ClassifyTextByReferences(popupText, refs) {
    results := []
    best := Map()
    bestScore := -1

    for _, ref in refs {
        refText := ref.Get("text", "")
        score := FFCV_OcrSimilarityScore(popupText, refText)
        item := Map(
            "tipo", ref.Get("tipo", ""),
            "descricao", ref.Get("descricao", ""),
            "sourceFile", ref.Get("sourceFile", ""),
            "refText", refText,
            "score", score
        )
        results.Push(item)

        if (score > bestScore) {
            bestScore := score
            best := item
        }
    }

    FFCV_SortResultsByScoreDesc(results)
    return Map("best", best, "results", results)
}

FFCV_OcrSimilarityScore(leftText, rightText) {
    leftTokens := FFCV_TokenSet(leftText)
    rightTokens := FFCV_TokenSet(rightText)
    if (rightTokens.Count = 0)
        return 0.0

    hits := 0
    for token, _ in rightTokens {
        if leftTokens.Has(token)
            hits++
    }
    return hits / rightTokens.Count
}

FFCV_TokenSet(text) {
    normalized := FFCV_NormalizeOcrText(text)
    tokens := Map()
    for _, token in StrSplit(normalized, " ") {
        token := Trim(token)
        if (StrLen(token) < 3)
            continue
        if FFCV_IsStopWord(token)
            continue
        tokens[token] := true
    }
    return tokens
}

FFCV_NormalizeOcrText(text) {
    text := StrLower(text)
    replacements := Map(
        "á", "a", "à", "a", "â", "a", "ã", "a", "ä", "a",
        "é", "e", "ê", "e", "è", "e", "ë", "e",
        "í", "i", "ì", "i", "î", "i", "ï", "i",
        "ó", "o", "ò", "o", "ô", "o", "õ", "o", "ö", "o",
        "ú", "u", "ù", "u", "û", "u", "ü", "u",
        "ç", "c"
    )
    for from, to in replacements
        text := StrReplace(text, from, to)
    text := RegExReplace(text, "[^a-z0-9]+", " ")
    text := RegExReplace(text, "\s+", " ")
    return Trim(text)
}

FFCV_IsStopWord(token) {
    static words := Map(
        "para", true, "por", true, "com", true, "uma", true, "das", true,
        "dos", true, "que", true, "esta", true, "este", true, "sera", true,
        "ser", true, "foi", true, "nao", true, "sim", true, "ok", true,
        "deve", true, "devera", true, "favor", true
    )
    return words.Has(token)
}

FFCV_SortResultsByScoreDesc(results) {
    Loop results.Length {
        i := A_Index
        Loop results.Length - i {
            j := A_Index
            if (results[j]["score"] < results[j + 1]["score"]) {
                tmp := results[j]
                results[j] := results[j + 1]
                results[j + 1] := tmp
            }
        }
    }
}

FFCV_Quote(value) {
    return Chr(34) StrReplace(value, Chr(34), Chr(34) Chr(34)) Chr(34)
}

FFCV_SafeWinGetText(winTitle) {
    try text := WinGetText(winTitle)
    catch as e
        return "<erro WinGetText: " e.Message ">"

    text := Trim(text)
    if (text = "" || text = "&OK" || text = "&Sim`r`n&Não" || text = "&Não`r`n&Sim")
        return text "`n<observação: Oracle Forms pode desenhar a mensagem em ui60Drawn; WinGetText pode expor só botões.>"
    return text
}
