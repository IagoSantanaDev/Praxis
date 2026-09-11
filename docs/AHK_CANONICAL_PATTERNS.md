# Padrões canônicos de interação MV em AutoHotkey v2

**Status:** especificação das primitivas canônicas de interação e sincronização MV
**Revisão:** 2026-09-10; motor de sincronização orientado a estado incorporado e validado por compilação estática.
**Escopo desta versão:** contratos das primitivas MV compartilhadas, do motor de transição e sua aplicação em todos os fluxos operacionais de MOV DOC, Protocolar, FFCV, popup de contas e XML/TISS.
**Fontes locais:** `lib/globals/mv/MVConstants.ahk`, `lib/globals/mv/components/Controls.ahk`, `lib/globals/mv/components/Dialogs.ahk`, `lib/globals/mv/components/Popups.ahk`, `lib/globals/mv/MVSync.ahk` e `lib/globals/mv/MVSession.ahk`.

## 1. Regra de canonização

A fonte única de interação deve permanecer em `lib/globals/mv/`:

- `MVConstants.ahk`: títulos, classes, coordenadas de domínio e timings compartilhados;
- `components/Controls.ahk`: descoberta, polling, clique, texto e espera;
- `components/Dialogs.ahk` e `components/Popups.ahk`: semântica de domínio para modais/popups, composta sobre Controls;
- `MVSession.ahk`: preparação da sessão, ativação e abort.

Um wrapper de módulo é permitido quando acrescenta semântica de negócio, relatório ou escolha de fallback. Um wrapper que apenas repete a busca, o clique, o polling ou o timing da primitiva canônica deve ser removido na migração, depois de confirmar todos os callers.

### 1.1 Convenções de tipos e unidades

| Convenção | Contrato |
|---|---|
| `winTitle` | string de critério de janela AHK; os títulos `MV_WIN_*` usam `ahk_exe` e podem depender de `SetTitleMatchMode(2)` carregado pela sessão |
| `classNN` | identificação exata `ClassNN`, por exemplo `Button1` ou `Edit2` |
| `classPrefix` | prefixo de `ClassNN`, por exemplo `Edit`, `ComboBox` ou `ui60Drawn` |
| coordenadas | inteiros em coordenadas de cliente; `MVSession.ahk` define `CoordMode("Mouse", "Client")` |
| timeout em `Secs` | segundos, convertido internamente para milissegundos |
| timeout em `Ms` | milissegundos; ao chamar `MV_Poll`, converter para segundos apenas no ponto de chamada |
| retorno de busca | `HWND` inteiro ou `0` quando não encontrado/erro recuperável |
| retorno de ação | booleano; `true` confirma a ação local, não necessariamente o estado final da UI |
| erro de controle | falha recuperável retorna `0`, `false` ou `""` conforme o contrato; não ocultar mudança de contrato durante migração |

## 2. Contratos canônicos de Controls

As assinaturas abaixo conferem com a implementação atual de `components/Controls.ahk`. Os operadores de ação descritos nesta seção são obrigatórios nos fluxos operacionais; comentários de migração restantes identificam somente riscos de domínio ou macros fora do runtime principal.

### `MV_Poll`

```ahk
MV_Poll(condFn, timeoutSecs)
```

- **Entrada:** callback sem argumentos e timeout explícito em segundos.
- **Comportamento:** avalia `condFn()` imediatamente; repete após `MV_POLL_MS`; encerra quando o callback for truthy ou quando `A_TickCount` ultrapassar o deadline.
- **Retorno:** `true` se a condição foi satisfeita; `false` por timeout.
- **Globals/dependências:** lê `MV_POLL_MS`, definido em `MVConstants.ahk` e normalmente igual a `100` ms.
- **Exceções:** exceção lançada pelo callback não é capturada por `MV_Poll`; sobe para o caller. O caller decide se deve tratar como falha de fluxo.
- **Regra:** não passar milissegundos diretamente. Para um limite em ms, usar `timeoutMs / 1000`.

### `MV_FindControlAtPoint`

```ahk
MV_FindControlAtPoint(winTitle, classNN, targetX, targetY, tolerance := 14, classPrefix := "")
```

- **Entrada:** janela, classe exata ou prefixo, ponto de cliente e tolerância em pixels.
- **Comportamento:** enumera `WinGetControlsHwnd(winTitle)`, filtra por classe exata quando `classPrefix` é vazio ou por prefixo quando não vazio, obtém posição com `ControlGetPos` e devolve o controle que contém o ponto. Fora do retângulo, escolhe o mais próximo somente se a distância ao centro for `<= tolerance`.
- **Retorno:** `HWND` do controle ou `0`.
- **Erros:** falhas em `WinGetControlsHwnd`, `ControlGetClassNN` ou `ControlGetPos` são tratadas localmente: a busca inteira retorna `0` no primeiro caso; controles individuais são ignorados nos demais.
- **Dependências:** primitivas nativas `WinGetControlsHwnd`, `ControlGetClassNN` e `ControlGetPos`; coordenadas devem ser do cliente da janela.

