# Build e distribuição do Praxis

> Runbook interno para gerar, validar e entregar builds do Praxis.

Este documento é para quem mantém o Praxis e precisa produzir um pacote instalável ou um executável de teste. Ao final da leitura, a pessoa deve conseguir escolher o tipo de build correto, executar o comando, localizar os artefatos e validar o resultado antes de entregar.

## Visão geral

O build do Praxis transforma o projeto AutoHotkey em um pacote distribuível para Windows. O processo:

- compila o aplicativo para `Praxis.exe`;
- embute no executável um manifesto de integridade dos recursos externos;
- copia para o staging apenas os recursos necessários em runtime;
- bloqueia vazamento de arquivos fonte/script no pacote final;
- gera manifestos SHA-256 do pacote e do instalador;
- opcionalmente assina o executável e o instalador;
- opcionalmente gera o instalador Inno Setup.

O build reduz exposição casual do código-fonte, mas não é DRM inviolável. AutoHotkey compilado, compressão, assinatura e hashes aumentam o custo de adulteração/inspeção casual; não impedem engenharia reversa profissional.

## Pré-requisitos da máquina de build

Para build completo com instalador:

- Windows 64-bit;
- PowerShell;
- AutoHotkey v2 instalado;
- Ahk2Exe disponível;
- Inno Setup 6 instalado;
- assets do instalador presentes;
- recursos de runtime presentes: UI HTML, JSON de referências OCR e script OCR para embutir no EXE; WebView2Loader 64-bit continua externo no staging.

Para release assinado:

- certificado de code signing instalado com chave privada disponível;
- `signtool.exe` ou suporte ao `Set-AuthenticodeSignature` do PowerShell;
- working tree Git limpa, salvo exceção explícita com `-AllowDirty`.

## Tipos de build

### Build de teste

Use para validação local, QA manual e instalação temporária em ambiente controlado.

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build-praxis.ps1 `
  -Version 9.9.18-test
```

Características:

- gera `Praxis.exe`;
- gera instalador Inno Setup;
- não exige assinatura digital;
- não força compressão Ahk2Exe;
- registra no manifesto se a árvore Git estava suja;
- não deve ser tratado como release de produção.

Se o build avisar que assinatura digital está desabilitada, isso é esperado em build de teste. Para release, use o modo `-Release`.

### Build de teste sem instalador

Use apenas quando quiser validar compilação e staging sem gerar instalador.

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build-praxis.ps1 `
  -Version 9.9.18-test `
  -SkipInstaller
```

Esse modo não serve para validar distribuição completa, porque não exercita o script Inno Setup nem o empacotamento final.

### Build com assinatura obrigatória

Use quando quiser assinar os binários, mas sem ativar todas as regras estritas de release.

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build-praxis.ps1 `
  -Version 1.0.0 `
  -CertificateThumbprint "THUMBPRINT_DO_CERTIFICADO" `
  -RequireCodeSigning
```

Esse modo falha se a assinatura não puder ser aplicada ou validada.

### Release endurecido

Use para qualquer entrega que deva ser tratada como release real.

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build-praxis.ps1 `
  -Version 1.0.0 `
  -CertificateThumbprint "THUMBPRINT_DO_CERTIFICADO" `
  -Release
```

O modo `-Release` força:

- assinatura digital obrigatória;
- compressão Ahk2Exe;
- geração de instalador;
- working tree Git limpa;
- metadados de release no manifesto.

Bloqueios esperados:

```text
Release endurecido não permite -SkipInstaller. Gere e valide o instalador.
```

```text
Release endurecido bloqueado: working tree sujo. Commit/stash antes de gerar release ou use -AllowDirty para registrar exceção explícita.
```

Use `-AllowDirty` somente quando a exceção for intencional e aceitável. O manifesto registrará `sourceDirty=true`.

## Certificado de assinatura

Para teste interno, é possível criar certificado autoassinado:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\new-self-signed-code-signing-cert.ps1 `
  -TrustForCurrentUser
```

Para listar certificados disponíveis:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\list-code-signing-certs.ps1 `
  -OnlyCodeSigning
