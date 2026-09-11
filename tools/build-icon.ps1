param(
    [string]$InputPath = (Join-Path $PSScriptRoot '..\assets\icon.ico'),
    [string]$OutputPath = (Join-Path $PSScriptRoot '..\assets\icon.ico')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

function Get-LargestIcoImage {
    param([byte[]]$Bytes)

    $imageCount = [BitConverter]::ToUInt16($Bytes, 4)
    $largestEntry = $null
    for ($index = 0; $index -lt $imageCount; $index++) {
        $entryOffset = 6 + ($index * 16)
        $width = [int]$Bytes[$entryOffset]
        $height = [int]$Bytes[$entryOffset + 1]
        if ($width -eq 0) { $width = 256 }
        if ($height -eq 0) { $height = 256 }
        $entry = [PSCustomObject]@{
            Width = $width
            Height = $height
            Size = [BitConverter]::ToUInt32($Bytes, $entryOffset + 8)
            Offset = [BitConverter]::ToUInt32($Bytes, $entryOffset + 12)
        }
        if ($null -eq $largestEntry -or ($entry.Width * $entry.Height) -gt ($largestEntry.Width * $largestEntry.Height)) {
            $largestEntry = $entry
        }
    }

    $pngBytes = $Bytes[$largestEntry.Offset..($largestEntry.Offset + $largestEntry.Size - 1)]
    $stream = [System.IO.MemoryStream]::new($pngBytes)
    try {
        return [PSCustomObject]@{
            Bitmap = [System.Drawing.Bitmap]::new([System.Drawing.Image]::FromStream($stream))
            Bytes = $pngBytes
        }
    } finally {
        $stream.Dispose()
    }
}

function New-PngBytes {
    param(
        [System.Drawing.Image]$Source,
        [int]$Size
    )

    $bitmap = [System.Drawing.Bitmap]::new($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.DrawImage($Source, 0, 0, $Size, $Size)
    } finally {
        $graphics.Dispose()
    }

    $stream = [System.IO.MemoryStream]::new()
    try {
        $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
        return $stream.ToArray()
    } finally {
        $stream.Dispose()
        $bitmap.Dispose()
    }
}

$sizes = @(16, 20, 24, 32, 40, 48, 64, 128, 256)
$sourceBytes = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $InputPath))
$source = Get-LargestIcoImage -Bytes $sourceBytes
try {
    $images = foreach ($size in $sizes) {
        $pngBytes = if ($size -eq 256) { $source.Bytes } else { New-PngBytes -Source $source.Bitmap -Size $size }
        [PSCustomObject]@{ Size = $size; Bytes = $pngBytes }
    }
} finally {
    $source.Bitmap.Dispose()
}

$directory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Path $directory -Force | Out-Null
$outputStream = [System.IO.FileStream]::new((Resolve-Path -LiteralPath $directory).Path + '\' + (Split-Path -Leaf $OutputPath), [System.IO.FileMode]::Create)
$writer = [System.IO.BinaryWriter]::new($outputStream)
try {
    $writer.Write([UInt16]0)
    $writer.Write([UInt16]1)
    $writer.Write([UInt16]$images.Count)
    $dataOffset = 6 + (16 * $images.Count)
    foreach ($image in $images) {
        $dimension = if ($image.Size -eq 256) { 0 } else { $image.Size }
        $writer.Write([byte]$dimension)
        $writer.Write([byte]$dimension)
        $writer.Write([byte]0)
        $writer.Write([byte]0)
        $writer.Write([UInt16]1)
        $writer.Write([UInt16]32)
        $writer.Write([UInt32]$image.Bytes.Length)
        $writer.Write([UInt32]$dataOffset)
        $dataOffset += $image.Bytes.Length
    }
    foreach ($image in $images) {
        $writer.Write($image.Bytes, 0, $image.Bytes.Length)
    }
} finally {
    $writer.Dispose()
    $outputStream.Dispose()
}

Write-Host "Generated $OutputPath with $($images.Count) resolutions: $($sizes -join ', ')"