### `MV_FindControlByClientPoint`

```ahk
MV_FindControlByClientPoint(winTitle, classNN, targetX, targetY, tolerance := 14)
```

- **Contrato pretendido:** busca por `ClassNN` exata e delega a `MV_FindControlAtPoint(..., "")`.
- **P0 resolvido:** `components/Controls.ahk` mantém uma única definição pública de `MV_FindControlByClientPoint`, delegada ao helper canônico `MV_FindControlAtPoint`. A contagem de definições e os callers foram verificados após a consolidação em S03.
- **Retorno e erros:** iguais aos de `MV_FindControlAtPoint`.
- **Não fazer nesta tarefa:** não editar a fonte para resolver o bloqueio.

### `MV_FirstControlByClass`

```ahk
MV_FirstControlByClass(winTitle, classNN)
```

- **Entrada:** critério de janela e `ClassNN` exata.
- **Retorno:** primeiro `HWND` encontrado, ou `0`.
- **Erros:** falha ao enumerar controles retorna `0`; falha ao ler a classe de um controle ignora esse controle.
- **Uso permitido:** base de `MV_ClickFirstControl` e wrapper `Popup_FirstControlByClass`; o wrapper de popup é compatível e não é uma duplicata a apagar enquanto for API de domínio.

### `MV_ClickFirstControl`

```ahk
MV_ClickFirstControl(winTitle, classNN)
```

- **Comportamento:** chama `MV_FirstControlByClass`; se houver `HWND`, executa `ControlClick hwnd,,,,, "NA"`.
- **Retorno:** `false` sem controle; `true` quando o comando de clique foi aceito.
- **Limitação:** `true` não prova que a janela mudou ou que um modal fechou; o caller deve usar `MV_Poll` para observar o estado final.
- **Dependências:** `MV_FirstControlByClass` e primitiva nativa `ControlClick` com opção `NA`.

### `MV_ClickBySpec`

```ahk
MV_ClickBySpec(winTitle, classNN, x, y)
```

- **Validação:** rejeita classe vazia, placeholder `CLASSNN` e coordenadas vazias.
- **Estratégia:** tenta `MV_ClickControlAt` com tolerância de `20`; se falhar, exige janela existente, ativa-a, aguarda `WinActive` por até `3` segundos e executa `Click(x, y, 1)`.
- **Retorno:** `true` se o clique por controle ou físico for emitido; `false` para entrada inválida, janela ausente, falha de ativação, timeout ou exceção.
- **Exceções:** o fallback físico está protegido por `try/catch` e devolve `false`.
- **Regra:** callers de domínio podem adaptar a especificação, mas não devem reimplementar a sequência busca → ativação → fallback.

### `MV_SetTextByControl` e `MV_SetTextByClick`

```ahk
MV_SetTextByControl(winTitle, classNN, value, fallbackX := "", fallbackY := "", clear := true)
MV_SetTextByClick(winTitle, x, y, value, clear := true)
```

- **`MV_SetTextByControl`:** tenta `ControlSetText` no primeiro controle da classe exata; se o controle não existir ou rejeitar a operação, usa `MV_SetTextByClick` quando as coordenadas de fallback foram fornecidas.
- **`MV_SetTextByClick`:** exige `MV_EnsureWindowActive`; clica com deslocamento `(x + 15, y + 8)`, aguarda `MV_KEY_SETTLE_MS`; com `clear=true`, envia Home, Ctrl+Shift+End e Backspace, aguarda novamente; por fim usa `SendText value`.
- **Retorno:** `false` quando não há controle/fallback utilizável ou a janela não pôde ser ativada; `true` após emitir a operação.
- **Globals:** `MV_KEY_SETTLE_MS` vem de `MVConstants.ahk` e vale `100` ms atualmente.
- **Limitação:** a implementação não lê o texto de volta; callers que exigem confirmação devem compor `MV_CopyFocusedText` ou uma leitura específica.
- **Wrappers permitidos:** equivalentes de domínio como `TissXml_SetTextByClickAt`, `TissXml_SetTextByClickNoClear` e preenchimento do popup, desde que preservem a semântica `clear` e não dupliquem a sequência.

### `MV_CopyFocusedText`

```ahk
MV_CopyFocusedText(timeoutMs := 600, extrairNumero := false)
```

