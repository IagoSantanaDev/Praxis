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
- recursos de runtime presentes: UI HTML, imagens de erro e WebView2Loader 64-bit.

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
dist\Praxis-1.0.0\stage\Praxis-build-manifest.json
dist\Praxis-1.0.0\installer\Praxis-Setup-1.0.0.exe
dist\Praxis-1.0.0\Praxis-build-manifest.json
dist\Praxis-1.0.0\Praxis-installer-manifest.json
dist\Praxis-1.0.0\distribution\                      — pasta portátil (sem instalador)
dist\Praxis-1.0.0\Praxis-Portable-1.0.0.zip       — ZIP portátil pronto para uso
```

O staging inclui recursos necessários para runtime (WebView2Loader 64-bit e documentos de licença/aviso da raiz). O staging não deve conter `.ahk`, `.ps1` ou `.iss` — nem o `cli-check.ahk`, que deixou de ser distribuído (o EXE faz o check internamente, ver seção de integridade).

Para levar o pacote a outro PC, normalmente use apenas o instalador:

```text
Praxis-Setup-<versão>.exe
```

A pasta `stage` é útil para validação técnica, mas não é o pacote de entrega preferencial.

## Validação pós-build

Depois de gerar um build completo, valide pelo menos:

1. o executável existe;
2. o instalador existe (quando gerado);
3. o ZIP portátil existe e tem o conteúdo esperado;
4. os hashes do manifesto conferem com os arquivos em disco;
5. não há fonte AutoHotkey no staging;
6. o modo de integridade do EXE retorna `0`.

Exemplo:

```powershell
$root = "dist\Praxis-9.9.18-test"
$stage = Join-Path $root "stage"
$exe = Join-Path $stage "Praxis.exe"
$setup = Join-Path $root "installer\Praxis-Setup-9.9.18-test.exe"
$zip = Join-Path $root "Praxis-Portable-9.9.18-test.zip"

$proc = Start-Process -FilePath $exe -ArgumentList "--integrity-check" -WorkingDirectory $stage -Wait -PassThru
$sourceLeaks = @(Get-ChildItem -LiteralPath $stage -Recurse -File | Where-Object { $_.Extension -in @('.ahk', '.ps1', '.iss') })

[pscustomobject]@{
  IntegrityExit        = $proc.ExitCode
  SetupExists          = Test-Path -LiteralPath $setup
  ExeExists            = Test-Path -LiteralPath $exe
  ZipExists            = Test-Path -LiteralPath $zip
  WebView2LoaderExists = Test-Path -LiteralPath (Join-Path $stage "lib\vendor\64bit\WebView2Loader.dll")
  SourceLeakCount      = $sourceLeaks.Count
}
```

Resultado esperado:

```text
IntegrityExit        : 0
SetupExists          : True
ExeExists            : True
ZipExists            : True
WebView2LoaderExists : True
SourceLeakCount      : 0
```

Se `IntegrityExit` for diferente de `0`, o executável bloqueou porque algum recurso protegido está ausente ou alterado.

## Integridade de recursos em runtime

O build gera um manifesto AutoHotkey embutido no executável. Esse manifesto contém hashes SHA-256 dos recursos externos do pacote: WebView2Loader 64-bit e os documentos legais distribuídos (LICENSE/COPYRIGHT/NOTICE.md). UI, imagens e dicionário OCR são embutidos no próprio EXE e não têm caminho em disco para validar.

O check é executado pelo próprio `Praxis.exe`, sem depender de AutoHotkey instalado no destino:

```powershell
\Praxis.exe --integrity-check
```

Códigos relevantes:

- `0`: integridade intacta;
- `70`: recurso ausente ou alterado.

O `cli-check.ahk` permanece na raiz do repositório apenas como helper de dev mode (`AutoHotkey64.exe cli-check.ahk --integrity-check`) e não é distribuído no pacote.

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
- `.pfx`, senhas, chaves privadas ou tokens;
- `config.ini` de desenvolvimento;
- logs, dumps, XMLs reais ou evidências locais de teste.

O script de build já bloqueia vazamento de `.ahk`, `.ps1` e `.iss` no staging. Ainda assim, valide antes de entregar.

## Checklist antes de entregar

Para build de teste:

- [ ] comando de build concluiu sem erro;
- [ ] instalador foi gerado;
- [ ] integridade retorna `0`;
- [ ] staging não contém fonte AutoHotkey;
- [ ] versão de teste está clara no nome do pacote;
- [ ] limitações de assinatura foram comunicadas.

Para release:

- [ ] `-Release` foi usado;
- [ ] certificado correto foi usado;
- [ ] assinatura do EXE e do instalador foi validada;
- [ ] working tree estava limpa ou `-AllowDirty` foi justificado;
- [ ] manifestos foram preservados;
- [ ] hash SHA-256 do instalador foi registrado;
- [ ] pacote foi testado em máquina limpa ou VM compatível.

## Release automático (GitHub Actions)

A cada push na branch `main`, o workflow `.github/workflows/release.yml` roda em `windows-latest` e:

1. baixa os zips oficiais do AutoHotkey v2 e do Ahk2Exe (sem instalar nada no runner);
2. executa `tools/publish-release.ps1`, que roda `build-praxis.ps1 -SkipInstaller` e gera o ZIP portátil;
3. publica/atualiza o **GitHub Release rolling** com tag `continuous` (marcado como Latest):
   - `Praxis-Portable-<versão>.zip`;
   - `SHA256SUMS.txt` (hash SHA-256 do ZIP).

Publicação manual local (após `gh auth login`):

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\publish-release.ps1
```

O release rolling não exige certificado de code signing nem Inno Setup. Para release assinado e com instalador, continue usando `build-praxis.ps1 -Release` na máquina de build local.

## Proteção jurídica e limites técnicos

Para proteção formal no Brasil, mantenha registro e evidências fora do build técnico:

- registro de programa de computador no INPI;
- hash da versão registrada;
- histórico Git;
- licença proprietária;
- contratos/EULA/NDA revisados por advogado.

A proteção técnica não substitui contrato, revisão jurídica, assinatura digital, controle de distribuição nem homologação do ambiente onde o software será executado.
