# Contexto para continuar — RPA MV2000i

Última atualização: 2026-05-19

Este arquivo preserva o contexto da conversa antes de desligar o PC. Leia este arquivo antes de retomar o trabalho.

## Objetivo atual

Tornar o macro AutoHotkey do fluxo MOV DOC + FFCV mais robusto usando a estratégia correta:

- **Menus e sentinelas visuais** podem usar `ImageSearch`/cache quando não houver controle confiável.
- **Prints do Window Spy / `ClassNN_*.png` não devem virar `ImageSearch`**. Eles servem para extrair `ClassNN`, `Text` e coordenadas **Client x/y** e depois automatizar por controle/HWND.
- Campos variáveis do Oracle Forms, especialmente grids/listas com `EditN` instável, devem continuar por teclado/atalhos se isso for mais confiável.

## Decisões importantes

### 0. MOV DOC/FFCV sempre abrem uma nova instância da tela funcional

Mesmo que o módulo MOV DOC ou FFCV já esteja aberto e até pareça estar na tela correta, o fluxo principal deve sempre abrir/navegar para uma nova instância da tela funcional necessária no início da etapa:

- MOV DOC: abrir nova tela **Baixa de Documentos** para iniciar coleta por protocolo.
- FFCV: abrir nova tela **Manutenção de Remessa** para criar/selecionar remessa.
- XML/TISS: abrir nova tela de **Monitoração/Geração XML** antes de gerar o arquivo.

Motivo: reaproveitar uma tela já aberta deixa estado residual do Oracle Forms (modo consulta, foco, grid, `EditN`, popup anterior, registro atual) e é provável causa de instabilidade. Detectar módulo aberto ainda pode evitar relogar, mas não deve pular a abertura da tela funcional.

### 0.1. Convênio majoritário define a remessa

Quando um protocolo retornar contas de convênios diferentes no MOV DOC, o fluxo deve escolher o convênio com maior quantidade de contas válidas e criar/inserir remessa apenas para esse convênio. As contas dos demais convênios devem ir para o array de erros no padrão:

```text
Número do protocolo | Número da conta | Convênio diferente: <número do convênio>
```

Exemplo: se o protocolo tiver 3 contas do convênio `921` e 1 conta do convênio `922`, a remessa deve ser criada para o convênio `921`; a conta do convênio `922` deve ser registrada como erro `Convênio diferente: 922`.

### 0.2. Abertura dos módulos somente por atalhos locais

O MV2000i não abre de forma confiável apenas com o comando completo `C:\orant\BIN\ifrun60.EXE E:\Mv2000\movdoc\movdoc.fmx` quando o processo não inicia dentro da pasta do módulo. A automação agora exige atalhos locais em:

```text
atalhos/MOVDOC.lnk
atalhos/FFCV.lnk
```

A pasta `atalhos/` fica ignorada no Git porque os `.lnk` dependem do PC da empresa. Não há fallback para `ifrun60`: se o atalho obrigatório não existir, o fluxo deve falhar de forma explícita.

### 0.3. MOV DOC usa região Client e qualquer `Edit*`, não `EditN` fixo

Os dados de `test_macros/02_movdoc_baixa.ahk` e `Fluxos/Fluxo_MovDoc` mostraram que o mesmo `Edit2` pode representar Protocolo em um estado e Conta em outro. A coleta principal deve usar coordenadas Client estáveis e localizar qualquer controle `Edit*` naquela região:

```text
Protocolo: x=21,  y=106
Conta:     x=252, linhas y=222/245/268/291
Convênio:  x=491, mesmas linhas da conta
```

A leitura deve usar somente `ControlGetText(hwnd)` com validação numérica, sem fallback por clipboard. Isso é possível sem `EditN` fixo porque o script primeiro localiza o `hwnd` de qualquer `Edit*` na região Client esperada e depois chama `ControlGetText(hwnd)`. Como o grid desce apenas uma linha por `{Down}`, a automação usa a opção C de custo-benefício: coleta as 4 linhas visíveis, envia até 4 `{Down}`, coleta novamente, para se o popup aparecer ou se nenhum item novo for adicionado.

### 0.4. Popups validados usam `ClassNN` sem coordenada

Para popups modais já validados em que há um único botão de ação (`Button1`, texto `&OK`), o script principal deve clicar o primeiro controle com esse `ClassNN`, sem exigir Client x/y e sem fallback por `Enter`. Coordenadas Client em popup só são necessárias se houver botões duplicados ou ambiguidade.

