# Praxis

Automação para processos de faturamento hospitalar no sistema **MV2000i (Gestão Hospitalar)**. O projeto foi desenvolvido em AutoHotkey v2 e usa uma interface desktop em WebView2 com HTML, CSS e JavaScript.

> Hospital: São Rafael · Desenvolvedor: Iago Santana

---

## Visão geral

O Praxis automatiza etapas recorrentes do fluxo faturamento hospitalar, com foco em leitura de telas, interação com o MV2000i e geração de documentos e arquivos XML. A solução combina automação de teclado, OCR local, manipulação de janelas e uma interface leve para acompanhar o processo em execução.

## Tecnologias

| Componente | Tecnologia |
|---|---|
| Shell da janela | AutoHotkey v2 (`Gui`) |
| Interface UI | WebView2 (Chromium) + HTML/CSS/JS puro |
| Comunicação JS ↔ AHK | `PostWebMessageAsJson` / `window.chrome.webview.postMessage` |
| Automação do MV | AutoHotkey v2 — `Send`, `ControlClick`, OCR local e clipboard |
| Configuração | Caminhos fixos em `Documentos` |

Dependências de desenvolvimento:

- AutoHotkey v2 → [autohotkey.com](https://autohotkey.com)
- Ahk2Exe → ferramenta usada para compilar o executável
- WebView2 Runtime → necessário para executar a interface em desktop

---

## Build e distribuição

O build completo é executado por `tools/build-praxis.ps1`. Os comandos mais usados são estes:

| Comando | Resultado |
|---|---|
| `tools\build-praxis.ps1 -Version X.Y.Z` | gera EXE, pasta portátil e ZIP |
| `tools\build-praxis.ps1 -Version X.Y.Z -Release` | build com assinatura e compressão |

Artefatos gerados:

- `dist\Praxis-<ver>\stage\Praxis.exe` — executável compilado sem arquivos `.ahk`
- `dist\Praxis-<ver>\distribution\` — pasta portátil
- `dist\Praxis-<ver>\Praxis-Portable-<ver>.zip` — pacote pronto para uso
- `dist\Praxis-<ver>\Praxis-build-manifest.json` — hashes SHA256 dos artefatos

A validação de integridade em runtime é feita com `Praxis.exe --integrity-check`. O retorno `0` indica integridade válida, e `70` indica que algum recurso está ausente ou alterado.

### Release automático

A cada push na branch `main`, o GitHub Actions em `.github/workflows/release.yml` compila o projeto, gera o ZIP e publica ou atualiza o release no GitHub com tag `continuous` (Latest), incluindo `Praxis-Portable-<ver>.zip` e `SHA256SUMS.txt`.

Publicação manual local, após `gh auth login`:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\publish-release.ps1
```

---

## Estrutura de arquivos

```text
Praxis/
├── main.ahk                          # ponto de entrada com shell mínimo e App_Run()
├── cli-check.ahk                     # CLI para --integrity-check sem interface gráfica
├── lib/                              # código principal em AHK v2
│   ├── app/                          # estado e bootstrap da aplicação
│   │   ├── App.ahk                   # App_Run() e shell WebView2
│   │   ├── AppState.ahk              # estado global da aplicação
│   │   ├── Dispatcher.ahk            # ponte AHK ↔ JS (SendToUI)
│   │   └── ScriptRegistry.ahk        # registro dos módulos de faturamento
│   ├── config/                       # configuração e caminhos
│   │   ├── Secrets.ahk               # DPAPI: API key em cache Map()
│   │   └── Paths.ahk                 # documentos, logs e XMLs em cache Map()
│   ├── ui/
│   │   ├── index.html                # interface WebView2
│   │   ├── UiBridge.ahk              # ponte WebView2 → AHK (window.chrome.webview)
│   │   └── UiLog.ahk                 # notificações, progresso e conclusão para a UI
│   ├── vendor/                       # bibliotecas externas e runtime distribuído
│   │   ├── WebView2.ahk              # wrapper WebView2 para AHK v2
│   │   ├── ComVar.ahk                # helper COM para WebView2
│   │   ├── JSON.ahk                  # parse/stringify JSON
│   │   ├── Promise.ahk               # promise/await para AHK v2
│   │   ├── 32bit/WebView2Loader.dll  # loader WebView2 32-bit
│   │   └── 64bit/WebView2Loader.dll  # loader WebView2 64-bit
│   ├── globals/                      # módulos compartilhados
│   │   ├── mv/                       # automação MV2000i — telas, componentes e ações
│   │   │   ├── MVConstants.ahk       # janelas, timeouts e caminhos do MV
│   │   │   ├── MVSession.ahk         # login e contexto de sessão
│   │   │   ├── MVWindows.ahk         # helpers de janela
│   │   │   ├── FFCV_ErrorTemplates.ahk # template de erros FFCV via OCR
│   │   │   ├── FFCV_ErrorReferences.json # referências SHA256 dos erros OCR
│   │   │   ├── screens/             # telas: Login, MovDoc, FFCV, XML e popup
│   │   │   ├── components/          # componentes do MV
│   │   │   └── actions/             # ações gerais da automação
│   │   └── shared/                  # utilitários compartilhados
│   │       ├── DateUtils.ahk
│   │       ├── StringUtils.ahk
│   │       └── Validation.ahk
│   └── modules/                      # módulos por funcionalidade
│       ├── remessa_protocolo/       # download de protocolos MOV DOC → FFCV
│       ├── protocolar/              # protocolação de contas
│       └── fechar_xml/              # fechamento e geração de XML TISS
├── assets/                          # recursos do aplicativo
│   └── icon.ico                     # ícone multi-resolução usado por EXE e UI
├── tools/                           # scripts de build e suporte
│   ├── build-praxis.ps1             # build completo da distribuição
│   ├── build-ocr-error-references.ps1 # gera FFCV_ErrorReferences.json
│   ├── find-top-level-calls.ps1     # checagem anti execução duplicada
│   └── ocr-probe.ps1                # prova OCR contra o MV em debug
├── README.md, LICENSE, COPYRIGHT, NOTICE.md  # documentação e termos legais
```

Arquivos gerados durante o build e que não ficam versionados em `.gitignore`:

- `build/generated/Praxis_IntegrityManifest.ahk` — hash de todos os artefatos
- `build/generated/Praxis_Ui.ahk` — `ui/index.html` codificado em Base64 e embutido no EXE
- `build/generated/Praxis_OcrReferences.ahk` — `FFCV_ErrorReferences.json` em Base64
- `build/generated/Praxis_OcrProbe.ahk` — `ocr-probe.ps1` em Base64
- `dist/Praxis-<ver>/` — pasta de release portátil

---

## Módulos disponíveis

### 1. Remessa por protocolo (principal)
**Categoria:** faturamento

Esse fluxo baixa protocolos no MOV DOC e cria ou atualiza a remessa no FFCV.

| Parâmetro | Tipo | Obrigatório |
|---|---|---|
| Protocolos | texto | Sim |
| Tipo de Conta | seleção | Sim |
| Remessa Existente | texto | Não |
| Data de Entrega | data | Não |
| Data de Vencimento | data | Não |

### 2. Protocolar
**Categoria:** movimentação

Move contas de uma ou mais remessas de um setor para outro no MV2000i. O fluxo valida a origem e o destino, gera o CSV de contas, abre a tela de envio, envia cada conta, trata popups de usuário e pode finalizar a operação com impressão/salvamento do envio.

| Parâmetro | Tipo | Obrigatório |
|---|---|---|
| Remessas | texto | Sim |
| Setor Atual | texto | Sim |
| Setor de Envio | texto | Sim |
| Tipo de Atendimento | seleção | Sim |
| Finalizar Envio | checkbox | Não |
| Uma Remessa = Um Protocolo | checkbox | Não |

Esse módulo é usado para transferir o lote de contas para o setor de destino e concluir o processamento do protocolo operacional.

### 3. Fechar e gerar XML
**Categoria:** faturamento

Fecha remessas no FFCV e, opcionalmente, gera o arquivo XML TISS correspondente. A rotina confirma a entrega da remessa, aceita data de entrega e vencimento quando informado, executa a etapa de fechamento e produz o XML gerado para o lote no formato do sistema de faturamento.

| Parâmetro | Tipo | Obrigatório |
|---|---|---|
| Remessas | texto | Sim |
| Data de Entrega | data | Não |
| Data de Vencimento | data | Não |
| Fechar Remessa | checkbox | Não |
| Gerar XML | checkbox | Não |

Esse fluxo cobre a etapa final do ciclo de faturamento: encerramento documental da remessa e geração do XML para exportação/encaminhamento.

---

## Instalação para desenvolvimento

1. Clone ou copie a pasta `Praxis/` para qualquer diretório local.
2. Abra `main.ahk` ou execute o executável compilado.
3. Os logs ficam em `%USERPROFILE%\Documents\Praxis`.
4. Os XMLs são gravados em `%USERPROFILE%\Documents\XML`.

> As bibliotecas externas, como `lib/vendor/WebView2.ahk`, já vêm no repositório. Não é preciso baixá-las manualmente.

---

## Execução em produção

O pacote de produção é portátil. Basta extrair `Praxis-Portable-<versão>.zip` em qualquer pasta e executar `Praxis.exe`. Ele não instala arquivos no sistema, não cria atalhos e não depende de Inno Setup.

Os logs ficam em `%USERPROFILE%\Documents\Praxis`. A planilha de envio fica em `%USERPROFILE%\Documents\Envio.CSV`. Os XMLs TISS são gravados em `%USERPROFILE%\Documents\XML`. O WebView2 Runtime continua sendo um pré-requisito do Windows para a interface.

---

## Interface

- **Janela:** 750 × 540 px, redimensionável, com mínimo de 640 × 460
- **Aplicativo:** sidebar por categoria, formulário dinâmico, log e barra de progresso
- **Comunicação:** bidirecional AHK ↔ JS via WebView2

---

## Notas técnicas — Oracle Forms 6i

O MV2000i roda sobre **Oracle Forms 6i (`ifrun60.EXE`)**.

### Funciona bem

- `WinExist`, `WinActivate`, `WinWaitActive`
- `ControlClick` com **ClassNN**
- `Send` para teclado: F7, F8, F10, Tab, Enter e setas
- `WinGetText` em popups modais
- OCR local do Windows (`Windows.Media.Ocr`) na área client dos popups de erro

### Estratégia para campos de texto

1. **Teclado** como caminho principal: `SendText`, `Tab`, `Enter`, `F6`, `F7`, `F8`, `F10`
2. **HWND por ClassNN + coordenada client** como fallback
3. **Clipboard** para leitura: clique duplo e `Ctrl+C`
