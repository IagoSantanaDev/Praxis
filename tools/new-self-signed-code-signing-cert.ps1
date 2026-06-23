<#
.SYNOPSIS
Cria um certificado autoassinado de Code Signing para builds internos/testes do Praxis.

.DESCRIPTION
Gera um certificado autoassinado no Windows Certificate Store sem gravar .pfx, senha ou chave
privada no repositório. Por padrão, usa Cert:\CurrentUser\My e pode confiar o certificado
somente para o usuário atual copiando o certificado público para CurrentUser\Root e
CurrentUser\TrustedPublisher.

Uso recomendado para ambiente interno/teste:
  1. Criar e confiar no usuário atual:
     powershell -ExecutionPolicy Bypass -File .\tools\new-self-signed-code-signing-cert.ps1 -TrustForCurrentUser

  2. Copiar o Thumbprint exibido e gerar build assinado:
     powershell -ExecutionPolicy Bypass -File .\tools\build-praxis.ps1 -Version 1.0.0 -CertificateThumbprint <THUMBPRINT> -RequireCodeSigning

Atenção: certificado autoassinado NÃO substitui certificado comercial para distribuição pública.
Ele só será confiável nas máquinas onde o certificado público for instalado como confiável.
#>

[CmdletBinding()]
param(
    [string]$ProjectName = 'Praxis Internal Code Signing',
    [string]$DnsName = 'praxis.local',
    [ValidateRange(1, 10)]
    [int]$Years = 2,
    [switch]$TrustForCurrentUser,
    [switch]$ForceNew,
    [string]$ExportPublicCertPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Normalize-Subject {
    param([string]$Name)

    if ($Name -match '^CN=') { return $Name }
    return "CN=$Name"
}

function Get-ExistingCertificate {
    param([string]$Subject)

    $now = Get-Date
    Get-ChildItem -LiteralPath 'Cert:\CurrentUser\My' -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Subject -eq $Subject -and
            $_.HasPrivateKey -and
            $_.NotAfter -gt $now -and
            ($_.EnhancedKeyUsageList | Where-Object { $_.ObjectId -eq '1.3.6.1.5.5.7.3.3' })
        } |
        Sort-Object NotAfter -Descending |
        Select-Object -First 1
}

function Trust-CertificateForCurrentUser {
    param([System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate)

    $tempCert = Join-Path $env:TEMP "praxis-code-signing-$($Certificate.Thumbprint).cer"
    try {
        Export-Certificate -Cert $Certificate -FilePath $tempCert -Force | Out-Null
        Import-Certificate -FilePath $tempCert -CertStoreLocation 'Cert:\CurrentUser\Root' | Out-Null
        Import-Certificate -FilePath $tempCert -CertStoreLocation 'Cert:\CurrentUser\TrustedPublisher' | Out-Null
    } finally {
        if (Test-Path -LiteralPath $tempCert) {
            Remove-Item -LiteralPath $tempCert -Force
        }
    }
}

$subject = Normalize-Subject -Name $ProjectName
$cert = $null

if (!$ForceNew) {
    $cert = Get-ExistingCertificate -Subject $subject
}

if (!$cert) {
    $cert = New-SelfSignedCertificate `
        -Type CodeSigningCert `
        -Subject $subject `
        -DnsName $DnsName `
        -CertStoreLocation 'Cert:\CurrentUser\My' `
        -KeyExportPolicy Exportable `
        -KeyUsage DigitalSignature `
        -NotAfter (Get-Date).AddYears($Years)
}

if ($TrustForCurrentUser) {
    Trust-CertificateForCurrentUser -Certificate $cert
}

if (![string]::IsNullOrWhiteSpace($ExportPublicCertPath)) {
    $parent = Split-Path -Parent $ExportPublicCertPath
    if (![string]::IsNullOrWhiteSpace($parent) -and !(Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent | Out-Null
    }
    Export-Certificate -Cert $cert -FilePath $ExportPublicCertPath -Force | Out-Null
}

[pscustomobject]@{
    Subject = $cert.Subject
    Thumbprint = $cert.Thumbprint
    Store = 'CurrentUser\My'
    NotAfter = $cert.NotAfter
    HasPrivateKey = $cert.HasPrivateKey
    TrustedForCurrentUser = [bool]$TrustForCurrentUser
    PublicCertExportedTo = if ([string]::IsNullOrWhiteSpace($ExportPublicCertPath)) { $null } else { $ExportPublicCertPath }
} | Format-List
