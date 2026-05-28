# Mini macros de teste AHK v2

Esta pasta contém macros separados para validar o fluxo do MV antes de copiar ClassNN/coordenadas para o script principal.

Estratégias testadas:

- teclado puro para login quando o campo Usuário já abre focado;
- título amplo de janela para detectar módulo aberto, sem depender do título exato da subtela;
- imagens de `Imagens_Debug/` para menus e para sentinela visual de erro/popup (`Erro_Icone.png`);
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
- `03_ffcv_manutencao_remessas.ahk` — manutenção de remessas FFCV.
- `04_popup_inserir_contas.ahk` — popup de inserir contas na remessa.
- `05_entrega_datas.ahk` — tela de entrega/datas.
- `06_xml_monitoracao_tiss.ahk` — tela Monitoração de Faturamento - TISS.
- `07_xml_gerado.ahk` — tela XML gerado.

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