- **Comportamento:** limpa `A_Clipboard`, envia Ctrl+C e aguarda `ClipWait(timeoutMs / 1000)`.
- **Retorno:** `""` no timeout; texto aparado (`Trim`) no sucesso; com `extrairNumero=true`, primeiro grupo `\d+` ou `""` se não houver número.
- **Globals/efeito:** altera o clipboard global do processo e depende do controle atualmente focado.
- **Unidade:** argumento em milissegundos; `ClipWait` recebe segundos.
- **Falhas:** timeout é representado por string vazia; não confundir string vazia com campo realmente vazio sem um contrato adicional.

### `MV_ControlCheckedAt`

```ahk
MV_ControlCheckedAt(winTitle, classNN, clientX, clientY, tolerance := 14)
```

- **Comportamento:** localiza o controle com `MV_FindControlByClientPoint` e lê `ControlGetChecked`.
- **Retorno:** valor de `ControlGetChecked` quando há controle; `""` quando não há controle ou a leitura lança exceção.
- **Semântica:** `""` é estado de falha/desconhecido, não deve ser convertido silenciosamente em `false`.
- **Dependências:** busca por ponto e primitiva nativa `ControlGetChecked`.

### `MV_WaitWindowStable`

```ahk
MV_WaitWindowStable(winTitle, stableMs := 600, timeoutSecs := 20)
```

- **Comportamento:** enquanto dentro do timeout, verifica existência, ativa a janela, enumera controles e considera estabilidade quando a janela está ativa e a contagem de controles permanece igual por `stableMs`.
- **Retorno:** `true` após estabilidade; `false` quando o timeout expira.
- **Unidades:** `stableMs` em milissegundos; `timeoutSecs` em segundos.
- **Globals:** lê `MV_POLL_MS`.
- **Erros:** falha de enumeração usa lista vazia; isso pode produzir um estado estável falso se o caller não distinguir janela sem controles de falha nativa. A migração deve preservar ou tornar essa distinção explícita.

### `MV_WaitOracleSettled`

```ahk
MV_WaitOracleSettled(winTitle, stableMs := 800, timeoutMs := 30000)
```

- **Comportamento:** exige simultaneamente janela existente, nenhum modal via `Dialog_ActiveModalTitle`, cursor diferente de `Wait`/`AppStarting` e contagem de controles estável por `stableMs`.
- **Retorno:** `true` quando o Oracle Forms está assentado; `false` no timeout.
- **Unidades:** todos os parâmetros desta função são milissegundos, exceto nenhum; `timeoutMs` não deve ser tratado como segundos.
- **Dependências:** `Dialog_ActiveModalTitle`, `WinExist`, `WinGetControlsHwnd`, `A_Cursor`, `MV_POLL_MS` e a disponibilidade do include de Dialogs no grafo final.
- **Regra de migração:** não fundir com `MV_WaitWindowStable` apenas por semelhança textual; a checagem de modal e cursor é parte do contrato.

## 3. Contratos do motor de sincronização

`lib/globals/mv/MVSync.ahk` é incluído por `MVSession.ahk` depois de `MVConstants.ahk` e `Controls.ahk`.

- `MV_CaptureScreenState(winTitle)` captura HWND, processo, classe, título e assinatura estrutural dos controles.
- `MV_GetScreenSignature(hwnd)` inclui a identidade da janela e texto, visibilidade e habilitação dos controles; portanto, mudança no mesmo HWND pode ser detectada.
- `MV_WaitScreenChanged(previousState, timeoutMs, winTitle)` aguarda uma assinatura ou HWND diferente; timeout retorna `false` e gera log técnico.
- `MV_WaitScreenStable(winTitle, stableMs, timeoutMs)` exige a mesma assinatura durante a janela de estabilidade.
- `MV_WaitExpectedState(expectedFn, winTitle, timeoutMs, description)` valida a condição operacional específica da tela após a estabilidade.
- `MV_WaitWindowClosed(winTitle, timeoutMs)` aguarda fechamento observável sem atraso fixo.
- `MV_ActAndWait` é o operador base: captura estado anterior, executa o callback, aguarda mudança, aguarda estabilidade e, quando informado, valida o predicado operacional.
- `MV_ClickAndWait`, `MV_ClickAtAndWait`, `MV_ClickHwndAndWait`, `MV_ClickModalAndWait`, `MV_SendAndWait`, `MV_SendTextAndWait`, `MV_SendFunctionAndWait`, `MV_SendEnterAndWait` e `MV_SetTextAndWait` são os operadores canônicos dos fluxos.
- Fechamentos usam `MV_CloseWindowAndWait`, que comprova o evento de janela fechada e a estabilidade da janela de retorno.
- Os loops continuam cooperativos: chamam `ThrowIfAppStopped()` a cada polling e usam `Sleep` somente para espaçar observações, nunca como prova de conclusão.
- A migração operacional foi aplicada a MOV DOC, Protocolar, FFCV, popup de contas e XML/TISS. Um `Send`/`ControlSend` residual só pode existir dentro do callback de uma ação canônica ou em um loop de polling.

