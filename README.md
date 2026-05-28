# RPA MV2000i

Automação de processos de faturamento hospitalar no sistema **MV2000i (Gestão Hospitalar)**. Desenvolvido em AutoHotkey v2 com interface gráfica WebView2 (HTML/CSS/JS).

> Hospital: São Rafael · Desenvolvedor: Iago Santana

---

## Tecnologias

| Componente | Tecnologia |
|---|---|
| Shell da janela | AutoHotkey v2 (`Gui`) |
| Interface UI | WebView2 (Chromium) + HTML/CSS/JS puro |
| Comunicação JS↔AHK | `PostWebMessageAsJson` / `window.chrome.webview.postMessage` |
| Automação do MV | AutoHotkey v2 — Send, ControlClick, ImageSearch + Clipboard |
| Credenciais | Windows DPAPI via PowerShell |
| Configuração | `config.ini` (IniRead/IniWrite) |

**Dependências externas (baixar manualmente):**
- `WebView2.ahk`, `JSON.ahk` → [github.com/thqby/ahk2_lib](https://github.com/thqby/ahk2_lib)
- AutoHotkey v2 → [autohotkey.com](https://autohotkey.com)
- WebView2 Runtime → já presente no Windows 10/11 atualizado

---

## Estrutura de Arquivos

```
RPA MV2000i/
├── main.ahk                   # Entry point: GUI, login, dispatcher
├── config.ini                 # Configuração e credenciais criptografadas
├── lib/
│   ├── WebView2.ahk           # Lib externa (thqby)
│   ├── JSON.ahk               # Lib externa (thqby)
│   ├── Promise.ahk            # Dependência da WebView2.ahk
│   ├── ComVar.ahk             # Dependência da WebView2.ahk
│   └── 64bit/WebView2Loader.dll
├── scripts/
│   ├── mv_session.ahk         # Login MV, abertura de módulos, polling
│   ├── remessa_protocolo.ahk  # Script principal
│   ├── protocolar.ahk        # Stub
│   └── fechar_xml.ahk        # Stub
├── ui/
│   └── index.html             # Interface completa (login + app)
└── images/                    # Somente imagens realmente usadas pelos macros
```

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

1. Copiar pasta `RPA MV2000i/` para o computador
2. Criar `config.ini` com:
   ```ini
   [Paths]
   WorkDir=C:\Users\<usuario>\Documents\RPA MV2000i
   ```
3. Criar pasta `%DOCUMENTS%\RPA MV2000i\XML\`
4. Baixar libs AHK em `lib\`:
   - `WebView2.ahk`, `JSON.ahk`, `Promise.ahk`, `ComVar.ahk`
5. Duplo clique em `main.ahk`

---

## Instalação (Produção)

Script Inno Setup 6 (`installer.iss`):
- Instala em `%LOCALAPPDATA%\RPA MV2000i\` (sem admin)
- Cria `%DOCUMENTS%\RPA MV2000i\XML\` automaticamente
- Grava `WorkDir` no `config.ini`
- Cria atalhos no Menu Iniciar e Área de Trabalho

---

## Interface

- **Janela:** 750×540px (redimensionável, mínimo 640×460)
- **Login:** estilo da tela de login do MV2000i
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
- `ImageSearch` com `*TransFFFFFF *10` para menus

### Não confiável sozinho
- `ControlSetText`/`ControlGetText` para campos de texto do Forms
- Window Spy para identificar campos por ClassNN único (muitos campos compartilham `Edit2`, etc.)
- Coordenadas de tela (variam por monitor, resolução, escala)

### Estratégia para campos de texto
1. **Teclado** como caminho principal (SendText, Tab, Enter, F6/F7/F8/F10)
2. **HWND por ClassNN + coordenada Client** como fallback
3. **Clipboard** para leitura: double-click → `Ctrl+C`

---

## Padrões do Projeto

```autohotkey
; Polling (em vez de Sleep fixo)
MV_Poll(condFn, timeoutSecs)

; Leitura de campo via clipboard
MV_ReadAt(winTitle, cx, cy)

; Credenciais DPAPI
EncryptDPAPI(plainText)  ; PowerShell ConvertFrom-SecureString
DecryptDPAPI(encrypted)
```