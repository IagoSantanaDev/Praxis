# Praxis

Aplicação desktop em AutoHotkey v2 para automações do fluxo Praxis, com interface HTML carregada via WebView2.

## Visão geral

O projeto centraliza scripts operacionais em uma interface única. O arquivo `main.ahk` registra as automações disponíveis, abre a UI em `ui/index.html` e despacha as execuções para os scripts em `scripts/`.

Automações registradas atualmente:

- **Remessa por Protocolo**: baixa protocolos no MOV DOC e cria ou atualiza remessa no FFCV.
- **Protocolar**: movimenta contas de remessas para outro setor.
- **Fechar e Gerar XML**: fecha remessas e gera arquivo XML.

## Estrutura

```text
.
├── main.ahk                 # Entrada da aplicação
├── lib/                     # Bibliotecas AutoHotkey e WebView2Loader.dll
├── scripts/                 # Automações executadas pela interface
├── ui/                      # Interface HTML carregada no WebView2
└── Imagens_Debug/           # Evidências locais de debug ignoradas pelo Git
```

## Requisitos

- Windows.
- AutoHotkey v2.0 ou superior.
- Microsoft Edge WebView2 Runtime.
- `lib/64bit/WebView2Loader.dll` disponível no caminho esperado pelo `main.ahk`.
- PowerShell disponível para criptografia/descriptografia local das credenciais via DPAPI.

## Como executar

1. Instale o AutoHotkey v2.
2. Garanta que o WebView2 Runtime esteja instalado.
3. Execute o arquivo principal:

```powershell
AutoHotkey64.exe .\main.ahk
```

Também é possível abrir `main.ahk` diretamente se a associação de arquivos do AutoHotkey v2 estiver configurada no Windows.

## Configuração local

Na primeira execução, a aplicação pode criar `config.ini` ao lado do `main.ahk` para armazenar configurações locais, incluindo credenciais criptografadas com DPAPI do Windows.

Esse arquivo é específico da máquina e está ignorado pelo Git.

## Proteção, autoria e uso restrito

O Praxis é um software proprietário de titularidade declarada de Iago Santana Lima, disponibilizado neste repositório com **todos os direitos reservados**.

O acesso ao código-fonte, documentação, interface, scripts, imagens, versões antigas, builds ou materiais auxiliares não concede licença de uso, cópia, modificação, redistribuição, engenharia reversa, criação de obras derivadas ou exploração comercial.

Qualquer uso autorizado deve ser formalizado por escrito, com definição de cliente, CNPJ, unidade, setor, máquina, usuário, ambiente, finalidade, prazo e versão autorizada.

Para preservação de autoria e rastreabilidade, mantenha versionamento Git, histórico de alterações, datas de publicação, documentação técnica e evidências de criação atualizadas. Para proteção formal no Brasil, considere o registro de programa de computador junto ao INPI antes de distribuição externa ou uso comercial amplo.

## Documentos legais, build e distribuição

Consulte os documentos abaixo:

- `DISTRIBUTION.md` — guia de registro INPI, revisão jurídica, distribuição segura, proteção técnica e geração de build/instalador;
- `LICENSE` — licença proprietária de todos os direitos reservados;
- `COPYRIGHT` — declaração de autoria e titularidade do repositório;
- `NOTICE.md` — aviso de uso restrito e titularidade;
- `EULA.md` — modelo de termo de licença de uso;
- `NDA.md` — modelo de termo de confidencialidade;
- `PRIVACY_LGPD.md` — política operacional de privacidade, segurança e LGPD;
- `THIRD_PARTY_NOTICES.md` — avisos de componentes e bibliotecas de terceiros.

## Componentes de terceiros

O projeto pode utilizar AutoHotkey, Microsoft Edge WebView2, WebView2Loader.dll e bibliotecas AutoHotkey de terceiros. Esses componentes permanecem sujeitos às respectivas licenças e avisos de seus titulares originais.

A licença proprietária do Praxis aplica-se ao código, documentação, interface, scripts, fluxos e materiais próprios do projeto, sem alterar direitos ou obrigações relativos a componentes externos.

## Segurança e LGPD

Por envolver automações em contexto hospitalar, não versionar nem compartilhar credenciais, dados pessoais, dados de pacientes, XMLs reais, logs sensíveis, prints de telas internas, arquivos de configuração, `.env`, `config.ini` ou evidências de debug contendo informações reais.

Antes de usar dados, imagens ou logs em documentação, testes, prompts ou ferramentas de IA, remova informações sensíveis e confirme se há autorização adequada.

## Licença

Consulte `LICENSE`, `COPYRIGHT`, `NOTICE.md`, `EULA.md`, `NDA.md`, `PRIVACY_LGPD.md` e `THIRD_PARTY_NOTICES.md`.