```

O `Thumbprint` identifica o certificado e não é segredo. A chave privada e arquivos `.pfx` são sensíveis e não devem ser distribuídos.

Certificado autoassinado é útil para testes e ambiente interno controlado, mas não cria reputação pública no SmartScreen nem substitui certificado comercial para distribuição externa.

## Artefatos gerados

Para a versão `1.0.0`, o build completo gera:

```text
dist\Praxis-1.0.0\stage\Praxis.exe
dist\Praxis-1.0.0\stage\lib\64bit\WebView2Loader.dll
dist\Praxis-1.0.0\installer\Praxis-Setup-1.0.0.exe
dist\Praxis-1.0.0\delivery\Praxis-Setup-1.0.0.exe
dist\Praxis-1.0.0\distribution\Praxis.exe
dist\Praxis-1.0.0\distribution\lib\64bit\WebView2Loader.dll
dist\Praxis-1.0.0\distribution\LICENSE
dist\Praxis-1.0.0\distribution\COPYRIGHT
dist\Praxis-1.0.0\distribution\NOTICE.md
dist\Praxis-1.0.0\distribution\EULA.md
dist\Praxis-1.0.0\distribution\NDA.md
dist\Praxis-1.0.0\distribution\PRIVACY_LGPD.md
dist\Praxis-1.0.0\distribution\THIRD_PARTY_NOTICES.md
dist\Praxis-1.0.0\delivery\LICENSE
dist\Praxis-1.0.0\delivery\COPYRIGHT
dist\Praxis-1.0.0\delivery\NOTICE.md
dist\Praxis-1.0.0\delivery\EULA.md
dist\Praxis-1.0.0\delivery\NDA.md
dist\Praxis-1.0.0\delivery\PRIVACY_LGPD.md
dist\Praxis-1.0.0\delivery\THIRD_PARTY_NOTICES.md
dist\Praxis-1.0.0\Praxis-build-manifest.json
dist\Praxis-1.0.0\Praxis-installer-manifest.json
```

O staging agora é sanitizado para runtime: contém apenas o executável compilado, o loader WebView2 e os documentos legais que o instalador também instala. A pasta `distribution` é a entrega portátil para computadores que não aceitam instalador; ela não expõe `.ahk`, `.ps1`, `.html` ou `.json`.

Para levar o pacote a outro PC, use a pasta `distribution` ou apenas o instalador da pasta `delivery`:

```text
dist\Praxis-<versão>\distribution\Praxis.exe
dist\Praxis-<versão>\delivery\Praxis-Setup-<versão>.exe
```

A pasta `stage` é útil para validação técnica, mas não é o pacote de entrega preferencial.

## Validação pós-build

Depois de gerar um build completo, valide pelo menos:

1. o executável existe na pasta `stage`;
2. o instalador existe na pasta `installer`;
3. a pasta `delivery` existe para cenários com instalador;
4. a pasta `distribution` existe para cenários sem instalador;
5. o loader WebView2 foi copiado;
6. não há fonte AutoHotkey, HTML, JSON ou scripts de build em `stage`, `delivery` ou `distribution`;
7. o modo de integridade retorna sucesso.

Exemplo:

```powershell
$root = "dist\Praxis-9.9.18-test"
$stage = Join-Path $root "stage"
$delivery = Join-Path $root "delivery"
$distribution = Join-Path $root "distribution"
$exe = Join-Path $stage "Praxis.exe"
$setup = Join-Path $root "installer\Praxis-Setup-9.9.18-test.exe"
$loader = Join-Path $stage "lib\64bit\WebView2Loader.dll"
$disallowed = @('.ahk', '.ps1', '.iss', '.html', '.json')

$proc = Start-Process -FilePath $exe -ArgumentList "--integrity-check" -WorkingDirectory $stage -Wait -PassThru
$stageLeaks = @(Get-ChildItem -LiteralPath $stage -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $disallowed -contains $_.Extension })
$deliveryLeaks = @(Get-ChildItem -LiteralPath $delivery -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $disallowed -contains $_.Extension })
$distributionLeaks = @(Get-ChildItem -LiteralPath $distribution -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $disallowed -contains $_.Extension })