## 4. Contratos de sessão e abort

### `MV_EnsureWindowActive`

```ahk
MV_EnsureWindowActive(winTitle, timeoutSecs := 3)
```

- **Entrada:** critério de janela e timeout em segundos.
- **Comportamento:** retorna `false` sem janela; caso contrário chama `WinActivate` e aguarda `WinActive` usando `MV_Poll`.
- **Retorno:** `true` somente quando a janela fica ativa dentro do limite; `false` em ausência ou timeout.
- **Dependências:** `WinExist`, `WinActivate`, `WinActive`, `MV_Poll` e `MV_POLL_MS`.
- **Uso:** pré-condição de `MV_SetTextByClick` e fallback de `MV_ClickBySpec`; não substituir por `WinActivate` sem espera.

### `MV_EnsureModule`

A fonte canônica generaliza `MV_EnsureMovDoc()` e `MV_EnsureFFCV()` sem alterar os aliases públicos:

```ahk
MV_EnsureModule(moduleWin, stableMs := MV_MODULE_STABLE_MS, timeoutSecs := MV_TIMEOUT_LOAD)
```

- Deve verificar a existência de `moduleWin`, ativar a janela e chamar `MV_WaitWindowStable`.
- Deve retornar booleano e propagar `false` para ausência, falha de ativação ou timeout.
- `stableMs` é milissegundos; `timeoutSecs` é segundos.
- Os wrappers `MV_EnsureMovDoc` e `MV_EnsureFFCV` podem permanecer como aliases de domínio durante a migração, caso callers públicos ainda os usem.
- **Estado:** implementado em `MVSession.ahk`; os callers existentes continuam usando os aliases de domínio, que delegam para a fonte única.

### `MV_Abort`

```ahk
MV_Abort(msg, sendStatus := false)
```

- **Comportamento:** envia à UI uma mensagem de erro; opcionalmente envia status `Execução finalizada.` com `running=false`; define `gRunning := false`.
- **Retorno:** sempre `false`, permitindo `return MV_Abort(...)` no caller.
- **Globals:** declara e escreve `gRunning`; depende de `SendToUI` e de `gRunning` inicializado pelo host.
- **Efeito:** é encerramento de fluxo, não exceção; não relançar como erro genérico durante a canonização.
- **Compatibilidade:** substitui conceitualmente `Protocolar_Abort` e `RP_Abort`; manter wrappers somente se houver caller público e fazê-los delegar à função canônica.

### Política de wrappers de módulo

- Wrappers de abort e parse permanecem somente quando preservam uma API de domínio/compatibilidade ou acrescentam semântica observável, como `sendStatus=true`; não criar wrapper para apenas renomear a primitiva.
- Wrappers de interação permanecem somente quando acrescentam timeout, logging, fallback ou composição de estado. `TissXml_ClickBySpec` é permitido porque compõe `MV_ClickAndWait` com o timeout/relato próprio da tela XML/TISS.
- Quando não houver semântica adicional, o caller usa diretamente `MV_Abort`, `ParseListaCsv` ou `MV_ClickBySpec`.

### Preparação de processo em `MVSession.ahk`

Antes da API, o arquivo define `SetTitleMatchMode(2)`, `DetectHiddenText(true)`, atrasos de controle/janela/teclado e `CoordMode("Mouse", "Client")`. Esses efeitos são pré-condições globais do módulo e não devem ser repetidos em cada wrapper. O arquivo inclui `MVConstants.ahk` e `components/Controls.ahk`; `Dialogs.ahk`/`Popups.ahk` incluem Controls e Constants por sua vez, e não devem criar uma segunda fonte de constantes.

## 4. Modais, popups e wrappers permitidos

### `Dialogs.ahk`

- `Dialog_ActiveModalTitle()` retorna o critério `MV_CLASS_MODAL_FORMS` quando `WinExist` encontra um modal, ou `""`; é o oracle usado por `MV_WaitOracleSettled` e `MV_WaitModalGone`.
- `Dialog_ClassifyErroContaModal(winTitle := "")` resolve o modal ativo e delega a `FFCV_ClassifyErrorModal`; retorna um `Map` de classificação. O OCR é semântica de domínio e não deve ser absorvido por Controls.
- `Dialog_MovDocPopupVisible()` é um wrapper fino de `WinExist` para o título do popup; preservar somente enquanto for API de domínio.
- `Dialog_DismissMovDocPopup()` ativa o popup, aguarda `Popup_FirstControlByClass`, tenta `MV_ClickFirstControl`, usa Enter como fallback e confirma o fechamento com polling. É wrapper permitido porque expressa o fluxo MOV DOC; não duplicar a busca/clique.
- `Dialog_DismissMovDocPopup()` e `Popup_DismissActiveModal()` permanecem separados: o primeiro retorna booleano e possui fallback `Enter` específico do MOV DOC; o segundo retorna `Map("ok", ..., "report", ...)` para o fluxo de remessa e não possui esse fallback. A sequência compartilhada continua nas primitivas canônicas, sem núcleo parametrizado que apagaria essa diferença de contrato.
- O `try` atual converte falhas em `false`; mudanças futuras devem manter erro observável por `MV_Log` e não ocultar a razão.

