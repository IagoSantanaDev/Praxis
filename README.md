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
| Configuração | `config.ini` (IniRead/IniWrite) |

**Dependências para desenvolvimento:**
- AutoHotkey v2 → [autohotkey.com](https://autohotkey.com)
- Ahk2Exe → instalado junto ao AutoHotkey ou pelo instalador oficial
- Inno Setup 6 → necessário para gerar instalador
- WebView2 Runtime → necessário para executar a interface WebView2

---

## Build e Distribuição

O build E2E é feito por `tools/build-praxis.ps1`. Os comandos mais comuns:

| Comando | Saída |
|---|---|
| `tools\build-praxis.ps1 -Version X.Y.Z` | `dist\Praxis-X.Y.Z\stage\Praxis.exe` + instalador |
| `tools\build-praxis.ps1 -Version X.Y.Z -SkipInstaller` | Apenas EXE + distribuição portátil |
| `tools\build-praxis.ps1 -Version X.Y.Z -Release` | Build com assinatura, compressão e instalador |

Saídas geradas:
- `dist\Praxis-<ver>\stage\Praxis.exe` — EXE compilado (sem .ahk)
- `dist\Praxis-<ver>\distribution\` — pasta portátil (sem instalador)
- `dist\Praxis-<ver>\installer\Praxis-Setup-<ver>.exe` — instalador Inno Setup
- `dist\Praxis-<ver>\delivery\` — pacote sanitizado final
- `dist\Praxis-<ver>\Praxis-build-manifest.json` — SHA256 de cada artefato

Validação de integridade em runtime: `AutoHotkey64.exe main.ahk --integrity-check` (exit 0 = OK).

---

## Estrutura de Arquivos

```
Praxis/
├── main.ahk                       # Entry point: shell mínimo com App_Run()
├── cli-check.ahk                  # CLI para --integrity-check (sem GUI)
├── config.ini                     # Configuração local (gerado pelo instalador)
├── lib/                           # TODO o código de script (AHK v2)
│   ├── app/                       # Estado e bootstrap da aplicação
│   │   ├── App.ahk                # App_Run() e shell WebView2
│   │   ├── AppState.ahk           # Estado global da aplicação
│   │   ├── Dispatcher.ahk         # Bridge AHK ↔ JS (SendToUI)
│   │   └── ScriptRegistry.ahk     # Registry dos 3 módulos de faturamento
│   ├── config/                    # Configuração, segredos e caminhos
│   │   ├── Secrets.ahk            # DPAPI: API key (cache Map())
│   │   ├── Settings.ahk           # IniRead/IniWrite: config.ini (cache Map())
│   │   └── Paths.ahk              # WorkDir, XML dir (cache Map())
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
├── installer/                    # Inno Setup
│   ├── Praxis.iss                # Script do instalador
│   └── assets/                   # Ícone e banners do wizard
├── tools/                        # Scripts de build
│   ├── build-praxis.ps1          # Build E2E (EXE + instalador + delivery)
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
- `dist/Praxis-<ver>/` — pasta de release com EXE, instalador e delivery

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

1. Clonar ou copiar pasta `Praxis/` para o computador
2. Criar `config.ini` com:
   ```ini
   [Paths]
   WorkDir=C:\Users\<usuario>\Documents\Praxis
   ```
3. Criar pasta `%DOCUMENTS%\Praxis\XML\`
4. Duplo clique em `main.ahk`

> **Nota:** As bibliotecas externas (p.ex. `lib/vendor/WebView2.ahk`) já estão incluídas no repositório — não é necessário baixá-las manualmente.

---

## Instalação (Produção)

O pacote de produção é gerado pelo script de build e pelo instalador Inno Setup do projeto. Para testes controlados, o build também cria a pasta `dist\Praxis-<versão>\delivery\` com o instalador e os documentos legais, e a pasta `dist\Praxis-<versão>\distribution\` com a versão portátil para computadores que não aceitam instalador, sem expor `.ahk`, `.ps1`, `.html` ou `.json`.

Para gerar e validar builds, consulte a seção [Build e Distribuição](#build-e-distribuição) acima.

O instalador:
- instala em `%LOCALAPPDATA%\Programs\Praxis\` sem exigir privilégios elevados por padrão;
- cria `%DOCUMENTS%\Praxis\` automaticamente;
- grava `WorkDir` no `config.ini`;
- cria atalhos no Menu Iniciar e, opcionalmente, na Área de Trabalho;
- instala os recursos de runtime necessários do Praxis;
- tenta instalar o Microsoft Edge WebView2 Runtime se ele não estiver presente.

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

A pasta `lib/vendor/` é **distribuída** no pacote de produção (contém `WebView2.ahk`, necessária em runtime). O `.gitignore` padrão ignora `vendor/` por convenção upstream; por isso, as negações explícitas `!lib/vendor/32bit/` e `!lib/vendor/64bit/` garantem que as DLLs WebView2Loader sejam rastreadas e incluídas no instalador, sem ser silenciadas por padrões genéricos upstream.

---

## Padrões do Projeto

```autohotkey
; Polling (em vez de Sleep fixo)
MV_Poll(condFn, timeoutSecs)

; Leitura de campo via clipboard
MV_ReadAt(winTitle, cx, cy)

```
