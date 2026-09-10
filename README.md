# Praxis

Automação de processos de faturamento hospitalar no sistema **MV2000i (Gestão Hospitalar)**. Desenvolvido em AutoHotkey v2 com interface gráfica WebView2 (HTML/CSS/JS).

> Hospital: São Rafael · Desenvolvedor: Iago Santana

---

## Tecnologias

| Componente | Tecnologia |
|---|---|
| Shell da janela | AutoHotkey v2 (`Gui`) |
| Interface UI | WebView2 (Chromium) + HTML/CSS/JS puro |
| Comunicação JS↔AHK | `PostWebMessageAsJson` / `window.chrome.webview.postMessage` |
| Automação do MV | AutoHotkey v2 — Send, ControlClick, OCR local + Clipboard |
| Configuração | Caminhos fixos em `Documentos` |

**Dependências para desenvolvimento:**
- AutoHotkey v2 → [autohotkey.com](https://autohotkey.com)
- Ahk2Exe → ferramenta de build disponível no ambiente de desenvolvimento
- WebView2 Runtime → necessário para executar a interface WebView2

---

## Build e Distribuição

O build E2E é feito por `tools/build-praxis.ps1`. Os comandos mais comuns:

| Comando | Saída |
|---|---|
| `tools\build-praxis.ps1 -Version X.Y.Z` | EXE + distribuição portátil + ZIP |
| `tools\build-praxis.ps1 -Version X.Y.Z -Release` | Build portátil com assinatura e compressão |

Saídas geradas:
- `dist\Praxis-<ver>\stage\Praxis.exe` — EXE compilado (sem .ahk)
- `dist\Praxis-<ver>\distribution\` — pasta portátil
- `dist\Praxis-<ver>\Praxis-Portable-<ver>.zip` — ZIP portátil pronto para uso
- `dist\Praxis-<ver>\Praxis-build-manifest.json` — SHA256 de cada artefato

Validação de integridade em runtime: `Praxis.exe --integrity-check` (exit 0 = OK, 70 = recurso ausente/alterado).

### Release automático (rolling)

A cada push em `main`, o GitHub Actions (`.github/workflows/release.yml`) builda, zipla e publica/atualiza o **GitHub Release** com tag `continuous` (Latest), contendo `Praxis-Portable-<ver>.zip` + `SHA256SUMS.txt`.

Publicação manual local (com `gh auth login`):

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\publish-release.ps1
```

---

## Estrutura de Arquivos

```
Praxis/
├── main.ahk                       # Entry point: shell mínimo com App_Run()
├── cli-check.ahk                  # CLI para --integrity-check (sem GUI)
├── lib/                           # TODO o código de script (AHK v2)
│   ├── app/                       # Estado e bootstrap da aplicação
│   │   ├── App.ahk                # App_Run() e shell WebView2
│   │   ├── AppState.ahk           # Estado global da aplicação
│   │   ├── Dispatcher.ahk         # Bridge AHK ↔ JS (SendToUI)
│   │   └── ScriptRegistry.ahk     # Registry dos 3 módulos de faturamento
│   ├── config/                    # Configuração, segredos e caminhos
│   │   ├── Secrets.ahk            # DPAPI: API key (cache Map())
│   │   └── Paths.ahk              # Documentos, logs e XMLs (cache Map())
│   ├── ui/
│   │   ├── index.html             # Interface WebView2 completa
│   │   ├── UiBridge.ahk           # Ponte WebView2 → AHK (window.chrome.webview)
│   │   └── UiLog.ahk              # Notify/Progress/Done para a UI
│   ├── vendor/                    # Bibliotecas externas (distribuídas)
│   │   ├── WebView2.ahk           # Wrapper WebView2 para AHK v2
│   │   ├── ComVar.ahk             # Variante COM helper (deps WebView2)
│   │   ├── JSON.ahk               # JSON parse/stringify
│   │   ├── Promise.ahk            # Promise/await para AHK v2
│   │   ├── 32bit/WebView2Loader.dll   # WebView2 loader (32-bit)
│   │   └── 64bit/WebView2Loader.dll   # WebView2 loader (64-bit)
│   ├── globals/                   # Módulos globais compartilhados
│   │   ├── mv/                    # Automação MV2000i — screen/component/action
│   │   │   ├── MVConstants.ahk        # Constantes de janelas, timeouts, paths MV
│   │   │   ├── MVSession.ahk          # Login e contexto de sessão MV
│   │   │   ├── MVWindows.ahk          # Helpers de janela MV
│   │   │   ├── FFCV_ErrorTemplates.ahk # Cadastro de erros FFCV via OCR
│   │   │   ├── FFCV_ErrorReferences.json # Referências SHA256 dos erros OCR
│   │   │   ├── screens/              # Telas: Login, MovDoc, FFCV, XML, Popup
│   │   │   ├── components/           # Componentes
│   │   │   └── actions/              # Ações: OpenScreens, CloseScreen, etc.
│   │   └── shared/                  # Utilitários compartilhados
│   │       ├── DateUtils.ahk
│   │       ├── StringUtils.ahk
│   │       └── Validation.ahk
│   └── modules/                  # Scripts por módulo de faturamento
│       ├── remessa_protocolo/    # Download de protocolos MOV DOC → FFCV
│       ├── protocolar/           # Protocolação de contas
│       └── fechar_xml/           # Fechamento e geração TISS XML
├── assets/                       # Recursos externos do aplicativo
│   └── icon.ico                  # Ícone usado pelo EXE e pela UI
├── tools/                        # Scripts de build
│   ├── build-praxis.ps1          # Build E2E da distribuição portátil
│   ├── build-ocr-error-references.ps1 # Regenera FFCV_ErrorReferences.json
│   ├── find-top-level-calls.ps1   # Sanity check anti double-execution (wired into build)
│   └── ocr-probe.ps1             # Prova OCR contra MV (debug)
└── README.md, LICENSE, COPYRIGHT, NOTICE.md   # Documentação e termos legais
```

Arquivos gerados em build (NÃO versionados, em `.gitignore`):
- `build/generated/Praxis_IntegrityManifest.ahk` — hash de todos os artefatos
- `build/generated/Praxis_Ui.ahk` — `ui/index.html` em Base64 (embarcado no EXE)
- `build/generated/Praxis_OcrReferences.ahk` — `FFCV_ErrorReferences.json` em Base64
- `build/generated/Praxis_OcrProbe.ahk` — `ocr-probe.ps1` em Base64
- `dist/Praxis-<ver>/` — pasta de release portátil

---

## Scripts Disponíveis

### 1. Remessa por Protocolo (principal)
**Categoria:** Faturamento

Baixa protocolos no MOV DOC e cria/atualiza remessa no FFCV.

| Parâmetro | Tipo | Obrigatório |
|---|---|---|
| Protocolos | text | Sim |
| Tipo de Conta | select | Sim |
| Remessa Existente | text | Não |
| Data de Entrega | date | Não |
| Data de Vencimento | date | Não |

### 2. Protocolar
**Categoria:** Movimentação · Stub — fluxo pendente de detalhamento

### 3. Fechar e Gerar XML
**Categoria:** Faturamento · Stub — fluxo pendente de detalhamento

---

## Instalação (Desenvolvimento)

1. Clonar ou copiar a pasta `Praxis/` para qualquer diretório
2. Duplo clique em `main.ahk` ou execute o EXE compilado
3. Os logs serão gravados em `%USERPROFILE%\Documents\Praxis`
4. Os XMLs serão gravados em `%USERPROFILE%\Documents\XML`

> **Nota:** As bibliotecas externas (p.ex. `lib/vendor/WebView2.ahk`) já estão incluídas no repositório — não é necessário baixá-las manualmente.

---

## Execução (Produção)

O pacote de produção é portátil: extraia `Praxis-Portable-<versão>.zip` em qualquer diretório e execute `Praxis.exe`. O pacote não instala arquivos, não cria atalhos e não depende de Inno Setup.

Os logs ficam em `%USERPROFILE%\Documents\Praxis`. A planilha de envio fica em `%USERPROFILE%\Documents\Envio.CSV`. Os XMLs TISS são gravados em `%USERPROFILE%\Documents\XML`. O WebView2 Runtime continua sendo um pré-requisito do Windows para a interface.

---

## Interface

- **Janela:** 750×540px (redimensionável, mínimo 640×460)
- **App:** sidebar com módulos por categoria + formulário dinâmico + log + barra de progresso
- **Comunicação:** bidirecional AHK↔JS via WebView2

---

## Notas Técnicas — Oracle Forms 6i

O MV2000i roda sobre **Oracle Forms 6i (`ifrun60.EXE`)**.

### Funciona bem
- `WinExist`, `WinActivate`, `WinWaitActive`
- `ControlClick` com **ClassNN**
- `Send` (teclado: F7, F8, F10, Tab, Enter, setas)
- `WinGetText` em popups modais
- OCR local do Windows (`Windows.Media.Ocr`) na área client dos popups de erro

### Não confiável sozinho
- `ControlSetText`/`ControlGetText` para campos de texto do Forms
- Window Spy para identificar campos por ClassNN único (muitos campos compartilham `Edit2`, etc.)
- Coordenadas de tela (variam por monitor, resolução, escala)

### Estratégia para campos de texto
1. **Teclado** como caminho principal (SendText, Tab, Enter, F6/F7/F8/F10)
2. **HWND por ClassNN + coordenada Client** como fallback
3. **Clipboard** para leitura: double-click → `Ctrl+C`

### D006 — Exceção lib/vendor/ no .gitignore

A pasta `lib/vendor/` é **distribuída** no pacote de produção (contém `WebView2.ahk`, necessária em runtime). O `.gitignore` padrão ignora `vendor/` por convenção upstream; por isso, as negações explícitas `!lib/vendor/32bit/` e `!lib/vendor/64bit/` garantem que as DLLs WebView2Loader sejam rastreadas e incluídas no pacote portátil, sem serem silenciadas por padrões genéricos upstream.

---

## Padrões do Projeto

```autohotkey
; Polling (em vez de Sleep fixo)
MV_Poll(condFn, timeoutSecs)

; Leitura de campo via clipboard
MV_ReadAt(winTitle, cx, cy)

```
