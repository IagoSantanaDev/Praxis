# RPA MV2000i — Relatório de Contexto e Conhecimento

> Gerado em: 18/05/2026<br>
> Hospital: Hospital São Rafael<br>
> Desenvolvedor: Iago<br>
> Ambiente: Windows / WSL2, AHK v2

---

## 1. Visão Geral do Projeto

RPA comercial para automação de processos de faturamento hospitalar no sistema **MV2000i (Gestão Hospitalar)**. O produto é vendido para o hospital e instalado por usuário (sem admin). A interface gráfica é uma janela própria construída com **AHK v2 + WebView2 + HTML/CSS/JS**. Os scripts de automação interagem diretamente com o MV2000i via AHK.

---

## 2. Tecnologia

### 2.1 Interface do RPA
| Componente | Tecnologia |
|---|---|
| Shell da janela | AutoHotkey v2 (`Gui`) |
| UI renderizada | WebView2 (Chromium embutido) |
| Frontend | HTML + CSS + JavaScript puro |
| Comunicação bidirecional | `PostWebMessageAsJson` (AHK→JS) / `window.chrome.webview.postMessage` (JS→AHK) |
| Serialização | JSON via `thqby/JSON.ahk` |

### 2.2 Automação
| Item | Detalhe |
|---|---|
| Linguagem | AutoHotkey v2.0 |
| Runtime do MV | `ifrun60.EXE` (Oracle Forms 6i) |
| Interação com UI | `Send`, `ControlClick`, `ImageSearch` + Clipboard |
| Armazenamento de credenciais | Windows DPAPI via PowerShell |
| Configuração | `config.ini` (leitura/escrita via `IniRead`/`IniWrite`) |

### 2.3 Dependências externas (baixar manualmente)
- `WebView2.ahk` — github.com/thqby/ahk2_lib
- `JSON.ahk` — github.com/thqby/ahk2_lib
- AutoHotkey v2 — autohotkey.com
- WebView2 Runtime — já presente no Windows 10/11 atualizado

---

## 3. Oracle Forms 6i — Comportamento Confirmado

O MV2000i roda sobre **Oracle Forms 6i via `ifrun60.EXE`**. Isso tem implicações diretas na automação:

### O que funciona
- `WinExist`, `WinActivate`, `WinWaitActive` — janela principal é Windows normal
- `ControlClick` com **ClassNN** — botões são expostos como controles Windows
- `Send` — teclado funciona normalmente (F7, F8, F10, Tab, Enter, setas)
- `WinGetText` — retorna texto de popups modais (mesmo que o Window Spy não mostre)
- `ImageSearch` — para navegar menus e campos sem ClassNN único

### O que NÃO é confiável sozinho
- `ControlSetText` / `ControlGetText` para campos de texto do Forms — podem funcionar em alguns controles, mas não devem ser a única estratégia
- Window Spy para identificar textfields por ClassNN único — muitos campos compartilham o mesmo ClassNN (`Edit2`, `Edit3`, etc.)
- Coordenadas `Screen` — variam por monitor, resolução, escala e posição da janela
- Tab para navegar entre seções de tela — só é confiável quando o foco inicial e a ordem de tabulação foram validados

### Estratégia adotada para campos de texto
1. **Caminho preferido quando o foco é previsível:** teclado (`SendText`, `Tab`, `Enter`, teclas F6/F7/F8/F10).
2. **Caminho robusto para campos duplicados:** localizar HWND por `ClassNN + coordenada Client` e então usar `ControlSetText`, `ControlFocus`, `ControlClick` ou `ControlSend` no HWND.
3. **Leitura de campos Oracle Forms:** double-click para selecionar → `Ctrl+C` → ler `A_Clipboard`.
4. **Leitura de grid:** selecionar primeira célula → copiar → seta para baixo → repetir até popup/estado de fim.

### Estratégia para botões de menu (dropdowns em cascata)
- `ImageSearch` com PNG do texto do item de menu
- `*TransFFFFFF *10` como prefixo no ImageSearch — branco transparente + tolerância 10 para anti-aliasing
- Crop mínimo do texto, sem bordas

---

## 4. Estrutura de Arquivos

