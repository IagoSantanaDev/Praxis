<#
Praxis — software proprietário
Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

Captura uma região da tela e executa OCR usando Windows.Media.Ocr.
Este script é usado por test_macros/14_ocr_probe.ahk e pelo macro principal para classificar erros via OCR.
#>

[CmdletBinding()]
param(
    [int]$X = 0,
    [int]$Y = 0,
    [int]$Width = 0,
    [int]$Height = 0,
    [string]$ImagePath = '',
    [int]$Scale = 2,
    [string]$Language = '',
    [string]$ScreenshotPath = '',
    [string]$OutputJsonPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-ResultJson {
    param([hashtable]$Payload)

    $Payload.timestamp = (Get-Date).ToString('o')
    $json = $Payload | ConvertTo-Json -Depth 8

    if ($OutputJsonPath -ne '') {
        $dir = Split-Path -Parent $OutputJsonPath
        if ($dir -ne '' -and -not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        Set-Content -LiteralPath $OutputJsonPath -Value $json -Encoding UTF8
    }

    $json
}

function Await-AsyncOperation {
    param(
        [Parameter(Mandatory = $true)]$AsyncOperation,
        [Parameter(Mandatory = $true)][type]$ResultType
    )

    $asTaskMethod = [System.WindowsRuntimeSystemExtensions].GetMethods() |
        Where-Object {
            $_.Name -eq 'AsTask' -and
            $_.IsGenericMethodDefinition -and
            $_.GetParameters().Count -eq 1 -and
            $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
        } |
        Select-Object -First 1

    if ($null -eq $asTaskMethod) {
        throw 'Não encontrei System.WindowsRuntimeSystemExtensions.AsTask<T>(IAsyncOperation<T>).'
    }

    $task = $asTaskMethod.MakeGenericMethod($ResultType).Invoke($null, @($AsyncOperation))
    try {
        $task.Wait()
    } catch [System.AggregateException] {
        $innerMessages = @($_.Exception.InnerExceptions | ForEach-Object { $_.Message })
        throw ($innerMessages -join ' | ')
    }
    return $task.Result
}

function Convert-OcrLines {
    param($OcrResult)

    $lines = @()
    foreach ($line in $OcrResult.Lines) {
        $words = @()
        foreach ($word in $line.Words) {
            $words += [ordered]@{
                text = $word.Text
                x = [math]::Round($word.BoundingRect.X, 2)
                y = [math]::Round($word.BoundingRect.Y, 2)
                width = [math]::Round($word.BoundingRect.Width, 2)
                height = [math]::Round($word.BoundingRect.Height, 2)
            }
        }
        $lines += [ordered]@{
            text = $line.Text
            words = $words
        }
    }
    return $lines
}

try {
    $usingExistingImage = $ImagePath -ne ''
    $inputImagePath = ''

    $createdScreenshotPath = $false
    if ($usingExistingImage) {
        $inputImagePath = [System.IO.Path]::GetFullPath($ImagePath)
        if (-not (Test-Path -LiteralPath $inputImagePath)) {
            throw "Imagem OCR não encontrada: $inputImagePath"
        }
    } elseif ($Width -le 0 -or $Height -le 0) {
        throw "Região inválida: Width=$Width Height=$Height."
    }

    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName System.Runtime.WindowsRuntime

    [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime] | Out-Null
    [Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics.Imaging, ContentType = WindowsRuntime] | Out-Null
    [Windows.Graphics.Imaging.SoftwareBitmap, Windows.Graphics.Imaging, ContentType = WindowsRuntime] | Out-Null
    [Windows.Graphics.Imaging.BitmapPixelFormat, Windows.Graphics.Imaging, ContentType = WindowsRuntime] | Out-Null
    [Windows.Graphics.Imaging.BitmapAlphaMode, Windows.Graphics.Imaging, ContentType = WindowsRuntime] | Out-Null
    [Windows.Media.Ocr.OcrEngine, Windows.Media.Ocr, ContentType = WindowsRuntime] | Out-Null
    [Windows.Globalization.Language, Windows.Globalization, ContentType = WindowsRuntime] | Out-Null

    $requestedLanguage = $Language
    $fallbackUsed = $false
    $availableLanguages = @([Windows.Media.Ocr.OcrEngine]::AvailableRecognizerLanguages | ForEach-Object { $_.LanguageTag })

    if ($Language -ne '') {
        $languageObject = [Windows.Globalization.Language]::new($Language)
        $ocrEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($languageObject)
    } else {
        $ocrEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
    }

    if ($null -eq $ocrEngine -and $availableLanguages.Count -gt 0) {
        $fallbackUsed = $true
        $fallbackLanguageObject = [Windows.Globalization.Language]::new($availableLanguages[0])
        $ocrEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($fallbackLanguageObject)
    }

    if ($null -eq $ocrEngine) {
        Write-ResultJson @{
            ok = $false
            error = 'Nenhum mecanismo OCR disponível para o idioma solicitado/perfil do usuário.'
            requestedLanguage = $requestedLanguage
            availableLanguages = $availableLanguages
            region = @{ x = $X; y = $Y; width = $Width; height = $Height }
        }
        exit 2
    }

    if ($usingExistingImage) {
        $ScreenshotPath = $inputImagePath
    } else {
        if ($ScreenshotPath -eq '') {
            $ScreenshotPath = Join-Path $env:TEMP ('praxis-ocr-' + [guid]::NewGuid().ToString('N') + '.png')
            $createdScreenshotPath = $true
        }
        $ScreenshotPath = [System.IO.Path]::GetFullPath($ScreenshotPath)

        $screenshotDir = Split-Path -Parent $ScreenshotPath
        if ($screenshotDir -ne '' -and -not (Test-Path -LiteralPath $screenshotDir)) {
            New-Item -ItemType Directory -Path $screenshotDir -Force | Out-Null
        }

        $bitmap = New-Object System.Drawing.Bitmap $Width, $Height
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.CopyFromScreen($X, $Y, 0, 0, $bitmap.Size)
            $bitmap.Save($ScreenshotPath, [System.Drawing.Imaging.ImageFormat]::Png)
        } finally {
            $graphics.Dispose()
            $bitmap.Dispose()
        }
    }

    $ocrInputPath = $ScreenshotPath
    $processedImagePath = ''
    if ($Scale -gt 1) {
        $processedImagePath = Join-Path $env:TEMP ('praxis-ocr-scaled-' + [guid]::NewGuid().ToString('N') + '.png')
        $sourceBitmap = [System.Drawing.Bitmap]::FromFile($ScreenshotPath)
        try {
            $scaledWidth = [Math]::Max(1, [int]($sourceBitmap.Width * $Scale))
            $scaledHeight = [Math]::Max(1, [int]($sourceBitmap.Height * $Scale))
            $scaledBitmap = New-Object System.Drawing.Bitmap $scaledWidth, $scaledHeight
            $scaledGraphics = [System.Drawing.Graphics]::FromImage($scaledBitmap)
            try {
                $scaledGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
                $scaledGraphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
                $scaledGraphics.DrawImage($sourceBitmap, 0, 0, $scaledWidth, $scaledHeight)
                $scaledBitmap.Save($processedImagePath, [System.Drawing.Imaging.ImageFormat]::Png)
            } finally {
                $scaledGraphics.Dispose()
                $scaledBitmap.Dispose()
            }
        } finally {
            $sourceBitmap.Dispose()
        }
        $ocrInputPath = $processedImagePath
    }

    $storageFile = Await-AsyncOperation ([Windows.Storage.StorageFile]::GetFileFromPathAsync($ocrInputPath)) ([Windows.Storage.StorageFile])
    $stream = Await-AsyncOperation ($storageFile.OpenReadAsync()) ([Windows.Storage.Streams.IRandomAccessStreamWithContentType])
    try {
        $decoder = Await-AsyncOperation ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
        $softwareBitmap = Await-AsyncOperation ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])

        if ($softwareBitmap.BitmapPixelFormat -ne [Windows.Graphics.Imaging.BitmapPixelFormat]::Bgra8) {
            $convertedBitmap = [Windows.Graphics.Imaging.SoftwareBitmap]::Convert(
                $softwareBitmap,
                [Windows.Graphics.Imaging.BitmapPixelFormat]::Bgra8,
                [Windows.Graphics.Imaging.BitmapAlphaMode]::Premultiplied
            )
            $softwareBitmap.Dispose()
            $softwareBitmap = $convertedBitmap
        }

        try {
            $ocrResult = Await-AsyncOperation ($ocrEngine.RecognizeAsync($softwareBitmap)) ([Windows.Media.Ocr.OcrResult])
            $lines = Convert-OcrLines $ocrResult
            Write-ResultJson @{
                ok = $true
                error = ''
                language = $ocrEngine.RecognizerLanguage.LanguageTag
                requestedLanguage = $requestedLanguage
                availableLanguages = $availableLanguages
                fallbackUsed = $fallbackUsed
                textAngle = $ocrResult.TextAngle
                fullText = $ocrResult.Text
                lines = $lines
                lineCount = @($lines).Count
                screenshotPath = $ScreenshotPath
                ocrInputPath = $ocrInputPath
                scale = $Scale
                imagePath = if ($usingExistingImage) { $inputImagePath } else { '' }
                source = if ($usingExistingImage) { 'image' } else { 'screen' }
                region = @{ x = $X; y = $Y; width = $Width; height = $Height }
            }
        } finally {
            $softwareBitmap.Dispose()
        }
    } finally {
        if ($null -ne $stream) {
            $stream.Dispose()
        }
        if ($processedImagePath -ne '' -and (Test-Path -LiteralPath $processedImagePath)) {
            Remove-Item -LiteralPath $processedImagePath -Force -ErrorAction SilentlyContinue
        }
        if ($createdScreenshotPath -and (Test-Path -LiteralPath $ScreenshotPath)) {
            Remove-Item -LiteralPath $ScreenshotPath -Force -ErrorAction SilentlyContinue
        }
    }
} catch {
    Write-ResultJson @{
        ok = $false
        error = $_.Exception.Message
        imagePath = $ImagePath
        region = @{ x = $X; y = $Y; width = $Width; height = $Height }
    }
    exit 1
}