### 1. `ClassNN_*.png` é evidência, não alvo de clique por imagem

Arquivos como estes são prints do Window Spy:

- `Imagens_Debug/ClassNN_FecharContas.png`
- `Imagens_Debug/ClassNN_CaminhoXML.png`
- `Imagens_Debug/ClassNN_SalvarXML.png`
- `Imagens_Debug/ClassNN_VoltarXML.png`

Eles foram usados para copiar dados como:

```text
ClassNN: Button4
Client: x:623 y:471
```

Depois disso, o script deve usar helpers como:

```ahk
MV_ClickControlAt(winTitle, classNN, clientX, clientY)
MV_FocusControlAt(winTitle, classNN, clientX, clientY)
MV_SetTextControlAt(winTitle, classNN, clientX, clientY, value)
```

Não usar:

```ahk
MV_ClickImage(RP_IMG_...)
```

para esses prints do Window Spy.

### 2. Manutenção de Remessa FFCV fica por teclado/atalhos

O usuário explicou que os campos da remessa têm `ClassNN`, mas os `EditN` variam muito conforme:

- quantidade de remessas do convênio;
- estado inicial da tela;
- posição/registro da grid.

Portanto, **não converter `03_ffcv_manutencao_remessas.ahk` nem as funções equivalentes do principal para `ClassNN` fixo nos campos da remessa** sem nova validação.

Manter esse fluxo funcional por teclado:

```text
F7 → convênio → F8
Tab x3
F7 → remessa → F8
F6 → data → Tab x3 → tipo → F10
```

Isso já foi registrado em comentários em:

- `test_macros/03_ffcv_manutencao_remessas.ahk`
- `scripts/remessa_protocolo.ahk`
- `test_macros/README.md`

## Alterações relevantes feitas nesta conversa

### Retomada atual

1. `scripts/mv_session.ahk` ganhou `MV_ControlCheckedAt(winTitle, classNN, clientX, clientY)` para ler checkbox por HWND/controle com `ControlGetChecked`.
2. `scripts/remessa_protocolo.ahk` passou a tratar o checkbox **Recebido** somente como estado de controle: se `Button1 @ Client 718,359` estiver desmarcado (`0`), clica uma vez; se estiver marcado (`1`), aplica double click; se o estado não puder ser lido, aborta sem fallback por imagem.
3. `scripts/mv_session.ahk` também passou a detectar popup de erro de login pelo título `Mensagem do MV2000 ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE` e fechar somente pelo primeiro `Button1` do modal, sem fallback por `Enter` e sem coordenadas x/y.
4. `scripts/mv_session.ahk` passou a exigir `atalhos/MOVDOC.lnk` e `atalhos/FFCV.lnk`; não há fallback para `ifrun60`/`WorkingDir`.
5. `scripts/mv_session.ahk` ganhou helpers de `Edit*` por região Client (`MV_SetTextEditAtPoint`, `MV_FocusEditAtPoint`, `MV_ReadEditAtPoint`) para não depender de `EditN` fixo; a leitura da grid usa somente `ControlGetText(hwnd)`, sem clipboard.
6. `scripts/remessa_protocolo.ahk` passou a abrir MOV DOC, FFCV e XML/TISS por atalhos de menu, sempre criando nova tela funcional, e a coletar linhas MOV DOC como `{protocolo, conta, convenio}` por região Client.
7. `scripts/remessa_protocolo.ahk` agora usa a opção C de paginação: coleta 4 linhas visíveis, envia até 4 setas para baixo, coleta novamente, e para quando aparece popup ou quando nenhuma conta nova entra.
8. `scripts/remessa_protocolo.ahk` agora escolhe o convênio majoritário e envia à remessa apenas as contas desse convênio; as demais entram em erros como `Convênio diferente: <convênio>`.
9. `scripts/remessa_protocolo.ahk` teve as detecções por imagem removidas do fluxo principal; onde não houver janela/controle validado, o fluxo deve falhar explicitamente em vez de usar imagem/Enter como fallback.
10. `test_macros/01_login_identificacao.ahk` e `test_macros/02_movdoc_baixa.ahk` foram alinhados com as regras novas: login por título de popup, abertura por atalho obrigatório e MOV DOC por região Client.
11. Verificação local executada: `git diff --check -- scripts/mv_session.ahk scripts/remessa_protocolo.ahk test_macros/02_movdoc_baixa.ahk docs/CONTEXTO_CONTINUAR.md .gsd/DECISIONS.md` passou sem erros. AutoHotkey não está disponível no PATH deste ambiente, então a validação executável ainda precisa ocorrer no PC da empresa.