```
RPA MV2000i/
├── main.ahk                          ← Entry point: GUI, login, dispatcher
├── rpa.md                            ← Documento de contexto operacional
├── config.ini                        ← Configuração e credenciais criptografadas (gerado/local)
├── lib/
│   ├── WebView2.ahk                  ← Lib externa thqby
│   ├── JSON.ahk                      ← Lib externa thqby
│   ├── Promise.ahk                   ← Dependência da WebView2.ahk
│   ├── ComVar.ahk                    ← Dependência da WebView2.ahk
│   └── 64bit/WebView2Loader.dll      ← Loader nativo WebView2 usado pelo AHK 64-bit
├── scripts/
│   ├── mv_session.ahk                ← Login, abertura de módulos, polling e utilitários MV
│   ├── remessa_protocolo.ahk         ← Script principal (Remessa por Protocolo)
│   ├── protocolar.ahk                ← Script: Protocolar (validação/stub)
│   └── fechar_xml.ahk                ← Script: Fechar e Gerar XML (validação/stub)
├── test_macros/
│   ├── _mv_control_probe.ahk         ← Biblioteca para testar HWND + ClassNN + coordenada Client
│   ├── 01_login_identificacao.ahk    ← Mini macro de teste de login
│   └── 02..07_*.ahk                  ← Mini macros por tela do Remessa por Protocolo
├── ui/
│   └── index.html                    ← Interface completa (login + app)
└── Imagens_Debug/
    ├── Tittle_*.png                  ← Prints de títulos/janelas do Window Spy
    ├── ClassNN_*.png                 ← Prints de ClassNN/controles do Window Spy
    ├── Menu_*.png                    ← Recortes de menus para navegação visual
    └── Botão_*.png                   ← Recortes de botões/estados visuais
```

---

## 5. Window Spy — Dados Mapeados

### 5.1 Janela de Login (Identificação)

| Item | Valor |
|---|---|
| **Title** | `Identificação` |
| **ahk_class** | `ui60Modal_W32` |
| **ahk_exe** | `ifrun60.EXE` |
| Campo Usuário | ClassNN: `Edit2` — Client: x:147 y:108 w:98 h:17 |
| Campo Senha | ClassNN: `Edit2` — Client: x:269 y:108 w:101 h:17 |
| Botão Confirma | ClassNN: `Button1` (a confirmar) |
| Fundo (canvas) | ClassNN: `ui60Drawn_W321` |

> **Decisão atual:** no login do MV, preferir fluxo 100% por teclado, porque o campo Usuário já abre focado: enviar usuário → `Tab` → enviar senha → `Enter`. A diferenciação por HWND + coordenada Client fica como técnica de fallback/teste para campos duplicados, não como caminho principal do login.

> **Atenção:** Usuário e Senha compartilham ClassNN `Edit2`. Se for necessário endereçar por controle, localizar o HWND por `ClassNN + coordenada Client`, nunca por coordenada de tela.

---

### 5.2 MOVDOC — Aplicativo

| Item | Valor |
|---|---|
| **Executável** | `ifrun60.EXE E:\mv2000\movdoc\movdoc.fmx` |
| **Start in** | `E:\mv2000\movdoc` |
| **Janela principal** | `Movimentação de Documentos - [Menu Principal - HOSPITAL SAO RAFAEL]` |
| **ahk_class** | `ui60MDIroot_W32` |

#### Tela: Baixa de Documentos (Protocolação)

| Item | Valor |
|---|---|
| **Title** | `Movimentação de Documentos - [Protocolação de Baixa de Documentos - HOSPITAL SAO RAFAEL]` |
| **ahk_class** | `ui60MDIroot_W32` |
| Checkbox "Recebido" (1ª linha) | ClassNN: `Button1` — Text: *(vazio)* — Client: x:718 y:359 w:19 h:23 |
| Botão "1 - Imprimir Registro de Baixa" | ClassNN: a confirmar (barra azul no rodapé) |
| **Popup fim do grid** | Title: `Forms` — ahk_class: `ui60Modal_W32` |
| └─ Mensagem | `FRM-40352: Último registro da consulta recuperado.` |
| └─ Botão OK | ClassNN: `Button1` — Client: x:181 y:61 w:38 h:26 |
| **Popup de erro genérico** | Title: `Mensagem do MV2000` — ahk_class: `ui60Modal_W32` |
| └─ Botão OK | ClassNN: `Button1` — Text: `&OK` |

#### Grid "Documentos" — Estrutura de colunas

| Coluna | Conteúdo |
|---|---|
| Documento | Tipo (ex: 11) |
| Atendimento | Código de atendimento |
| **Conta** | Número da conta ← **coletar** |
| Remessa | Número da remessa |
| Data | Data |
| Hora | Hora |
| **Convênio** | Código numérico (ex: 944) ← **coletar** |
| Convênio (nome) | Descrição (ex: CNU - ESPECIAL E) |
| Movimento | Checkbox |
| Devolvido | Checkbox |
| Recebido | Checkbox |

#### Navegação de menus no MOVDOC

