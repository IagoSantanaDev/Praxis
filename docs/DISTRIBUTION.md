# Build e distribuição do Praxis

> Guia interno para gerar, validar e entregar builds do Praxis.

Este documento é para quem mantém o projeto e precisa produzir um pacote portátil ou um executável de teste. Em poucas páginas, ele cobre como rodar o build, onde encontrar os artefatos e como validar o resultado antes de entregar.

## Visão geral

O build do Praxis transforma o código em AutoHotkey em um pacote para Windows. O processo:

- compila o aplicativo em `Praxis.exe`;
- incorpora no executável um manifesto de integridade para recursos externos;
- copia para o staging apenas o que é necessário em runtime;
- bloqueia vazamentos de código-fonte ou scripts no pacote final;
- gera um manifesto SHA-256 do pacote;
- pode assinar o executável quando necessário.

Esse passo reduz a exposição casual do código-fonte, mas não é um sistema de proteção inviolável. O executável compilado, a compressão, a assinatura e os hashes dificultam inspeções e adulterações simples, sem impedir engenharia reversa profissional.

## Pré-requisitos da máquina de build

Para um build portátil:

- Windows 64-bit;
- PowerShell;
- AutoHotkey v2 instalado;
- Ahk2Exe disponível;
- recursos de runtime presentes: interface HTML, imagens de erro e `WebView2Loader` 64-bit.

Para release assinado:

- certificado de code signing instalado com chave privada disponível;
- `signtool.exe` ou suporte ao `Set-AuthenticodeSignature` do PowerShell;
- árvore Git limpa, a menos que seja usada uma exceção explícita com `-AllowDirty`.

## Tipos de build

### Build de teste

Esse é o caminho para validação local, QA manual e instalação temporária em ambiente controlado.

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build-praxis.ps1 `
  -Version 9.9.18-test
```

Ele gera:

- `Praxis.exe`;
- pasta de distribuição;
- ZIP portátil;
- sem exigência de assinatura digital;
- sem compressão forçada do Ahk2Exe;
- registro no manifesto quando a árvore Git estiver suja.

Esse tipo de build não deve ser tratado como release de produção. Se o processo avisar que a assinatura digital está desabilitada, isso é esperado em build de teste. Para release, use o modo `-Release`.

### Build com assinatura obrigatória

Use esse modo quando quiser assinar os binários, sem ativar todas as regras estritas de release.

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build-praxis.ps1 `
  -Version 1.0.0 `
  -CertificateThumbprint "THUMBPRINT_DO_CERTIFICADO" `
  -RequireCodeSigning
```

Esse modo falha se a assinatura não puder ser aplicada ou validada.

### Release endurecido

Use esse caminho para qualquer entrega que deva ser tratada como release real.

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build-praxis.ps1 `
  -Version 1.0.0 `
  -CertificateThumbprint "THUMBPRINT_DO_CERTIFICADO" `
  -Release
```

O modo `-Release` força:

- assinatura digital obrigatória;
- compressão Ahk2Exe;
- árvore Git limpa;
- metadados de release no manifesto.

Esse build não gera instalador e não tem um modo alternativo de instalação.

```text
Release endurecido bloqueado: working tree sujo. Commit/stash antes de gerar release ou use -AllowDirty para registrar exceção explícita.
```

Use `-AllowDirty` somente quando a exceção for intencional e aceitável. O manifesto registra `sourceDirty=true`.

## Certificado de assinatura

Para testes internos, é possível criar um certificado autoassinado:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\new-self-signed-code-signing-cert.ps1 `
  -TrustForCurrentUser
```

Para listar certificados disponíveis:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\list-code-signing-certs.ps1 `
  -OnlyCodeSigning
```

O `Thumbprint` identifica o certificado e não é um segredo. A chave privada e os arquivos `.pfx` são sensíveis e não devem ser distribuídos.

Um certificado autoassinado é útil para testes e ambientes internos controlados, mas não cria reputação pública no SmartScreen nem substitui um certificado comercial para distribuição externa.

## Artefatos gerados

Para a versão `1.0.0`, o build gera:

```text
dist\Praxis-1.0.0\stage\Praxis.exe
dist\Praxis-1.0.0\Praxis-build-manifest.json
dist\Praxis-1.0.0\distribution\                      — pasta portátil
dist\Praxis-1.0.0\Praxis-Portable-1.0.0.zip       — ZIP portátil pronto para uso
```

O staging inclui os recursos de runtime necessários, como `WebView2Loader` 64-bit e os documentos legais em nível raiz. O staging não deve conter `.ahk`, `.ps1` ou `.iss`. O `cli-check.ahk` também não é distribuído no pacote final; o EXE faz esse check internamente.

Para levar o pacote a outro computador, basta extrair o ZIP portátil e executar `Praxis.exe`. A pasta `stage` é útil para validação técnica, mas o ZIP é o pacote preferido para entrega.

## Validação pós-build

Depois de gerar um build, vale conferir pelo menos estes pontos:

1. o executável existe;
2. o ZIP portátil existe e tem o conteúdo esperado;
3. os hashes do manifesto batem com os arquivos em disco;
4. não há fonte AutoHotkey no staging;
5. o modo de integridade do EXE retorna `0`.

Exemplo:

