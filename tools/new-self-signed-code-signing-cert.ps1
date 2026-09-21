<#
Praxis — software proprietário
Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

Gera um certificado de code signing autoassinado e exporta como .pfx, para uso
com tools/build-praxis.ps1 -PfxPath.

IMPORTANTE — leia antes de usar:
Um certificado autoassinado satisfaz o requisito técnico de "todo build deve
ser assinado" (ver docs/DISTRIBUTION.md), mas NÃO tem cadeia até uma CA
confiável. Ele NÃO builda reputação no Windows SmartScreen nem muda o
tratamento dado pelo antivírus/EDR corporativo na máquina de produção — a
única forma real de resolver isso é um certificado emitido por uma CA
confiável (ver docs/DISTRIBUTION.md, seção "Certificado de assinatura").
Use este script como solução temporária enquanto um certificado de CA não é
adquirido, não como solução definitiva.

Gere o certificado UMA VEZ e reutilize o mesmo .pfx em todos os builds
(inclusive CI). Gerar um novo certificado a cada build muda o "publisher"
percebido a cada vez, o que é pior do que manter um único certificado
estável — mesmo autoassinado, um publisher consistente é preferível.

Exemplos:
  # Gera o certificado e pede a senha do .pfx interativamente
  powershell -ExecutionPolicy Bypass -File .\tools\new-self-signed-code-signing-cert.ps1

  # Também confia no certificado nesta máquina, só para os builds locais não
  # falharem a checagem de assinatura por "cadeia não confiável" localmente
  # (não tem nenhum efeito na máquina de produção do hospital)
  powershell -ExecutionPolicy Bypass -File .\tools\new-self-signed-code-signing-cert.ps1 -TrustForCurrentUser

  # Imprime o .pfx em base64, para colar direto no secret do GitHub Actions
  # PRAXIS_CODE_SIGNING_PFX_BASE64 (CUIDADO: não deixe isso em histórico de
  # terminal, log de CI ou arquivo versionado)
  powershell -ExecutionPolicy Bypass -File .\tools\new-self-signed-code-signing-cert.ps1 -PrintBase64
#>

[CmdletBinding()]
param(
    [string]$Subject = 'CN=Praxis (autoassinado)',
    [string]$OutputPfxPath = (Join-Path $PSScriptRoot '..\build\praxis-selfsigned.pfx'),
    [int]$ValidYears = 10,
    [switch]$TrustForCurrentUser,
    [switch]$PrintBase64
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (!(Get-Command New-SelfSignedCertificate -ErrorAction SilentlyContinue)) {
    throw 'New-SelfSignedCertificate não está disponível. Rode este script no PowerShell do Windows (módulo PKI), não no PowerShell Core em Linux/macOS.'
}

$outputDir = Split-Path -Parent $OutputPfxPath
if (![string]::IsNullOrWhiteSpace($outputDir) -and !(Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

Write-Host "Gerando certificado autoassinado: $Subject (validade: $ValidYears anos)" -ForegroundColor Cyan
$cert = New-SelfSignedCertificate `
    -Subject $Subject `
    -Type CodeSigningCert `
    -KeyUsage DigitalSignature `
    -KeyExportPolicy Exportable `
    -KeyLength 2048 `
    -HashAlgorithm SHA256 `
    -NotAfter (Get-Date).AddYears($ValidYears) `
    -CertStoreLocation Cert:\CurrentUser\My

Write-Host "Certificado criado. Thumbprint: $($cert.Thumbprint)" -ForegroundColor Green

if ($TrustForCurrentUser) {
    # Só afeta ESTA máquina (evita que Get-AuthenticodeSignature reporte
    # NotTrusted nos builds locais). Não propaga para nenhuma outra máquina —
    # em particular, não muda nada na máquina de produção do hospital.
    $rootStore = Get-Item Cert:\CurrentUser\Root
    $rootStore.Open('ReadWrite')
    $rootStore.Add($cert)
    $rootStore.Close()
    Write-Host 'Certificado adicionado a Cert:\CurrentUser\Root nesta máquina (apenas local).' -ForegroundColor Yellow
}

Write-Host "Exportando .pfx: $OutputPfxPath"
$pfxPassword = Read-Host -Prompt 'Senha para proteger o .pfx (guarde-a — sem ela o .pfx não serve para nada)' -AsSecureString
Export-PfxCertificate -Cert $cert -FilePath $OutputPfxPath -Password $pfxPassword | Out-Null

Write-Host ''
Write-Host 'Pronto. Próximos passos:' -ForegroundColor Cyan
Write-Host "  1. Guarde $OutputPfxPath e a senha em local seguro (gerenciador de senhas / cofre da equipe)."
Write-Host '     O arquivo já cai no .gitignore (*.pfx) — não versione-o de propósito.'
Write-Host '  2. Build local:'
Write-Host "     `$env:PRAXIS_SIGNING_PFX_PASSWORD = '<senha que você acabou de definir>'"
Write-Host "     powershell -ExecutionPolicy Bypass -File .\tools\build-praxis.ps1 -Version 1.0.0 -PfxPath `"$OutputPfxPath`""
Write-Host '  3. Para o release automático no GitHub Actions, configure em Settings > Secrets and variables > Actions:'
Write-Host '     PRAXIS_CODE_SIGNING_PFX_BASE64  = conteúdo do .pfx acima, em base64 (use -PrintBase64 para gerar)'
Write-Host '     PRAXIS_SIGNING_PFX_PASSWORD     = a senha definida acima'

if ($PrintBase64) {
    Write-Host ''
    Write-Warning 'Imprimindo o .pfx em base64 — não deixe isso em log de CI, histórico de terminal compartilhado ou qualquer lugar versionado.'
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($OutputPfxPath))
}