### `Popups.ahk`

- `Popup_ContaVisible()` usa sentinela e coordenadas de `MVConstants`; compõe `Popup_FindControlByClassPrefixAtPoint` e `MV_FindControlByClientPoint`. É regra de domínio do popup Informações da Conta.
- `Popup_FindControlByClassPrefixAtPoint(winTitle, classPrefix, targetX, targetY, tolerance := 35)` delega a `MV_FindControlAtPoint` com prefixo. Não é uma segunda implementação.
- `Popup_FirstControlByClass(winTitle, classNN)` delega a `MV_FirstControlByClass`. É alias compatível; remover apenas após inventário de callers.
- `Popup_DismissActiveModal()` retorna `Map("ok", bool, "report", string)`, trata modal ausente como sucesso, aguarda botão OK, clica, aguarda fechamento por `MV_TIMEOUT_ACOE` e estabiliza por `MV_CONTA_STABLE_MS`. O `Map` e o relatório são semântica de domínio, portanto o wrapper é permitido.

## 5. Constantes e globals canônicos

`MVConstants.ahk` é a única fonte para títulos de janela, classes de modal, coordenadas do popup, `MV_TIPO_CONTA` e timings. Defaults compartilhados de polling e espera também devem viver ali; valores de infraestrutura do shell permanecem em `App.ahk` porque não pertencem à automação MV. Valores atualmente relevantes:

- `MV_POLL_MS = 100` ms;
- `MV_DEFAULT_TIMEOUT_MS = 30000` ms e `MV_DEFAULT_TIMEOUT_SECS = 20` s;
- `MV_DEFAULT_STABLE_MS = 600` ms, `MV_ORACLE_STABLE_MS = 800` ms e `MV_CLIPBOARD_TIMEOUT_MS = 600` ms;
- `MV_WINDOW_ACTIVATE_TIMEOUT_SECS = 3` s;
- `FFCV_FINAL_STABLE_MS = 800` ms e `FFCV_FINAL_ACTION_TIMEOUT_MS = 30000` ms, compartilhados por FFCV/XML/TISS;
- `MV_TIMEOUT_LOAD = 15` s e `MV_TIMEOUT_ACOE = 10` s;
- `MV_MODULE_STABLE_MS = 600` ms e `MV_TARGET_STABLE_MS = 600` ms;
- timings de foco/limpeza/tecla e popup entre `100` e `650` ms.

Defaults em `timeoutMs` e `timeoutSecs` devem referenciar essas constantes quando o contrato for compartilhado. Timeouts de domínio usados uma única vez, como aparição de popup ou fechamento específico de tela, continuam junto do módulo que define o contrato; não transformar todo literal isolado em constante global.

A divergência histórica de tipo de conta deve permanecer explícita: a fonte canônica define Internamento `1`, Emergência `2` e Ambulatório `3`; macros que usam outra ordem precisam ser migrados e validados, não corrigidos silenciosamente dentro dos helpers de interação.

## 6. Primitivas nativas versus convenções do projeto

### Primitivas nativas AHK v2

`WinExist` retorna o `HWND` da primeira janela encontrada ou `0`; `WinActive` informa a janela ativa; `WinActivate` solicita ativação; `WinGetControlsHwnd` enumera controles; `ControlGetClassNN`, `ControlGetPos`, `ControlGetChecked`, `ControlGetText`, `ControlClick`, `Click`, `Send`, `SendText`, `ClipWait`, `Sleep`, `SetTimer`, `Critical` e `A_TickCount` são capacidades da linguagem/runtime. AHK v2 também fornece `try/catch/finally`, callbacks e `Map`.

A documentação oficial consultada via **Context7** confirma, em particular, que `WinExist` retorna `0` quando não encontra janela e um `HWND` quando encontra, e que `Critical` controla interrupção de threads. A referência oficial é `https://www.autohotkey.com/docs/v2/`; as assinaturas e semântica de `Control*`, `ClipWait` e temporização devem ser rechecadas contra essa referência na migração.