### `scripts/remessa_protocolo.ahk`

1. Botão **Fechar contas sem imprimir faturas** deixou de usar imagem e passou a usar controle:

```ahk
FFCV_BTN_FINALIZAR     := "Button3"
FFCV_BTN_FINALIZAR_X   := 541
FFCV_BTN_FINALIZAR_Y   := 242
```

Uso no fluxo:

```ahk
MV_ClickControlAt(WIN_FFCV_DATAS, FFCV_BTN_FINALIZAR, FFCV_BTN_FINALIZAR_X, FFCV_BTN_FINALIZAR_Y)
```

2. Tela **XML gerado** deixou de usar imagem para caminho/salvar/voltar e passou a usar controles:

```ahk
XML_FORM_CAMPO_PATH   := "Edit1"
XML_FORM_CAMPO_PATH_X := 267
XML_FORM_CAMPO_PATH_Y := 467

XML_FORM_BTN_SALVAR   := "Button4"
XML_FORM_BTN_SALVAR_X := 623
XML_FORM_BTN_SALVAR_Y := 471

XML_FORM_BTN_VOLTAR   := "Button7"
XML_FORM_BTN_VOLTAR_X := 731
XML_FORM_BTN_VOLTAR_Y := 470
```

3. Removidas referências mortas às imagens de controle:

```text
RP_IMG_FECHAR_CONTAS
RP_IMG_CAMINHO_XML
RP_IMG_SALVAR_XML
RP_IMG_VOLTAR_XML
```

4. Comentários da seção FFCV foram ajustados para explicar que os campos variáveis da Manutenção de Remessa continuam por teclado/atalhos.

### Mini macros alterados/criados

#### `test_macros/05_entrega_datas.ahk`

Foi configurado parcialmente com dados já enviados pelo usuário:

```ahk
DATAS_CHECKBOX      → Button3,  x 541, y 242
DATAS_BTN_CONFIRMAR → Button10, x 30,  y 426
```

Ainda podem ficar pendentes/por teclado:

```text
DATAS_CAMPO_REMESSA
DATAS_CAMPO_ENTREGA
DATAS_CAMPO_VENCIMENTO
DATAS_BTN_VOLTAR
```

#### `test_macros/06_xml_monitoracao_tiss.ahk`

Foi configurado:

```ahk
XML_BTN_FATURAMENTO → Button7, x 55, y 458
```

Ainda pendentes se quiser robustez maior:

```text
XML_CAMPO_REMESSA
XML_BTN_BUSCAR
XML_BTN_SAIR_TELA
```

Mas o fluxo atual pode continuar por teclado (`Tab x5 → remessa → F8`) se estiver funcionando.

#### `test_macros/07_xml_gerado.ahk`

Foi alinhado com o script principal:

```ahk
XML_FORM_CAMPO_PATH → Edit1,   x 267, y 467
XML_FORM_BTN_SALVAR → Button4, x 623, y 471
XML_FORM_BTN_VOLTAR → Button7, x 731, y 470
```

Nomes antigos removidos no mini macro:

```text
XML_FORM_BTN_ENVIAR
XML_BTN_SAIR_FORM
```

#### `test_macros/04_popup_inserir_contas_fluxo.ahk`

Arquivo novo criado para testar o fluxo do popup de inserir contas de forma simples e editável.

Flags principais:

```ahk
DO_OPEN_POPUP       := false
DO_ACTION           := false
DO_CONFIG_DROPDOWNS := false
DO_SEND_ACCOUNT     := false
DO_CLOSE_POPUP      := false
```

Campos que o usuário deve configurar com Window Spy:

```ahk
WIN_POPUP
POPUP_DROPDOWN_1_CLASS / X / Y
POPUP_DROPDOWN_2_CLASS / X / Y
POPUP_CAMPO_CONTA_CLASS / X / Y
POPUP_BTN_OK_CLASS / X / Y
MODAL_BTN_OK_CLASS / X / Y
```

Uso recomendado:

1. abrir popup manualmente;
2. configurar `WIN_POPUP`;
3. rodar com `DO_ACTION := false`;
4. configurar controles pelo Window Spy;
5. ligar uma etapa por vez.

#### `test_macros/10_popup_text_capture.ahk`

Arquivo novo criado para capturar texto de popup/modal.

Ele:

- procura `ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE`;
- captura `WinGetText`;
- mostra em `MsgBox`;
- salva em `test_macros\ultimo_popup.txt`;
- copia para o clipboard com `A_Clipboard := content`.

Não clica, não fecha popup e não envia teclas para o MV.

## Como levar para o PC da empresa

Copiar pelo menos:

```text
scripts/
test_macros/
Imagens_Debug/
```

Idealmente copiar o projeto inteiro mantendo a estrutura:

```text
RPA MV2000i/
  scripts/
  test_macros/
  Imagens_Debug/
```

Precisa de **AutoHotkey v2** instalado.

Rodar os `.ahk` a partir da pasta `test_macros/` ou mantendo os caminhos relativos intactos.

## O que configurar em cada mini macro

### `02_movdoc_baixa.ahk` — crítico

Configurar com Window Spy:

```ahk
PROTO_CLASS / PROTO_X / PROTO_Y
CONVENIO_CLASS / CONVENIO_X / CONVENIO_Y
CONTA_CLASS / CONTA_X / CONTA_Y
```

Confirmar se ainda vale:

```ahk
RECEB_CLASS := "Button1"
RECEB_X := 718
RECEB_Y := 359
```

### `03_ffcv_manutencao_remessas.ahk`

Não mapear os campos variáveis por `ClassNN` fixo. Ajustar apenas dados de teste e flags:

```ahk
TEST_CONVENIO
TEST_REMESSA
TEST_TIPO_CONTA
DO_NAV
DO_LOAD_CONVENIO
DO_SELECT_OR_CREATE_REMESSA
```

### `04_popup_inserir_contas_fluxo.ahk` — importante

Configurar:

```ahk
WIN_POPUP
POPUP_DROPDOWN_1_CLASS / X / Y
POPUP_DROPDOWN_2_CLASS / X / Y
POPUP_CAMPO_CONTA_CLASS / X / Y
POPUP_BTN_OK_CLASS / X / Y, se existir
MODAL_BTN_OK_CLASS / X / Y, se houver modal de erro/aviso
```

### `05_entrega_datas.ahk`

Já tem checkbox e confirmar. Se necessário, configurar campos de data e voltar.

### `06_xml_monitoracao_tiss.ahk`

Já tem botão Faturamento. Se necessário, configurar campo remessa/buscar/sair.

### `07_xml_gerado.ahk`

Já configurado com os dados enviados. Confirmar no PC da empresa se as coordenadas Client batem.

### `10_popup_text_capture.ahk`

Normalmente não precisa configurar. Se quiser alvo específico, ajustar:

```ahk
POPUP_TITLE := "..."
```

## Regra para Window Spy

Sempre copiar:

```text
ClassNN
Client x
Client y
```

Nunca usar `Screen x/y`.

## Resultados dos testes

Os mini macros salvam relatórios em:

```text
test_macros\ultimo_resultado.txt
```

O capturador de popup salva em:

```text
test_macros\ultimo_popup.txt
```

Esses arquivos podem ser colados na próxima conversa para continuar.

## Próxima ação concreta ao retomar

1. No PC da empresa, rodar `test_macros/10_popup_text_capture.ahk` com um popup aberto para validar captura.
2. Validar `test_macros/07_xml_gerado.ahk` porque já está quase todo configurado.
3. Configurar e validar `test_macros/04_popup_inserir_contas_fluxo.ahk`, pois o popup de inserir contas é o trecho mais sensível.
4. Configurar e validar `test_macros/02_movdoc_baixa.ahk`, pois MOV DOC é crítico para coletar protocolo/convênio/contas.
5. Quando os mini macros estiverem configurados e funcionando, ler os `.ahk` validados e aplicar os valores ao principal `scripts/remessa_protocolo.ahk`.

## Atenções / não fazer

- Não converter campos variáveis da Manutenção de Remessa para `EditN` fixo.
- Não usar `ClassNN_*.png` com `MV_ClickImage`.
- Não usar coordenada `Screen`; usar sempre `Client` do Window Spy.
- Não ligar `DO_ACTION := true` antes de rodar uma vez em modo seguro e conferir o relatório.
- Não assumir que todas as mudanças no `git status` foram feitas nesta conversa; já havia alterações não commitadas no projeto.

## Verificações feitas nesta sessão

Foram executadas validações estáticas com:

```text
git diff --check
```

para os arquivos alterados/criados. Passou sem erros.

Não foi possível executar os `.ahk` neste ambiente porque o AutoHotkey não está disponível no PATH/caminhos padrão daqui.
