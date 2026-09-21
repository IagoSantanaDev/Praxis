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

- certificado de code signing com chave privada disponível — via `.pfx` (`-PfxPath`, recomendado para CI) ou já importado no certificate store do Windows (`-CertificateThumbprint`);
- `signtool.exe` (opcional; `-CertificateThumbprint` cai para `Set-AuthenticodeSignature` se não encontrado) ou suporte ao `Set-AuthenticodeSignature` do PowerShell (sempre usado com `-PfxPath`);
- árvore Git limpa, a menos que seja usada uma exceção explícita com `-AllowDirty` (apenas em `-Release`).

## Tipos de build

### Build de teste (sem assinatura)

Esse é o caminho para validação local e QA manual. Desde 2026-09-20, **assinatura é obrigatória por padrão em qualquer build** — um build sem certificado precisa optar explicitamente por `-AllowUnsigned`.

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build-praxis.ps1 `
  -Version 9.9.18-test `
  -AllowUnsigned
```

Ele gera:

- `Praxis.exe`;
- pasta de distribuição;
- ZIP portátil;
- sem compressão forçada do Ahk2Exe;
- registro no manifesto quando a árvore Git estiver suja.

Esse tipo de build não deve ser tratado como release de produção nem distribuído para a máquina de produção do hospital — um executável não assinado é o principal motivo de antivírus/EDR corporativo apagar o `.exe` (ver seção de troubleshooting, se existir, ou o histórico de auditoria do projeto). Para release, use o modo `-Release`.

### Build com assinatura (via .pfx — recomendado para CI e é o caminho atual do projeto)

Esse é o caminho padrão desde 2026-09-20: **basta não passar `-AllowUnsigned`** para exigir assinatura. Com um arquivo `.pfx`, não é preciso importar nada no certificate store do Windows — útil em runners de CI, que são efêmeros. Hoje o `.pfx` usado é o certificado autoassinado gerado por `tools/new-self-signed-code-signing-cert.ps1` (ver seção "Certificado de assinatura" abaixo).

```powershell
$env:PRAXIS_SIGNING_PFX_PASSWORD = '<senha do .pfx>'   # nunca como parâmetro de linha de comando
powershell -ExecutionPolicy Bypass -File .\tools\build-praxis.ps1 `
  -Version 1.0.0 `
  -PfxPath .\build\praxis-selfsigned.pfx
```

### Build com assinatura (certificado no store do Windows)

Alternativa quando o certificado já está importado localmente:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build-praxis.ps1 `
  -Version 1.0.0 `
  -CertificateThumbprint "THUMBPRINT_DO_CERTIFICADO"
```

Qualquer um dos dois modos falha se a assinatura não puder ser aplicada ou validada. `-RequireCodeSigning` continua aceito por compatibilidade, mas não muda mais nada — assinatura já é o padrão.

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

**Situação atual do projeto:** builds usam um certificado **autoassinado** como
solução temporária (gerado com o script abaixo), enquanto um certificado de CA
confiável não é adquirido. Isso satisfaz a exigência técnica de "todo build é
assinado", mas **não builda reputação no SmartScreen nem muda como o
antivírus/EDR corporativo trata o executável na máquina de produção** — a
única forma real de resolver isso é um certificado emitido por uma CA
confiável (ver comparação de opções no histórico de auditoria do projeto).
Trate isto como item em aberto, não como problema resolvido.

Gere o certificado (uma vez só — reutilize o mesmo `.pfx` em todo build,
inclusive CI; gerar um novo a cada build faria o "publisher" mudar toda hora):

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\new-self-signed-code-signing-cert.ps1 -TrustForCurrentUser
```

O script:
- cria um certificado de code signing autoassinado válido por 10 anos;
- com `-TrustForCurrentUser`, importa o certificado em `Cert:\CurrentUser\Root`
  **só nesta máquina** — evita que a checagem pós-assinatura do
  `build-praxis.ps1` acuse cadeia não confiável nos builds locais. Não tem
  nenhum efeito na máquina de produção do hospital;
- exporta um `.pfx` (pede a senha interativamente — nunca hardcoded) para uso
  com `-PfxPath`;
- com `-PrintBase64`, imprime o `.pfx` em base64 para colar no secret do
  GitHub Actions `PRAXIS_CODE_SIGNING_PFX_BASE64` (a senha vai no secret
  `PRAXIS_SIGNING_PFX_PASSWORD`, separado).

Para listar certificados de code signing já disponíveis:

```powershell
Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert
```

O `Thumbprint` identifica o certificado e não é um segredo. A chave privada e
os arquivos `.pfx` são sensíveis e não devem ser distribuídos nem commitados
(`*.pfx` já está no `.gitignore`) — em CI, o `.pfx` fica apenas no secret
`PRAXIS_CODE_SIGNING_PFX_BASE64` e a senha em `PRAXIS_SIGNING_PFX_PASSWORD`.

Quando um certificado de CA confiável for adquirido, o processo é o mesmo —
só troque o `.pfx` (ou use `-CertificateThumbprint` se preferir importar no
certificate store) — nada mais no build muda.

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

A cada push nas branches `main`/`KAN-03`, o workflow `.github/workflows/release.yml` roda em `windows-latest` e:

1. baixa os zips oficiais do AutoHotkey v2 e do Ahk2Exe (sem instalar nada no runner);
2. decodifica o certificado `.pfx` do secret `PRAXIS_CODE_SIGNING_PFX_BASE64`, se configurado;
3. executa `tools/publish-release.ps1`, que roda `build-praxis.ps1` (repassando `-PfxPath` quando o certificado estiver disponível) e gera o ZIP portátil;
4. publica/atualiza um **GitHub Release rolling por branch** (tag `continuous-<branch>`, ex.: `continuous-main`):
   - `Praxis-Portable-<versão>.zip`;
   - `SHA256SUMS.txt` (hash SHA-256 do ZIP).

Publicação manual local (após `gh auth login`):

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\publish-release.ps1 -PfxPath .\certificado.pfx
```

Desde 2026-09-20, o release rolling **exige** certificado de code signing como qualquer outro build — se os secrets `PRAXIS_CODE_SIGNING_PFX_BASE64` e `PRAXIS_SIGNING_PFX_PASSWORD` não estiverem configurados no repositório, o step de build falha intencionalmente em vez de publicar um artefato não assinado. Configure os dois secrets em Settings → Secrets and variables → Actions para habilitar a assinatura automática. A compressão Ahk2Exe do modo `-Release` continua sendo feita manualmente na máquina de build local, fora deste workflow.

## Proteção jurídica e limites técnicos

Para proteção formal no Brasil, mantenha registro e evidências fora do build técnico:

- registro de programa de computador no INPI;
- hash da versão registrada;
- histórico Git;
- licença proprietária;
- contratos/EULA/NDA revisados por advogado.

A proteção técnica não substitui contrato, revisão jurídica, assinatura digital, controle de distribuição nem homologação do ambiente onde o software será executado.
