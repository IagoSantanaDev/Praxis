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
| Automação do MV | AutoHotkey v2 — Send, ControlClick, ImageSearch + Clipboard |
| Credenciais | Windows DPAPI nativo (`CryptProtectData` / `CryptUnprotectData`) |
| Configuração | `config.ini` (IniRead/IniWrite) |

**Dependências para desenvolvimento:**
- AutoHotkey v2 → [autohotkey.com](https://autohotkey.com)
- Ahk2Exe → instalado junto ao AutoHotkey ou pelo instalador oficial
- Inno Setup 6 → necessário para gerar instalador
- WebView2 Runtime → necessário para executar a interface WebView2

Para detalhes de build, assinatura, artefatos e validação, consulte [`docs/DISTRIBUTION.md`](docs/DISTRIBUTION.md).

---

## Estrutura de Arquivos

```
Praxis/
├── main.ahk                   # Entry point: GUI, login, dispatcher
├── config.ini                 # Configuração e credenciais criptografadas
├── lib/
│   ├── WebView2.ahk           # Lib externa (thqby)
│   ├── JSON.ahk               # Lib externa (thqby)
│   ├── Promise.ahk            # Dependência da WebView2.ahk
│   ├── ComVar.ahk             # Dependência da WebView2.ahk
│   ├── 32bit/WebView2Loader.dll
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

1. Copiar pasta `Praxis/` para o computador
2. Criar `config.ini` com:
   ```ini
   [Paths]
   WorkDir=C:\Users\<usuario>\Documents\Praxis
   ```
3. Criar pasta `%DOCUMENTS%\Praxis\XML\`
4. Baixar libs AHK em `lib\`:
   - `WebView2.ahk`, `JSON.ahk`, `Promise.ahk`, `ComVar.ahk`
5. Duplo clique em `main.ahk`

---

## Instalação (Produção)

O pacote de produção é gerado pelo script de build e pelo instalador Inno Setup do projeto.

Para gerar e validar builds, consulte [`docs/DISTRIBUTION.md`](docs/DISTRIBUTION.md).

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
EncryptDPAPI(plainText)  ; CryptProtectData do Windows
DecryptDPAPI(encrypted)  ; CryptUnprotectData do Windows
```
