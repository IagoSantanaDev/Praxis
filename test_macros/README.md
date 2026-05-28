# Mini macros de teste AHK v2

Esta pasta contém macros separados para validar o fluxo do MV antes de copiar ClassNN/coordenadas para o script principal.

Estratégias testadas:

- teclado puro para login quando o campo Usuário já abre focado;
- título amplo de janela para detectar módulo aberto, sem depender do título exato da subtela;
- imagens de `Imagens_Debug/` para menus e para sentinela visual de erro/popup (`Erro_Icone.png`);
- prints `ClassNN_*.png` apenas como evidência do Window Spy para extrair `ClassNN` e coordenada Client — não use esses prints como alvo de `ImageSearch`;
- HWND do controle + ClassNN + coordenada Client para campos duplicados;
- double-click + Ctrl+C para ler campos/textfields do Oracle Forms.

## Regra padrão

Os testes vêm em modo seguro. Eles não executam ações reais até você ligar flags no arquivo.

Exemplos:

```ahk
DO_ACTION := false
DO_OPEN   := false
DO_LOGIN  := false
DO_NAV    := false
DO_READ   := false
```

Altere uma flag por vez e rode novamente.

## Arquivos

- `_mv_control_probe.ahk` — biblioteca comum de localização por HWND e helpers de imagem.
- `01_login_identificacao.ahk` — testa o login atual por teclado: usuário → Tab → senha → Enter.
- `02_movdoc_baixa.ahk` — testa o fluxo MOV DOC: detectar/abrir, login, Manutenção → Protocolação → Baixa, F8, leitura de convênio/conta.
- `03_ffcv_manutencao_remessas.ahk` — manutenção de remessas FFCV; usa teclado/atalhos de propósito porque os campos `EditN` da remessa variam conforme quantidade de registros.
- `04_popup_inserir_contas.ahk` — popup de inserir contas na remessa.
- `04_popup_inserir_contas_fluxo.ahk` — versão simples/editável para testar abertura, dropdowns, conta e fechamento do popup por etapas.
- `05_entrega_datas.ahk` — tela de entrega/datas.
- `06_xml_monitoracao_tiss.ahk` — tela Monitoração de Faturamento - TISS.
- `07_xml_gerado.ahk` — tela XML gerado.
- `08_checkbox_recebido_estado.ahk` — testa se o checkbox Recebido expõe estado via `ControlGetChecked`.
- `09_image_detection_benchmark.ahk` — detecta imagens na tela atual e compara cropadas vs prints grandes/tela cheia, com tempo por variação.
- `10_popup_text_capture.ahk` — captura texto de popup/modal ativo, mostra em mensagem, salva em `ultimo_popup.txt` e copia para o clipboard.

## Teste de detecção de imagem

O teste `09_image_detection_benchmark.ahk` não valida uma tela específica. Ele só procura as imagens listadas no que estiver visível no momento.

Escopo padrão:

```ahk
SEARCH_SCOPE := "screen"
```

Se quiser medir somente a janela ativa, sem depender de título específico:

```ahk
SEARCH_SCOPE := "active_window"
```

Use `screen` para comparar prints cropadas e prints de tela cheia sem depender de MOV DOC/FFCV estar com um título específico.

## Cache de coordenadas dos menus

O teste `02_movdoc_baixa.ahk` e o script principal usam modo híbrido para menus:

1. primeira execução: localiza o item por imagem;
2. salva o ponto relativo da janela em `config.ini`, seção `[ImageCache]`;
3. próximas execuções: clica direto no ponto salvo, sem `ImageSearch`.

Para forçar recálculo do cache no teste, use:

```ahk
CLEAR_MENU_CACHE := true
```

Depois volte para:

```ahk
CLEAR_MENU_CACHE := false
```

## Estado do checkbox Recebido

Para descobrir se o Oracle Forms expõe o estado do checkbox:

1. Abra a tela Baixa de Documentos com o checkbox Recebido visível.
2. Rode `08_checkbox_recebido_estado.ahk` com o checkbox em um estado.
3. Mude manualmente o checkbox no MV.
4. Rode o teste de novo.
5. Compare `ControlGetChecked(hwnd)` nos dois relatórios.

Interpretação:

- se mudar entre `0` e `1`, podemos usar estado por controle e remover imagem;
- se der erro, vier vazio, ou não mudar, o estado não está exposto de forma confiável;
- `ControlGetStyle` e `ControlGetExStyle` confirmam características do controle, mas geralmente não indicam marcado/desmarcado.

## Teste recomendado agora

1. Abra o MV ou deixe fechado.
2. Rode `02_movdoc_baixa.ahk` com tudo `false` para validar detecção.
3. Se quiser testar abertura, coloque:

```ahk
DO_OPEN := true
```

4. Se abrir login e quiser testar credencial de teste, coloque também:

```ahk
DO_LOGIN := true
```

5. Depois de estar no MOV DOC, teste navegação:

```ahk
DO_NAV := true
```

6. Quando tiver ClassNN/coordenadas Client de Protocolo, Convênio e Conta, preencha:

```ahk
PROTO_CLASS := "..."
PROTO_X := ...
PROTO_Y := ...

CONVENIO_CLASS := "..."
CONVENIO_X := ...
CONVENIO_Y := ...

CONTA_CLASS := "..."
CONTA_X := ...
CONTA_Y := ...
```

Então teste:

```ahk
DO_READ := true
```

## Onde preencher ClassNN e coordenadas

Use sempre coordenadas **Client** do Window Spy, nunca `Screen`.

Regra importante: arquivo `ClassNN_*.png` é documentação visual do Window Spy. Ele serve para copiar `ClassNN`, `Text`, `Client x/y/w/h` para o macro. Depois disso, o macro deve usar `MV_Test_FindControlByClientPoint`, `ControlClick`, `ControlFocus` ou `ControlSetText` por HWND — não `ImageSearch`.

Exemplo:

```ahk
CONTA_CLASS := "Edit2"
CONTA_X := 350
CONTA_Y := 286
```

Se houver ClassNN repetido, o helper procura o controle que contém ou está mais próximo do ponto Client informado.

## Saída

Cada teste gera:

```text
test_macros\ultimo_resultado.txt
```

O mesmo conteúdo também é copiado para a área de transferência.

## Regra de segurança

Não ligue flags de ação em tela de produção sem revisar os valores.

Teste em etapas: detecção → abertura/login → navegação → leitura → ação de salvar.