`SetTimer` é uma primitiva de callbacks periódicos e `Critical` é uma primitiva de proteção de thread; nenhum dos dois substitui automaticamente o polling síncrono definido por `MV_Poll`. A escolha de polling, as unidades, tolerâncias, mensagens de log, mapas de retorno e aliases são convenções deste projeto.

### Convenções do projeto

`MV_*`, `Popup_*` e `Dialog_*`; `MV_POLL_MS`; títulos/classes `MV_*`; coordenadas de cliente; retornos sentinela (`0`, `false`, `""`); `MV_Log`; `SendToUI`; `gRunning`; e a divisão Constants → Controls → wrappers de domínio → Session são contratos Praxis, não APIs nativas AHK. Não documentar essas convenções como se fossem garantias do runtime.

## 7. Dependências de include e ordem de carregamento

| Arquivo | Includes relevantes | Contrato de dependência |
|---|---|---|
| `MVSession.ahk` | `MVConstants.ahk`, `components/Controls.ahk` | fornece configuração global e API de sessão |
| `Dialogs.ahk` | `Controls.ahk`, `MVConstants.ahk`, `FFCV_ErrorTemplates.ahk` | depende de `MV_Log`, polling, popup e OCR de domínio |
| `Popups.ahk` | `Controls.ahk`, `MVConstants.ahk` | depende das primitivas canônicas e constantes do popup |
| callers de `MV_WaitOracleSettled` | devem carregar o símbolo `Dialog_ActiveModalTitle` | a resolução do modal não pode ficar implícita em include acidental |

A migração deve conferir o grafo real de includes em cada caller, porque AHK inclui arquivos e executa top-level; não adicionar uma segunda inclusão ou uma chamada top-level de entry point como atalho.

## 8. Riscos, prova e sequência de migração

### 8.1 Prova estática desta revisão

A revisão confirma a existência deste documento e dos cinco arquivos-fonte listados no cabeçalho, encontra cada contrato exigido nas seções anteriores, confirma a referência **Context7** e agora encontra uma única definição de `MV_FindControlByClientPoint` em `Controls.ahk`. A implementação canônica delega para `MV_FindControlAtPoint` com classe exata, preservando a assinatura pública e os callers existentes. O caminho `tools/cli-check.ps1` está ausente; não deve ser tratado como um quarto script disponível nem como substituto dos três validadores existentes.

- **P0 — duplicidade de `MV_FindControlByClientPoint`:** resolvido na etapa S03 inicial; a contagem estática e a busca de callers passaram antes/depois da remoção. O wrapper público permanece como delegação para a fonte única.
- **P1 - unidades de timeout heterogêneas:** manter nomes `timeoutSecs`, `timeoutMs` e `stableMs`; revisar cada caller antes de converter.
- **P1 - erro mascarado por sentinelas:** `0`, `false` e `""` têm significados diferentes; preservar o contrato e registrar razões nos wrappers.
- **P1 - include implícito de `Dialog_ActiveModalTitle`:** tornar o grafo explícito antes de consolidar waits.
- **P2 - wrappers públicos:** inventariar callers antes de apagar aliases de popup, MOV DOC, FFCV e TISS.
- **P2 - efeitos globais da sessão:** carregar configurações de `MVSession.ahk` uma vez e provar que macros isolados continuam com as mesmas coordenadas.

Sequência recomendada: (1) S03 removeu a duplicidade P0 e deixou a busca de classe exata delegada à fonte única; (2) S04 consolida texto, waits e modais preservando mapas/relatórios; (3) S05 resolve includes obsoletos, OCR e contratos de macros, depois revisa constantes e parsers relacionados. Cada etapa deve comparar callers, executar os três scripts nativos de validação disponíveis no repositório quando aplicável e não transformar um wrapper compatível em duplicata removível sem evidência.

## 9. Checklist para cada remoção futura

- [ ] assinatura e unidades conferem com esta especificação;
- [ ] `rg` encontrou todos os callers, inclusive `test_macros`;
- [ ] há uma única definição da primitiva;
- [ ] aliases públicos delegam ou foram removidos com prova de ausência de caller;
- [ ] includes continuam resolvendo todos os símbolos;
- [ ] falhas de janela, controle, clipboard, modal e timeout têm retorno observável;
- [ ] validações AHK disponíveis foram executadas e seus resultados foram registrados;
- [ ] nenhuma fonte foi apagada apenas por semelhança textual.

## 10. Parsing, registries e fronteiras de macros

Esta seção complementa os contratos de interação com as famílias identificadas no mapa S01. Semelhança textual não é motivo suficiente para apagar uma função: a regra é distinguir fonte única, wrapper de compatibilidade, semântica de domínio e placeholder.

### 10.1 Parsing de listas e parsers de domínio