```
Menu bar: Lançamentos | Manutenção | Tabelas | Configurações | Solicitações | Consultas | Relatórios | Enviar/Receber Mensagem | Ajuda
└── Lançamentos
    ├── Baixa de Documentos        ← imagem: Menu_Baixa.png
    ├── Protocolação de Documentos ← imagem: Menu_Protocolação.png
    └── Envio de Documentos        ← imagem: Menu_Envio.png
```

---

### 5.3 FFCV — Aplicativo

| Item | Valor |
|---|---|
| **Executável** | `ifrun60.EXE E:\Mv2000\ffcv\ffcv.fmx` |
| **Start in** | `E:\mv2000\ffcv` |
| **ahk_class** | `ui60MDIroot_W32` |

#### Tela: Manutenção de Remessas

| Item | Valor |
|---|---|
| **Title** | `MV2000i - Faturamento - [WIN_PRINCIPAL - HOSPITAL SAO RAFAEL]` |
| Botão "1 - Inserir Conta" | ClassNN: `Button10` — Text: `&1 - Inserir Conta` — Client: x:24 y:458 w:98 h:25 |
| Botão "5 - Entregar Rem." | ClassNN: `Button6` — Text: `&5 - Entregar Rem.` — Client: x:464 y:458 w:98 h:25 |
| Botão "6 - Relatório Atend." | ClassNN: `Button7` — Text: `&6 - Relatório Atend.` — Client: x:567 y:458 w:98 h:25 |
| Botão Sair (toolbar) | ClassNN: `ui60Viewcore_W329` — Client: x:563 y:5 w:23 h:23 |

#### Tela: Entrega de Remessas

| Item | Valor |
|---|---|
| **Title** | `MV2000i - Faturamento - [Cadastro: Faturas e Remessas - ###...]` |
| **ahk_class** | `ui60MDIroot_W32` |
| Botão "1 - Confirma a Entrega da Remessa" | ClassNN: `Button10` — Text: `&1 - Confirma a Entrega da Remessa` — Client: x:30 y:426 w:177 h:25 |
| Checkbox "Fechar contas sem imprimir faturas" | ClassNN: `Button3` — Text: `Fechar contas sem imprimir faturas` — Client: x:541 y:242 w:195 h:15 |

#### Tela: Monitoração de Faturamento - TISS

| Item | Valor |
|---|---|
| **Title** | `MV2000i - Faturamento - [ Monitoração de Faturamento - TISS - ###...]` |
| **ahk_class** | `ui60MDIroot_W32` |
| Botão "1 Faturamento" | ClassNN: `Button7` — Text: `&1 Faturamento` — Client: x:12 y:446 w:85 h:25 |

#### Tela: XML Gerado

| Item | Valor |
|---|---|
| **Title** | `MV2000i - Faturamento - [WIN_PRINCIPAL]` |
| **ahk_class** | `ui60MDIroot_W32` |
| Campo caminho (Edit1) | ClassNN: `Edit1` — Text inicial: `C:\` — Client: x:74 y:455 w:455 h:18 |
| Botão "Visualizar XML" | ClassNN: `Button4` — Text: `Visualizar XML` — Client: x:571 y:455 w:100 h:25 |
| Botão "Voltar" | ClassNN: `Button7` — Text: `Voltar` — Client: x:676 y:455 w:100 h:25 |
| Botão "Salvar_XML" | ClassNN: a confirmar |
| Botão "Sair" | ClassNN: a confirmar |
| Canvas principal | ClassNN: `ui60Drawn_W326` |

#### Popup: XML gerado com sucesso

| Item | Valor |
|---|---|
| **Title** | `Mensagem ao Usuário do MV 2000` |
| **ahk_class** | `ui60Modal_W32` |
| Mensagem | `Arquivo ENVIO_LOTE_GUIAS_doc_XXXXX_id_XXXXXXX.xml gerado com sucesso. Deseja visualiza-lo?` |
| Botão "Não" | ClassNN: `Button2` — Text: `&Não` — Client: x:152 y:76 w:44 h:26 |
| Botão "Sim" | ClassNN: `Button1` (a confirmar) |

#### Diálogo: Relatório de Atendimentos da Remessa

| Item | Valor |
|---|---|
| **Title** | `Relatório de Atendimentos da Remessa` |
| **ahk_class** | `ui60Modal_W32` |
| Botão "Imprimir" | ClassNN: `Button2` — Text: `&Imprimir` — Client: x:74 y:252 w:150 h:26 |
| Botão "Sair" | ClassNN: a confirmar |

#### Navegação de menus no FFCV

```
Menu bar: Lançamentos | Solicitações | Tabelas | Comercial | Importações | Configurações | Consultas | Relatórios | Sair | Enviar/Receber Mensagem | Ajuda
└── Manutenção
    ├── Manutenção de Remessa          ← imagem: Menu_Remessa.png
    ├── Entrega de Remessas            ← imagem: Menu_Entrega.png
    └── Monitoração de Faturamento - TISS ← imagem: Menu_TISS.png