[pscustomobject]@{
  IntegrityExit      = $proc.ExitCode
  SetupExists        = Test-Path -LiteralPath $setup
  DeliveryExists     = Test-Path -LiteralPath $delivery
  DistributionExists = Test-Path -LiteralPath $distribution
  ExeExists          = Test-Path -LiteralPath $exe
  LoaderExists       = Test-Path -LiteralPath $loader
  StageLeakCount     = $stageLeaks.Count
  DeliveryLeakCount  = $deliveryLeaks.Count
  DistributionLeakCount = $distributionLeaks.Count
}
```

Resultado esperado:

```text
IntegrityExit         : 0
SetupExists           : True
DeliveryExists        : True
DistributionExists    : True
ExeExists             : True
LoaderExists          : True
StageLeakCount        : 0
DeliveryLeakCount     : 0
DistributionLeakCount : 0
```

Se `IntegrityExit` for diferente de `0`, o executável bloqueou porque algum recurso protegido está ausente ou alterado.

## Integridade de recursos em runtime

O build gera um manifesto AutoHotkey embutido no executável. Esse manifesto contém hashes SHA-256 apenas dos recursos externos que permanecem no staging sanitizado.

Na inicialização, o Praxis valida:

- `lib\64bit\WebView2Loader.dll`;
- a presença do binário compilado e dos artefatos embutidos no EXE.

A UI HTML, o JSON de referências OCR e o script OCR são embutidos no executável durante o build.

Se algum arquivo externo estiver ausente ou alterado, o aplicativo falha fechado antes de liberar a interface ou automações. O modo interno de teste é:

```powershell
.\Praxis.exe --integrity-check
```

Códigos relevantes:

- `0`: integridade intacta;
- `70`: recurso ausente ou alterado.

## Dependências no PC de destino

O instalador atual é voltado para Windows 64-bit.

O PC de destino não precisa ter AutoHotkey instalado. O runtime AutoHotkey vai dentro do `Praxis.exe` compilado.

O PC de destino precisa ter Microsoft Edge WebView2 Runtime. Se o runtime não estiver presente, o instalador tenta baixar e executar o bootstrapper Evergreen da Microsoft durante a instalação.

O aplicativo também depende da validação de acesso em runtime pela API configurada no cliente. Se a rede do ambiente bloquear essa chamada, o build online atual não conseguirá validar novos acessos.

Essas são dependências operacionais do pacote atual, não instruções para contornar política de rede ou segurança.

## O que não deve entrar no pacote

Não distribua:

- arquivos `.ahk` fonte;
- scripts `.ps1` de build;
- scripts `.iss` do instalador;
- arquivos `.html` de interface;
- arquivos `.json` de manifesto ou referência;
- `.pfx`, senhas, chaves privadas ou tokens;
- `config.ini` de desenvolvimento;
- logs, dumps, XMLs reais ou evidências locais de teste.

O script de build já bloqueia vazamento de `.ahk`, `.ps1`, `.iss`, `.html` e `.json` no staging. Ainda assim, valide antes de entregar.

## Checklist antes de entregar

Para build de teste:

- [ ] comando de build concluiu sem erro;
- [ ] instalador foi gerado;
- [ ] pasta `delivery` foi gerada;
- [ ] integridade retorna `0`;
- [ ] staging não contém fonte AutoHotkey, HTML ou JSON;
- [ ] versão de teste está clara no nome do pacote;
- [ ] limitações de assinatura foram comunicadas.

Para release:

- [ ] `-Release` foi usado;
- [ ] certificado correto foi usado;
- [ ] assinatura do EXE e do instalador foi validada;
- [ ] working tree estava limpa ou `-AllowDirty` foi justificado;
- [ ] manifestos internos foram preservados fora da pasta `delivery`;
- [ ] hash SHA-256 do instalador foi registrado;
- [ ] pacote foi testado em máquina limpa ou VM compatível.

## Proteção jurídica e limites técnicos

Para proteção formal no Brasil, mantenha registro e evidências fora do build técnico:

- registro de programa de computador no INPI;
- hash da versão registrada;
- histórico Git;
- licença proprietária;
- contratos/EULA/NDA revisados por advogado.

A proteção técnica não substitui contrato, revisão jurídica, assinatura digital, controle de distribuição nem homologação do ambiente onde o software será executado.
