<#
Praxis — software proprietário
Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

Gera test_macros/ocr_error_references.json com os textos PT-BR canônicos dos crops em images/.
As imagens continuam sendo a fonte visual de validação, mas o JSON NÃO deve depender do OCR en-US,
porque acentos em português ficam corrompidos quando o pacote OCR pt-BR não está instalado.
#>

[CmdletBinding()]
param(
    [string]$Root = '',
    [string]$OutputPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-NormalizedOcrText {
    param([string]$Text)

    if ($null -eq $Text) { return '' }
    $value = $Text.ToLowerInvariant().Normalize([Text.NormalizationForm]::FormD)
    $builder = New-Object System.Text.StringBuilder
    foreach ($char in $value.ToCharArray()) {
        $category = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($char)
        if ($category -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$builder.Append($char)
        }
    }
    $value = $builder.ToString().Normalize([Text.NormalizationForm]::FormC)
    $value = [regex]::Replace($value, '[^a-z0-9]+', ' ')
    $value = [regex]::Replace($value, '\s+', ' ').Trim()
    return $value
}

if ($Root -eq '') {
    $Root = Split-Path -Parent $PSScriptRoot
}
$Root = [System.IO.Path]::GetFullPath($Root)

if ($OutputPath -eq '') {
    $OutputPath = Join-Path $Root 'test_macros\ocr_error_references.json'
}
$OutputPath = [System.IO.Path]::GetFullPath($OutputPath)

$templates = @(
    [ordered]@{
        tipo = 'conta_ja_digitada'
        descricao = 'Conta já digitada / redigite'
        sourceFile = 'Erro_Conta_Ja_Digitada_Texto.png'
        text = 'Atenção: Esta Conta já foi digitada, redigite !'
        lineCount = 1
    },
    [ordered]@{
        tipo = 'conta_aberta'
        descricao = 'Conta aberta'
        sourceFile = 'Erro_Conta_Aberta_Texto.png'
        text = 'Atenção: Existem ítens abertos na conta informada, abra a conta, feche e depois tente novamente'
        lineCount = 2
    },
    [ordered]@{
        tipo = 'conta_em_remessa'
        descricao = 'Conta já em remessa'
        sourceFile = 'Erro_Conta_Ja_Em_Remessa_Texto.png'
        text = 'Atenção: Esta Conta não existe, não possui conta Fechada ou possui mais de um Atendimento. Utilize a Lista'
        lineCount = 3
    },
    [ordered]@{
        tipo = 'agrupamento_diferente'
        descricao = 'Agrupamento de conta diferente'
        sourceFile = 'Erro_Conta_De_Agrupamento_Diferente_Texto.png'
        text = 'Atenção: Agrupamento da Conta diferente do Agrupamento da Remessa.Operação Não Realizada'
        lineCount = 2
    },
    [ordered]@{
        tipo = 'conta_tipo_diferente'
        descricao = 'Conta de tipo diferente'
        sourceFile = 'Erro_Conta_De_Tipo_Diferente_Texto.png'
        text = 'Atenção: Esta Conta Não Existe para o Filtro Selecionado!'
        lineCount = 1
    }
)

$references = @()
foreach ($template in $templates) {
    $imagePath = Join-Path $Root (Join-Path 'images' $template.sourceFile)
    $exists = Test-Path -LiteralPath $imagePath
    $text = [string]$template.text

    $references += [ordered]@{
        tipo = $template.tipo
        descricao = $template.descricao
        sourceFile = $template.sourceFile
        text = $text
        normalizedText = ConvertTo-NormalizedOcrText $text
        ok = $exists
        error = if ($exists) { '' } else { "Imagem não encontrada: $imagePath" }
        language = 'pt-BR'
        fallbackUsed = $false
        lineCount = [int]$template.lineCount
        charCount = $text.Length
    }
}

$payload = [ordered]@{
    generatedAt = (Get-Date).ToString('o')
    generator = 'tools/build-ocr-error-references.ps1'
    sourceDir = 'images'
    languageRequested = 'pt-BR'
    referenceMode = 'canonical-pt-br'
    references = $references
}

$outDir = Split-Path -Parent $OutputPath
if ($outDir -ne '' -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$payload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Host "Referências PT-BR gravadas em: $OutputPath"
Write-Host "Itens: $($references.Count)"