```

---

## 6. Imagens para ImageSearch

Todos os arquivos ficam em `Imagens_Debug/`. Usar sempre com prefixo `*TransFFFFFF *10` para ignorar fundo branco e tolerar anti-aliasing quando o recorte tiver fundo branco.

```autohotkey
; Padrão de uso
ImageSearch &x, &y, 0, 0, A_ScreenWidth, A_ScreenHeight,
    "*TransFFFFFF *10 " . A_ScriptDir . "\Imagens_Debug\nome_imagem.png"
```

| Arquivo | Conteúdo | Uso |
|---|---|---|
| `Conta.png` | Texto "Conta" | Referência visual da coluna Conta |
| `Convênio.png` | Texto "Convênio" | Referência visual do campo/coluna Convênio |
| `GridContasMOVDOC.png` | Recorte do grid de contas | Validar estrutura do grid MOVDOC |
| `GridContasMOVDOCCompleto.png` | Tela maior do grid MOVDOC | Referência de layout da baixa |
| `Menu_Manutenção.png` | "Manutenção" | Abrir dropdown de manutenção |
| `Menu_Baixa.png` | "Baixa de Documentos" | Navegar para baixa no MOVDOC |
| `Menu_Protocolação.png` | "Protocolação de Documentos" | Referência MOVDOC |
| `Menu_Envio.png` | "Envio de Documentos" | Referência MOVDOC |
| `Menu_Remessa.png` | "Manutenção de Remessa" | Navegar para manutenção no FFCV |
| `Menu_Entrega.png` | "Entrega de Remessas" | Navegar para entrega/datas no FFCV |
| `Menu_TISS.png` | "Monitoração de Faturamento - TISS" | Navegar para geração XML |
| `Erro_MOVDOC.png` | Ícone X vermelho | Referência visual de erro MOVDOC |
| `Botão_Ok_Popup.png` | Popup `FRM-40352` com botão OK | Detectar fim do grid e fechar popup |

> **Como criar os PNGs:** Snipping Tool → recorte mínimo do texto → salvar como PNG. Não precisa remover fundo manualmente — o `*TransFFFFFF` no ImageSearch já ignora os pixels brancos.

---

## 7. Padrões AHK v2 do Projeto

### 7.1 Polling (substituiu Sleep fixo para esperas)

```autohotkey
; Definição em mv_session.ahk
MV_Poll(condFn, timeoutSecs) {
    deadline := A_TickCount + timeoutSecs * 1000
    Loop {
        if condFn()
            return true
        if A_TickCount > deadline
            return false
        Sleep MV_POLL_MS   ; 50ms
    }
}

; Exemplos de uso
MV_Poll(() => WinExist("Baixa de Documentos"), 20)
MV_Poll(() => !WinExist("Forms"), 8)
MV_Poll(() => A_Clipboard != "", 5)
```

### 7.2 Quando usar Sleep fixo vs Polling

| Situação | Técnica |
|---|---|
| Aguardar janela abrir | Polling (`WinExist`) |
| Aguardar popup aparecer | Polling (`WinExist`) |
| Aguardar popup fechar | Polling (`!WinExist`) |
| Aguardar clipboard após Ctrl+C | Polling (`A_Clipboard != ""`) |
| Estabilização após input | `Sleep MV_DELAY_INPUT` (80ms fixo — inevitável) |
| Estabilização após Ctrl+C | `Sleep MV_DELAY_CLIP` (150ms fixo) |

### 7.3 Leitura de campo via clipboard

```autohotkey
; Campos do Forms não são acessíveis via ControlGetText.
; Double-click seleciona conteúdo (Ctrl+A não funciona).
MV_ReadAt(winTitle, cx, cy) {
    WinActivate winTitle
    A_Clipboard := ""
    ControlClick "x" . cx . " y" . cy, winTitle,,,2  ; double-click
    Sleep MV_DELAY_INPUT
    Send "^c"
    MV_Poll(() => A_Clipboard != "", 3)
    return Trim(A_Clipboard)
}
```

### 7.4 Leitura do grid de contas (MOVDOC)

```autohotkey
; 1. ImageSearch no header da coluna
; 2. Offset para primeira linha de dados
; 3. Double-click → Ctrl+C → armazena
; 4. Down arrow → já auto-seleciona → Ctrl+C → repete
; 5. Para quando clipboard retornar vazio