| Família | Fonte canônica / estado | Regra de canonização | Fatia | Risco / limite |
|---|---|---|---|---|
| Lista CSV simples | `lib/globals/mv/ParseUtils.ahk:ParseListaCsv` | **Fonte única.** `StrSplit` por vírgula, `Trim` e descarte de vazios; não criar variante para `remessas` ou `protocolos`. | S03 | O contrato é CSV simples; não interpretar pipe, linhas ou campos compostos aqui. |
| Protocolos de remessa | `lib/modules/remessa_protocolo/RPParsers.ahk:ParseProtocolos` | Wrapper de domínio preservado: delega para `ParseListaCsv`. `RP_RecordTiming`, `RP_ConvenioMajoritario`, `RP_FiltrarContasPorConvenio` e relatórios continuam semântica RP. | S03 | Confirmar callers antes de remover o nome público. |
| Remessas do Protocolar | `lib/modules/protocolar/ProtocolarParsers.ahk:Protocolar_ParseRemessas` | Wrappers de compatibilidade preservados: `Protocolar_ParseRemessas` delega para `ParseListaCsv` e `Protocolar_SplitSemicolonCsvLine` para `MV_SplitSemicolonCsvLine`, ambas em `lib/globals/mv/ParseUtils.ahk`; `Protocolar_ExtractContasFromCsv` escolhe `CD_REG_AMB` para Ambulatorial e `CONTA` para Hospitalar/Internamento, normaliza BOM/cabeçalho, suporta aspas e deduplicação. `Protocolar_Abort` delega para `MV_Abort(msg, true)`. | S03/S05 | O relatório FFCV usa índice 121 para Ambulatorial e 177 para Hospitalar/Internamento; o CSV é consumido antes da tela Protocolação de Envio. |
| Resultado FXML | `lib/modules/fechar_xml/FecharXml.ahk` + `FecharXmlParsers.ahk` | `RunFecharXML` valida remessas/datas, seleciona cada remessa, confirma entrega e chama `TissXml_Gerar`; `FXML_ParseFlowResult` agrega os XMLs. Parsers de payload bruto continuam placeholders não usados. | S05 | O orquestrador usa diretamente os Maps de `Ffcv_ConfirmarEntregaNaTela` e `TissXml_Gerar`; não inventar parser de payload inexistente. |
| Contas dos macros | `test_macros/11_ffcv_remessa_inserir_imprimir.ahk:ParseContasTeste` | Manter local: aceita `Array`, fallback, linhas, pipe e extração numérica. Não transformar em parser global por semelhança com CSV. | S04 | Entrada `Prot. | Conta | Convênio` tem semântica de fixture diferente de `ParseListaCsv`. |
| Tipos de conta | `lib/app/ScriptRegistry.ahk`/`MVConstants.ahk` versus macros `03`/`11` | Preservar a divergência para migração e validação; não corrigir macros nesta fatia. | S04 | Alteração silenciosa pode enviar tipo errado ao Oracle Forms. |

**Contrato validado pelo Context7.** A referência oficial AHK v2 confirma `StrSplit`/`Trim` como primitivas de string e `RegExMatch` como busca com retorno de posição/objeto de match. A canonização mantém a transformação mínima de `ParseListaCsv` e não coloca regras de domínio nos wrappers.

### 10.2 Registries e configuração

- `lib/app/ScriptRegistry.ahk` é o **catálogo canônico**: `gScripts` registra os três scripts e `ValidateScripts` valida `Array`/`Map`, IDs, tipos (`text`, `select`, `date`), formatos e opções. Não duplicar o catálogo nos registries de módulo.
- `RPRegistry.ahk`, `ProtocolarRegistry.ahk` e `FecharXmlRegistry.ahk` são shims de `#Include`, não registros paralelos. `FecharXmlRegistry.ahk` documenta que `FXML_Registry()` foi removida por ser órfã; não reintroduzi-la.
- `lib/config/Paths.ahk` é a fonte única para os diretórios de Documentos, logs e XMLs; não criar resoluções diretas concorrentes sem justificativa de compatibilidade.
- `lib/globals/mv/FFCV_ErrorTemplates.ahk` é o registro canônico de referências visuais/OCR. Artefatos gerados podem ser embutidos no build; `test_macros/13_ffcv_error_popup_detect.ahk` continua ferramenta de diagnóstico, não registry.

Antes de remover símbolo, provar com `rg` todos os callers em `lib/`, `main.ahk`, `tools/` e `test_macros/`, incluindo includes e chamadas indiretas pelo `Dispatcher`. A ausência de chamada não autoriza remover shim que seja include do catálogo.

### 10.3 Fronteiras e migração dos macros