```powershell
$root = "dist\Praxis-9.9.18-test"
$stage = Join-Path $root "stage"
$exe = Join-Path $stage "Praxis.exe"
$zip = Join-Path $root "Praxis-Portable-9.9.18-test.zip"

$proc = Start-Process -FilePath $exe -ArgumentList "--integrity-check" -WorkingDirectory $stage -Wait -PassThru
$sourceLeaks = @(Get-ChildItem -LiteralPath $stage -Recurse -File | Where-Object { $_.Extension -in @('.ahk', '.ps1', '.iss') })

[pscustomobject]@{
  IntegrityExit        = $proc.ExitCode
  ExeExists            = Test-Path -LiteralPath $exe
  ZipExists            = Test-Path -LiteralPath $zip
  WebView2LoaderExists = Test-Path -LiteralPath (Join-Path $stage "lib\vendor\64bit\WebView2Loader.dll")
  SourceLeakCount      = $sourceLeaks.Count
}
```

Resultado esperado:

```text
IntegrityExit        : 0
ExeExists            : True
ZipExists            : True
WebView2LoaderExists : True
SourceLeakCount      : 0
```

Se `IntegrityExit` for diferente de `0`, o executável bloqueou porque algum recurso protegido está ausente ou alterado.

## Integridade de recursos em runtime

O build gera um manifesto AutoHotkey embutido no executável. Esse manifesto inclui hashes SHA-256 dos recursos externos do pacote: `WebView2Loader` 64-bit e os documentos legais distribuídos (`LICENSE`, `COPYRIGHT`, `NOTICE.md`). A interface, as imagens e o dicionário OCR ficam embutidos no próprio EXE e não têm caminho em disco para validação.

O check é executado pelo próprio `Praxis.exe`, sem depender de uma instalação de AutoHotkey no destino:

```powershell
\Praxis.exe --integrity-check
```

Códigos relevantes:

- `0`: integridade intacta;
- `70`: recurso ausente ou alterado.

O `cli-check.ahk` continua na raiz do repositório apenas como helper para desenvolvimento (`AutoHotkey64.exe cli-check.ahk --integrity-check`) e não é distribuído no pacote.

## Dependências no PC de destino

O aplicativo portátil é voltado para Windows 64-bit.

O PC de destino não precisa ter AutoHotkey instalado. O runtime vem dentro do `Praxis.exe` compilado.

O ambiente precisa ter o Microsoft Edge WebView2 Runtime. Esse componente normalmente é entregue pela política de software do ambiente.

O aplicativo também depende da validação de acesso em runtime pela API configurada no cliente. Se a rede do ambiente bloquear essa chamada, a build online atual não conseguirá validar novos acessos.

Essas são dependências operacionais do pacote atual, não instruções para contornar regras de rede ou segurança.

## O que não deve entrar no pacote

Não distribua:

- arquivos `.ahk` de origem;
- scripts `.ps1` de build;
- `.pfx`, senhas, chaves privadas ou tokens;
- arquivos de configuração com dados específicos de desenvolvimento;
- logs, dumps, XMLs reais ou evidências locais de teste.

O script de build já bloqueia vazamentos de `.ahk`, `.ps1` e `.iss` no staging. Ainda assim, vale validar antes de entregar.

## Checklist antes da entrega

Para build de teste:

- [ ] o comando de build concluiu sem erro;
- [ ] o ZIP portátil foi gerado;
- [ ] o executável foi validado;
- [ ] o manifesto foi conferido;
- [ ] o pacote não contém fontes AutoHotkey.

Para release sério:

- [ ] o código está em árvore limpa;
- [ ] a assinatura foi aplicada corretamente;
- [ ] a distribuição foi testada em ambiente limpo;
- [ ] os artefatos e hashes foram registrados corretamente.
- [ ] integridade retorna `0`;
- [ ] staging não contém fonte AutoHotkey;
- [ ] versão de teste está clara no nome do pacote;
- [ ] limitações de assinatura foram comunicadas.

Para release:

- [ ] `-Release` foi usado;
- [ ] certificado correto foi usado;
- [ ] assinatura do EXE foi validada;
- [ ] working tree estava limpa ou `-AllowDirty` foi justificado;
- [ ] manifesto foi preservado;
- [ ] hash SHA-256 do ZIP foi registrado;
- [ ] pacote foi testado em máquina limpa ou VM compatível.

## Release automático (GitHub Actions)

A cada push na branch `main`, o workflow `.github/workflows/release.yml` roda em `windows-latest` e:

1. baixa os zips oficiais do AutoHotkey v2 e do Ahk2Exe (sem instalar nada no runner);
2. executa `tools/publish-release.ps1`, que roda `build-praxis.ps1` e gera o ZIP portátil;
3. publica/atualiza o **GitHub Release rolling** com tag `continuous` (marcado como Latest):
   - `Praxis-Portable-<versão>.zip`;
   - `SHA256SUMS.txt` (hash SHA-256 do ZIP).

Publicação manual local (após `gh auth login`):

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\publish-release.ps1
```

O release rolling não exige certificado de code signing. Para release assinado, use `build-praxis.ps1 -Release` na máquina de build local.

## Proteção jurídica e limites técnicos

Para proteção formal no Brasil, mantenha registro e evidências fora do build técnico:

- registro de programa de computador no INPI;
- hash da versão registrada;
- histórico Git;
- licença proprietária;
- contratos/EULA/NDA revisados por advogado.

A proteção técnica não substitui contrato, revisão jurídica, assinatura digital, controle de distribuição nem homologação do ambiente onde o software será executado.