ColetarColunaGrid(headerImg, rowOffsetY) {
    if !ImageSearch(&hx, &hy, 0, 0, A_ScreenWidth, A_ScreenHeight,
                   "*TransFFFFFF *10 " . A_ScriptDir . "\Imagens_Debug\" . headerImg)
        return []

    valores := []
    fieldY   := hy + rowOffsetY

    ; Primeira célula — double-click
    Click hx, fieldY, 2
    Sleep MV_DELAY_INPUT
    A_Clipboard := ""
    Send "^c"
    MV_Poll(() => A_Clipboard != "", 3)
    val := Trim(A_Clipboard)
    if val != ""
        valores.Push(val)

    ; Linhas seguintes — Down já seleciona
    Loop {
        Send "{Down}"
        Sleep MV_DELAY_INPUT
        A_Clipboard := ""
        Send "^c"
        MV_Poll(() => A_Clipboard != "", 2)
        val := Trim(A_Clipboard)
        if val = ""
            break
        valores.Push(val)
    }

    return valores
}
```

### 7.5 Estrutura de dados — Map multidimensional

```autohotkey
; Contas agrupadas por protocolo
; Map>>
protocolContas := Map()
protocolContas["12345"] := [
    Map("conta", "12950504"),
    Map("conta", "12950302")
]

; Array de erros
; Array<Map>
erros := []
erros.Push(Map(
    "protocolo",  "12345",
    "conta",      "12950504",
    "descricao",  "Convênio diferente"
))
```

### 7.6 Credenciais — DPAPI

```autohotkey
; Criptografia por usuário Windows (DPAPI)
; O config.ini não pode ser descriptografado em outra conta/máquina
EncryptDPAPI(plainText) {
    safe := StrReplace(plainText, "'", "''")
    return RunPS("ConvertTo-SecureString '" . safe
               . "' -AsPlainText -Force | ConvertFrom-SecureString")
}

DecryptDPAPI(encrypted) {
    return RunPS("(New-Object System.Management.Automation.PSCredential('x',"
               . "(ConvertTo-SecureString '" . encrypted
               . "'))).GetNetworkCredential().Password")
}
```

---

## 8. Fluxo de Login do MV (mv_session.ahk)

```
App inicia
  └── CheckSavedCredentials()
      ├── Sem credenciais salvas → JS: show_login
      └── Com credenciais → gUser/gPass em memória → JS: login_ok → abre app

Usuário preenche login no RPA → JS: save_creds → AHK: SaveCredentials()
  └── EncryptDPAPI(pass) → IniWrite → login_ok → abre app

gUser e gPass ficam disponíveis globalmente para os scripts usarem no MV.
```

**Fluxo de login no MV dentro dos scripts:**

```
MV_EnsureMovDoc() / MV_EnsureFFCV()
  ├── Detecta se a janela do módulo já está aberta
  │   └── Se aberta: ativar e seguir; não exigir título exato da subtela atual
  └── Se fechada:
      ├── Run do módulo pelo caminho .fmx correspondente
      ├── Aguarda janela Identificação
      ├── Campo Usuário já deve estar focado
      ├── SendText gUser
      ├── Tab
      ├── SendText gPass
      ├── Enter
      ├── Detecta popup de erro de login
      │   ├── Se erro: OK → fecha MOVDOC/FFCV → solicita novas credenciais no RPA
      │   └── Se não: aguarda janela do módulo abrir
      └── Retorna true quando a janela do módulo existir
```

**Regra importante:** login deve usar teclado como caminho principal. A abordagem por HWND + coordenada Client é mantida para testes e fallback, mas não deve ser o fluxo padrão se o campo Usuário já vier focado.

**Detecção de erro de login:** usar o popup modal com botão OK identificado nos prints de logout/erro. Ao detectar erro, limpar credenciais em memória, fechar o módulo que falhou e pedir novas credenciais ao usuário pela UI do RPA.

---

## 9. Scripts Implementados

### 9.1 Remessa por Protocolo (`remessa_protocolo.ahk`)

**Status:** script principal em especificação/implementação incremental. A UI já possui os parâmetros necessários; o fluxo operacional foi atualizado com base no comportamento real do MV.

**Parâmetros da UI:**
| Campo | Tipo | Obrigatório | Observação |
|---|---|---|---|
| Protocolos | text (vírgula separada) | Sim | Um ou mais protocolos. Ex: `12345, 67890` |
| Tipo de Conta | select: Internamento / Ambulatório / Emergência | Sim | Define código MV: Emergência=1, Internamento=2, Ambulatório=3 |
| Remessa Existente | text | Não | Se preenchida, inserir contas nela; se vazia, criar nova remessa |
| Data de Entrega | date | Não | Só usada quando o usuário quer fechar/entregar e gerar XML |
| Data de Vencimento | date | Não | Deve ser preenchida junto com Data de Entrega |

**Estrutura de dados obrigatória:**

```autohotkey
; Contas por protocolo.
; Necessário para mostrar ao usuário onde está a conta física quando houver erro.
protocolContas := Map()
protocolContas[protocolo] := [
    Map("conta", numeroConta)
]

; Erros por protocolo + conta.
erros := []
erros.Push(Map(
    "protocolo", protocolo,
    "conta", numConta,
    "descricao", "Convênio diferente"
))
```

**Fluxo atualizado:**

```
FASE 0 — Garantir MOV DOC
  ├── Detectar se MOV DOC está aberto
  │   ├── Se sim: ativar janela existente
  │   └── Se não: abrir MOV DOC pelo caminho .fmx e fazer login por teclado
  ├── Se aparecer erro de login: OK → fechar módulo → pedir novas credenciais ao usuário
  └── Não exigir título exato nessa detecção inicial, porque o MOV DOC pode estar em qualquer subtela

FASE 1 — Navegar até Baixa de Documentos
  ├── Clicar/selecionar menu Manutenção
  ├── Clicar/selecionar Baixa de Documentos
  ├── Aguardar tela de Baixa de Documentos carregar
  └── A partir daqui usar título/estado da tela de baixa

FASE 2 — Processar cada protocolo no MOV DOC
  Para cada protocolo informado pelo usuário:
  ├── Enviar número do protocolo no campo Protocolo
  ├── Apertar F8 (não Enter)
  ├── Aguardar carregamento dos dados do protocolo
  ├── Se convênio ainda não foi coletado:
  │   ├── Double-click no textfield de Convênio
  │   ├── Ctrl+C
  │   └── Guardar número do convênio em variável
  ├── Double-click no primeiro textfield/célula de Conta
  ├── Ctrl+C → guardar conta em protocolContas[protocolo]
  ├── Seta para baixo
  ├── Repetir leitura de conta até aparecer popup de fim do grid
  ├── Quando popup aparecer: clicar OK
  ├── Verificar checkbox Recebido
  │   ├── Se não estiver checkado: clicar uma vez
  │   └── Se estiver checkado: double-click conforme comportamento observado
  ├── Voltar ao campo inicial onde foi digitado o protocolo
  ├── Apertar F10 para salvar/baixar
  ├── Aguardar loading
  ├── Apertar F7 para preparar nova consulta
  └── Repetir para o próximo protocolo

FASE 3 — Garantir FFCV e entrar em Manutenção de Remessas
  ├── Detectar se FFCV está aberto
  │   ├── Se sim: ativar janela existente
  │   └── Se não: abrir FFCV pelo caminho .fmx e fazer login por teclado
  ├── Se aparecer erro de login: OK → fechar módulo → pedir novas credenciais ao usuário
  ├── Navegar até Manutenção de Remessa
  ├── Habilitar alteração com F7 ou botão equivalente
  ├── Informar convênio coletado no MOV DOC
  └── Aguardar carregamento

FASE 4 — Selecionar ou criar remessa
  Se usuário informou Remessa Existente:
  ├── Ir para área das remessas: Tab x3 ou clique na grade
  ├── F7 ou botão de busca
  ├── Digitar número da remessa
  ├── F8 ou botão confirmar
  └── Aguardar remessa carregar/ficar selecionada

  Se usuário NÃO informou Remessa Existente:
  ├── Ir para área das remessas
  ├── F6 ou botão nova remessa
  ├── Digitar data do dia
  ├── Enter 3 vezes ou foco direto no campo de tipo
  ├── Digitar tipo: Emergência=1, Internamento=2, Ambulatório=3
  ├── F10 ou botão salvar
  └── Aguardar nova remessa ser criada e ficar selecionada

FASE 5 — Inserir contas na remessa
  ├── Clicar botão Inserir Conta
  ├── Aguardar popup com 2 dropdowns + textfield
  ├── Dropdown 1: sempre segunda opção
  ├── Dropdown 2:
  │   ├── Internamento: manter como está
  │   └── Emergência/Ambulatório: trocar para segunda opção
  ├── Focar textfield de conta
  └── Para cada conta de cada protocolo:
      ├── Enviar número da conta
      ├── Enter
      ├── Esperar janela curta por popup/erro
      ├── Se erro "já digitada": OK e continuar
      ├── Se erro "convênio diferente": registrar protocolo + conta + descrição
      ├── Se erro "conta aberta": registrar protocolo + conta + descrição
      ├── Se erro "tipo diferente": registrar protocolo + conta + descrição
      └── Continuar com próxima conta

FASE 6A — Finalizar sem datas
  ├── Fechar popup/form de inserir contas
  ├── Clicar botão de finalização sem datas
  ├── Aguardar popup/tela de imprimir capa de remessa
  ├── Enter ou botão Imprimir
  └── Fim do macro

FASE 6B — Finalizar com datas e gerar XML
  ├── Fechar popup/form de inserir contas
  ├── Clicar botão para abrir tela de entrega/datas
  ├── Aguardar tela de Entrega de Remessas
  ├── Ler número da remessa em variável
  ├── Preencher Data de Entrega
  ├── Preencher Data de Vencimento
  ├── Marcar checkbox necessário
  ├── Confirmar entrega
  ├── Aguardar popup e confirmar OK/Enter
  ├── Aguardar tela/popup de imprimir capa
  ├── Imprimir/Enter
  ├── Aguardar término do carregamento
  ├── Voltar
  ├── Ir para tela Monitoração de Faturamento - TISS
  ├── Focar campo Remessa
  ├── Enviar número da remessa coletado
  ├── F8
  ├── Aguardar carregamento
  ├── Clicar Faturamento
  ├── Aguardar tela XML gerado
  ├── Preencher caminho completo do XML:
  │   └── {pasta XML criada pelo RPA}\{numRemessa}.xml
  ├── Clicar Salvar/Enviar XML
  ├── Aguardar popup "Deseja visualizá-lo?"
  ├── Clicar Não
  ├── Aguardar popup fechar
  ├── Sair da tela XML gerado
  └── Sair/voltar da tela de XML/TISS quando houver controle mapeado
```

**Notas de performance e robustez:**
- Inserção de contas deve ser o trecho mais rápido do macro, mas sempre com janela curta de detecção de popup após cada Enter.
- Não usar sleeps longos fixos em fluxos lentos do MV; usar polling por janela/estado.
- Usar `F6`, `F7`, `F8`, `F10` quando forem mais estáveis que botão por ClassNN.
- Quando ClassNN se repetir, localizar HWND por `ClassNN + coordenada Client` e agir no HWND.
- Para login, usar teclado como caminho principal.

### 9.2 Protocolar (`protocolar.ahk`)

**Status:** Stub — aguarda detalhamento do fluxo.

**Parâmetros:**
| Campo | Tipo | Obrigatório |
|---|---|---|
| Remessas | text (vírgula separada) | Sim |
| Setor Atual | text | Sim |
| Setor de Envio | text | Sim |

### 9.3 Fechar e Gerar XML (`fechar_xml.ahk`)

**Status:** Stub — aguarda detalhamento do fluxo.

**Parâmetros:**
| Campo | Tipo | Obrigatório |
|---|---|---|
| Remessas | text (vírgula separada) | Sim |
| Data de Entrega | date | Sim |
| Data de Vencimento | date | Sim |

---

## 10. Interface do RPA (UI)

### Tela de Login
- Estilo da janela "Identificação" do MV2000i
- Fundo: gradiente azul (igual ao MV)
- Dialog branco com título azul
- Campos: Usuário + Senha
- Botões: Cancelar / Confirmar
- Ao confirmar: salva credenciais criptografadas e abre o app

### App Principal
- Janela: 750×540px (redimensionável, mínimo 640×460)
- Header: azul escuro com logo MV
- Sidebar: lista de módulos por categoria
- Form area: formulário dinâmico gerado por `gScripts`
- Barra de progresso: repating-gradient azul MV
- Log console: fundo escuro, fonte monospace, cores por tipo
- Status bar: dot animado (verde = pronto, laranja piscando = executando)

### Comunicação JS ↔ AHK

| Direção | Tipo | Payload |
|---|---|---|
| AHK → JS | `show_login` | `{user}` |
| AHK → JS | `login_ok` | `{user, scripts[]}` |
| AHK → JS | `login_failed` | `{message}` |
| AHK → JS | `status` | `{message, running}` |
| AHK → JS | `log` | `{message}` |
| AHK → JS | `progress` | `{value: 0-100}` |
| AHK → JS | `done` | `{message}` |
| AHK → JS | `error` | `{message}` |
| JS → AHK | `ready` | — |
| JS → AHK | `save_creds` | `{user, pass}` |
| JS → AHK | `run_script` | `{scriptId, params{}}` |
| JS → AHK | `stop_script` | — |

---

## 11. Instalação no PC do Hospital (Modo Desenvolvimento)

### Requisitos
1. **AutoHotkey v2** — instalar em modo usuário (sem admin)
2. **WebView2 Runtime** — já presente no Windows 10/11 atualizado
3. **Libs AHK** — baixar `WebView2.ahk` e `JSON.ahk` de github.com/thqby/ahk2_lib e colocar em `lib\`

### Deploy sem installer (fase atual)
1. Copiar toda a pasta `rpa-mv2000i\` para o computador (ex: `C:\Users\fulano\Documents\rpa-mv2000i\`)
2. Criar `config.ini` com seção `[Paths] WorkDir=C:\Users\fulano\Documents\RPA MV2000i`
3. Criar pasta `C:\Users\fulano\Documents\RPA MV2000i\XML\`
4. Criar atalho na área de trabalho apontando para `main.ahk`
5. Duplo clique → abre o RPA

### Deploy com installer (produção)
Usar **Inno Setup 6** com o script `installer.iss` que:
- Instala em `%LOCALAPPDATA%\RPA MV2000i\` (sem admin)
- Cria `%DOCUMENTS%\RPA MV2000i\XML\` automaticamente
- Escreve o `WorkDir` real no `config.ini` via Pascal script pós-install
- Cria atalho no Menu Iniciar e opcionalmente na Área de Trabalho

---

## 12. Itens Pendentes / Placeholders

### mv_session.ahk
- [ ] Implementar login por teclado como fluxo principal: usuário → Tab → senha → Enter
- [ ] Detectar popup de erro de login; ao falhar, fechar módulo e pedir novas credenciais ao usuário
- [ ] Confirmar se `Button1` é sempre o botão Confirma no login
- [ ] Confirmar se banco (`ComboBox1`) precisa ser manipulado ou se sempre permanece em PRODUCAO
- [ ] Ajustar `MV_EnsureMovDoc()` e `MV_EnsureFFCV()` para não depender de título exato quando o módulo já estiver aberto em uma subtela qualquer

### remessa_protocolo.ahk
- [ ] ClassNN + coordenada Client do campo Protocolo na tela Baixa de Documentos
- [ ] ClassNN + coordenada Client do campo Convênio na tela Baixa de Documentos
- [ ] ClassNN + coordenada Client da primeira célula/campo Conta no grid do MOV DOC
- [ ] Confirmar técnica de fim do grid: popup `FRM-40352` + botão OK `Button1`
- [ ] ClassNN/coordenada do checkbox Recebido e regra final: se não checkado clicar uma vez; se checkado double-click conforme observado
- [ ] Confirmar ação correta após processar protocolo: voltar ao campo inicial, F10, aguardar loading, F7
- [ ] ClassNN/coordenadas do popup de Inserir Conta no FFCV: dropdown 1, dropdown 2, campo conta e botão OK de conta já digitada
- [ ] Textos exatos dos popups de erro no FFCV: já digitada, convênio diferente, conta aberta, tipo diferente
- [ ] ClassNN + coordenada Client de Data de Entrega e Data de Vencimento na tela Entrega de Remessas
- [ ] Confirmar campo que contém o número da remessa na tela Entrega de Remessas
- [ ] ClassNN/coordenada do campo Remessa na Monitoração de Faturamento - TISS
- [ ] ClassNN ou tecla para sair/voltar da tela Monitoração de Faturamento - TISS
- [ ] Garantir criação/uso da pasta XML do usuário e montar caminho `{XML}\{numRemessa}.xml`

### Mini macros de teste
- [ ] Rodar `01_login_identificacao.ahk` em modo localização e validar relatório
- [ ] Preencher e rodar testes de MOV DOC, FFCV, popup de contas, entrega/datas e XML conforme os próximos Window Spy
- [ ] Só transferir ClassNN/coordenadas para o macro principal depois de relatório positivo

### Scripts em stub
- [ ] Protocolar — detalhar fluxo completo
- [ ] Fechar e Gerar XML — detalhar fluxo completo

### Produção
- [ ] Gerar ícone `.ico` para o installer e janela do RPA
- [ ] Compilar `main.ahk` com Ahk2Exe
- [ ] Testar installer Inno Setup em máquina limpa
- [ ] Definir URL e backend da API de licenciamento

---

## 13. Classes de Janela do MV2000i — Referência Rápida

| Classe | Tipo |
|---|---|
| `ui60MDIroot_W32` | Janela principal de qualquer módulo |
| `ui60Modal_W32` | Todo popup/dialog modal (erros, confirmações) |
| `ui60Drawn_W321` | Canvas de renderização do Forms (não interagível via controles) |
| `ui60Drawn_W326` | Canvas em telas específicas (ex: XML Gerado) |
| `ui60Viewcore_W329` | Botões da toolbar interna do Forms |
| `ui60MDlroot_W32` | Variante (letra l minúscula — verificar se é a mesma) |