| Macro / família | Compatibilidade / escopo local | Canonização futura | Fatia |
|---|---|---|---|
| `_mv_control_probe.ahk` | Harness de teste com `MV_Test_FindControlByClientPoint`, busca por classe e ações opcionais; deve permanecer isolado para probe/relatório. | Compor `MV_FindControlAtPoint`, `MV_ClickBySpec` e helpers após resolver o P0 de duas definições em `Controls.ahk`. | S03 |
| `03_ffcv_manutencao_remessas.ahk` | Usa teclado/atalhos deliberadamente porque `EditN` do Oracle Forms varia; `T_Poll` e `TIPO_CODIGO` são contratos de teste. | Migrar polling/click só quando houver equivalência provada; manter teclado para campos variáveis e validar tipos. | S03/S04 |
| `11_ffcv_remessa_inserir_imprimir.ahk` | `ParseContasTeste`, `T_PollMs`, `FindControlByClassPrefixAtPoint`, `ClickBySpec`, waits e relatórios têm semântica de teste e `DO_ACTION`. | Delegar busca/click/polling à lib; preservar parser de fixture, relatório e parada em blocker. | S03/S04 |
| `12_fechar_remessa_gerar_xml.ahk` | Waits de Entrega/TISS/XML, teclado, modais e placeholder de saída são específicos do fluxo. | Migrar polling/click/set-text/modal à lib em S04; resolver FXML, includes e OCR em S05. | S04/S05 |
| `13_ffcv_error_popup_detect.ahk` | Diagnóstico visual; chama `FFCV_ErrorTemplates`, não trata texto do Forms como fonte confiável e não fecha modal por padrão. | Preservar como ferramenta; consolidar includes/API OCR e referências geradas em S05. | S05 |
| `20_login_nav_movdoc_ffcv.ahk` | Caller adicional de polling e estabilidade, fora do conjunto principal desta tarefa. | Incluir no inventário para evitar migração parcial de `T_Poll`/`WaitWindowStable`. | S03 |

### 10.4 Includes/API OCR obsoletos e limites

- O caminho antigo de OCR/API é **compatibilidade obsoleta**, não fonte canônica: o build embute `Praxis_OcrReferences.ahk` e `Praxis_OcrProbe.ahk`, enquanto `FFCV_ErrorTemplates.ahk` mantém fallback de arquivo e chama `tools/ocr-probe.ps1` via PowerShell quando necessário.
- `tools/ocr-probe.ps1` e `tools/build-ocr-error-references.ps1` permanecem a superfície operacional. S05 deve conferir includes opcionais, artefatos gerados e callers antes de remover qualquer API OCR antiga.
- `WinGetText`/Window Spy podem expor apenas `&OK` em modais desenhados `ui60Drawn`; a classificação confiável permanece OCR local/templates e deve deixar erro observável quando referências, subprocesso, JSON ou idioma falharem.
- Includes de produção e caminhos OCR devem permanecer explícitos e verificáveis; os placeholders FXML e a divergência de tipos continuam fora desta consolidação até existir contrato real.

### 10.5 Matriz S03–S05 e checklist de callers

| Família | Regra | Dono |
|---|---|---|
| Poll/find/click/activation | escolher `lib/globals/mv`, preservar wrappers de domínio e resolver P0 antes de remover | S03 |
| `ParseListaCsv` e aliases RP/Protocolar | manter fonte única; provar callers antes de remover aliases | S03 |
| Set-text, waits, modais e relatórios | delegar primitivas, preservar mapas/relatórios/fallbacks | S04 |
| `ParseContasTeste`, macros e tipos | manter fixtures locais e migrar equivalências provadas | S04 |
| FXML, registries órfãos e OCR/includes | implementar com contratos reais; retirar APIs obsoletas após prova de ausência | S05 |

Checklist obrigatório antes de qualquer remoção:

- [ ] `rg` de definição e caller em `lib/`, `main.ahk`, `tools/` e `test_macros/`;
- [ ] includes diretos e indiretos conferidos, inclusive `ScriptRegistry`/`Dispatcher`;
- [ ] assinatura, unidade (`Secs`/`Ms`) e sentinela de retorno comparadas com esta especificação;
- [ ] wrappers classificados como API de domínio, fixture de teste ou shim de include;
- [ ] entradas vazias, duplicadas, malformadas e timeout cobertas por prova estática ou teste existente;
- [ ] `tools/build-praxis.ps1`, `tools/find-implicit-locals.ps1` e `tools/find-top-level-calls.ps1` executados quando aplicável;
- [ ] bloqueios P0/P1 e placeholders continuam reportados, sem serem apresentados como resolvidos.

### 10.6 Prova de cobertura documental T02

A especificação T02 cobre explicitamente `ParseListaCsv`, `FecharXmlParsers`, `test_macros` e a sequência de migração S03, S04 e S05. Esses marcadores são rastreadores de cobertura do documento, não APIs novas nem autorização para remover wrappers sem o checklist de callers.
