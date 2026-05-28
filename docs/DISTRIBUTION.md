# Build, assinatura interna e distribuição do Praxis

> Guia operacional. Certificado autoassinado é adequado para testes, homologação e ambientes internos controlados. Não substitui certificado comercial para distribuição pública.

## Certificado autoassinado

Crie um certificado de code signing no Windows Certificate Store do usuário atual e confie nele localmente:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\new-self-signed-code-signing-cert.ps1 -TrustForCurrentUser
```

O comando exibe um `Thumbprint`. Esse valor não é segredo; ele identifica o certificado instalado.

Também é possível exportar apenas o certificado público `.cer` para instalar em outras máquinas internas:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\new-self-signed-code-signing-cert.ps1 `
  -TrustForCurrentUser `
  -ExportPublicCertPath .\dist\Praxis-Internal-CodeSigning.cer
```

Não distribua `.pfx`, senha ou chave privada. Para máquinas internas que precisam confiar na assinatura, copie apenas o `.cer` público e instale no usuário atual:

```powershell
Import-Certificate -FilePath .\Praxis-Internal-CodeSigning.cer -CertStoreLocation Cert:\CurrentUser\Root
Import-Certificate -FilePath .\Praxis-Internal-CodeSigning.cer -CertStoreLocation Cert:\CurrentUser\TrustedPublisher
```

## Listar certificados de assinatura disponíveis

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\list-code-signing-certs.ps1 -OnlyCodeSigning
```

## Gerar build assinado

Use o `Thumbprint` retornado pelo gerador/listador:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build-praxis.ps1 `
  -Version 1.0.0 `
  -CertificateThumbprint "THUMBPRINT_DO_CERTIFICADO" `
  -RequireCodeSigning
```

O build:

- compila `main.ahk` para `Praxis.exe`;
- não inclui arquivos `.ahk`, `.ps1` ou `.iss` no staging final;
- assina `Praxis.exe`;
- gera o instalador Inno Setup;
- assina `Praxis-Setup-<versão>.exe`;
- valida a assinatura com Authenticode;
- gera manifestos com SHA-256 e metadados de assinatura.

Se `signtool.exe` não estiver instalado, o script usa `Set-AuthenticodeSignature` como fallback local.

## Perfil de build endurecido

Para releases distribuídos fora da máquina de desenvolvimento, use sempre assinatura obrigatória e compressão do Ahk2Exe:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build-praxis.ps1 `
  -Version 1.0.0 `
  -CertificateThumbprint "THUMBPRINT_DO_CERTIFICADO" `
  -RequireCodeSigning `
  -Compress
```

Esse perfil:

- bloqueia release sem assinatura digital;
- reduz exposição casual com compressão do executável;
- mantém o stage sem `.ahk`, `.ps1` ou `.iss`;
- gera manifestos SHA-256 para auditoria;
- não inclui segredos no pacote.

Compressão e assinatura aumentam o custo de adulteração/inspeção casual, mas não impedem engenharia reversa por atacante determinado. Não coloque códigos de acesso aceitos, chaves privadas, tokens de API ou regras comerciais críticas dentro do cliente.

## Criptografia local do `config.ini`

O Praxis armazena dados sensíveis do `config.ini` usando DPAPI do Windows no contexto do usuário atual:

- `[Access] EncCode` — código de acesso validado na Praxis API;
- `[Auth] EncPass` — senha do MV informada pelo operador.

Esses valores:

- não ficam em texto claro;
- não devem ser copiados entre usuários/máquinas;
- devem ser revalidados contra a API quando aplicável;
- podem ser revogados no servidor removendo/trocando `ACCESS_CODES`.

A DPAPI protege contra leitura casual do arquivo, mas não protege contra malware rodando como o mesmo usuário nem contra um atacante que controle a sessão Windows. Por isso, a autorização real deve continuar no servidor (`https://praxis.squareweb.app/v1/access/validate`).

## Engenharia reversa: limites e postura

O cliente desktop deve ser tratado como ambiente não confiável. Medidas locais são barreiras, não garantias.

O que o projeto faz ou deve fazer:

- distribuir apenas `Praxis.exe` e recursos necessários, nunca os `.ahk` fonte;
- assinar o executável e o instalador;
- preservar manifesto de hashes para detectar adulteração;
- validar código de acesso na API, não em segredo hardcoded local;
- armazenar segredos locais com DPAPI;
- manter logs sem código de acesso, senha, XML real, prints sensíveis ou dados de paciente.

Se a ameaça for engenharia reversa profissional, considere uma camada comercial de proteção/empacotamento para Windows, como VMProtect/Themida/WinLicense ou equivalente. Mesmo essas soluções não tornam o cliente inviolável; elas apenas aumentam o custo. A proteção mais forte continua sendo manter decisões comerciais e validações revogáveis no servidor.

## Limites do certificado autoassinado

- Não cria reputação SmartScreen pública.
- Não prova identidade pública como certificado comercial.
- Só é confiável em máquinas que confiam no certificado público.
- É suficiente para validar integridade/autoria interna e reduzir alertas em ambiente controlado.

## Artefatos esperados

```text
dist\Praxis-1.0.0\stage\Praxis.exe
dist\Praxis-1.0.0\installer\Praxis-Setup-1.0.0.exe
dist\Praxis-1.0.0\Praxis-build-manifest.json
dist\Praxis-1.0.0\Praxis-installer-manifest.json
```

## Registro INPI e proteção jurídica

Para proteção formal no Brasil, faça o Registro de Programa de Computador no INPI e mantenha:

- pacote técnico da versão registrada;
- hash/resumo digital;
- protocolo/certificado;
- histórico Git;
- licença proprietária;
- EULA/NDA revisados por advogado antes de distribuição externa.

A proteção técnica não substitui contrato, revisão jurídica nem controle de distribuição.
