<#
.SYNOPSIS
Lista certificados candidatos para assinatura digital Authenticode do Praxis.

.DESCRIPTION
Mostra certificados nos stores CurrentUser\My e LocalMachine\My que possuem chave privada
e, preferencialmente, EKU de Code Signing. Não exporta chave, senha ou material sensível.
Use o Thumbprint exibido com tools/build-praxis.ps1 -CertificateThumbprint.
#>

[CmdletBinding()]
param(
    [ValidateSet('CurrentUser','LocalMachine','All')]
    [string]$StoreLocation = 'All',
    [string]$StoreName = 'My',
    [switch]$OnlyCodeSigning
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$locations = if ($StoreLocation -eq 'All') { @('CurrentUser','LocalMachine') } else { @($StoreLocation) }
$now = Get-Date

$results = foreach ($location in $locations) {
    $storePath = "Cert:\$location\$StoreName"
    if (!(Test-Path -LiteralPath $storePath)) { continue }

    Get-ChildItem -LiteralPath $storePath -ErrorAction SilentlyContinue | ForEach-Object {
        $codeSigningEku = $_.EnhancedKeyUsageList | Where-Object { $_.ObjectId -eq '1.3.6.1.5.5.7.3.3' }
        if ($OnlyCodeSigning -and !$codeSigningEku) { return }

        [pscustomobject]@{
            Store = "$location\$StoreName"
            Subject = $_.Subject
            Thumbprint = $_.Thumbprint
            HasPrivateKey = $_.HasPrivateKey
            IsCodeSigning = [bool]$codeSigningEku
            NotBefore = $_.NotBefore
            NotAfter = $_.NotAfter
            Expired = $_.NotAfter -lt $now
        }
    }
}

$results |
    Sort-Object IsCodeSigning, HasPrivateKey, NotAfter -Descending |
    Format-Table -AutoSize Store, Subject, Thumbprint, HasPrivateKey, IsCodeSigning, NotAfter, Expired
