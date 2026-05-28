# Mini macros de teste AHK v2

Esta pasta contém apenas os macros ainda úteis para validar o fluxo MV2000i antes de aplicar ajustes no script principal.

## Regra padrão

Os testes vêm em modo seguro sempre que executam ações de risco. Primeiro rode com as flags desligadas, confira o relatório e só depois ligue uma etapa por vez.

Exemplos:

```ahk
DO_ACTION := false
DO_INSERT_ACCOUNT := false
DO_GERAR_XML := false
```

Use sempre coordenadas **Client** do Window Spy, nunca `Screen`.

## Arquivos atuais

- `_mv_control_probe.ahk` — biblioteca comum para localizar controles por HWND/ClassNN/ponto Client e gerar relatório.
- `02_movdoc_baixa.ahk` — testa o fluxo MOV DOC: detectar/abrir, navegar para Baixa de Documentos, ler protocolo/conta/convênio e validar checkbox Recebido.
- `10_popup_text_capture.ahk` — captura diagnóstico de popup/modal ativo; enumera `WinGetText`, `WinGetControls`, HWNDs, `ClassNN`, retângulo e texto por controle.
- `11_ffcv_remessa_inserir_imprimir.ahk` — fluxo FFCV integrado: criar/buscar remessa, inserir uma ou várias contas no popup embarcado e imprimir relatório de atendimentos.
- `12_fechar_remessa_gerar_xml.ahk` — continuação do FFCV: entregar/fechar remessa com datas e gerar XML a partir da remessa deixada pelo macro 11.

## Fluxo recomendado de teste

1. Rode `02_movdoc_baixa.ahk` para obter/validar as contas do MOV DOC.
2. Cole as contas em `TEST_CONTAS` no `11_ffcv_remessa_inserir_imprimir.ahk`.
3. Rode o macro 11 com `DO_ACTION := false` para localizar botões e controles.
4. Ligue as etapas do macro 11 uma por vez:

```ahk
DO_NAV := true
DO_LOAD_CONVENIO := true
DO_SELECT_OR_CREATE_REMESSA := true
DO_INSERT_ACCOUNT := true
DO_PRINT_RELATORIO := true
```

5. Depois rode o macro 12 com `DO_ACTION := false`.
6. Ligue as etapas do macro 12 uma por vez:

```ahk
DO_OPEN_ENTREGA := true
DO_CONFIRM_ENTREGA := true
DO_OPEN_XML_TISS := true
DO_GERAR_XML := true
```

## Inserção de várias contas no macro 11

`TEST_CONTAS` aceita conta pura, lista separada por vírgula/ponto-e-vírgula/quebra de linha, ou linhas do MOV DOC no formato `protocolo | conta | convênio`.

Exemplos:

```ahk
TEST_CONTAS := "12960859,12960932,12960430"
```

```ahk
TEST_CONTAS := "
123456 | 12960859 | 930
123456 | 12960932 | 930
123456 | 12960430 | 930
"
```

Quando a linha tem `|`, o macro usa a segunda coluna numérica como conta.

## Popups e modais FFCV

Há dois alvos diferentes:

1. **Popup de inserir conta**: painel embarcado `Informações da Conta`, sem `WinTitle` próprio, detectado por:

```ahk
ui60Drawn W323 @ Client 432,109
Edit2 @ Client 298,143
```

2. **Modal de erro ao inserir conta**: janela própria `Forms ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE`, fechada por `Button1`.

Em modais Oracle Forms, a mensagem visual pode ser desenhada em `ui60Drawn_*`; `WinGetText` e Window Spy podem mostrar apenas `&OK`. Por isso o macro 11 classifica erros conhecidos por template visual.

Template atual:

```text
Imagens_Debug/Erros_FFCV/Erro_Conta_Ja_Digitada_Texto.png
```

Para adicionar outro erro, salve um crop da frase em `Imagens_Debug/Erros_FFCV/` e adicione ao array `ERROR_TEMPLATES` do macro 11.

## Polling rápido no macro 11

O envio em lote não usa `Sleep` longo. Ele faz polling subsegundo:

```ahk
POLL_INTERVAL_MS := 20
NO_MODAL_DECISION_MS := 450
MODAL_WAIT_AFTER_ENTER_MS := 800
```

Se o modal aparecer, reage imediatamente. Se não aparecer e o popup estiver estável, libera a próxima conta em menos de 1 segundo.

## Saídas

Os macros salvam relatórios em:

```text
test_macros\ultimo_resultado.txt
```

O capturador de popup salva em:

```text
test_macros\ultimo_popup.txt
```

Cole esses arquivos na conversa quando precisar continuar a análise.

## Atenções

- Não use `ClassNN_*.png` com `ImageSearch`; esses prints são evidência para copiar `ClassNN` e coordenada Client.
- Não use coordenadas `Screen`.
- Não ligue ações reais antes de rodar em modo seguro.
- Não confunda o popup embarcado `Informações da Conta` com o modal de erro `Forms`.
- Não reduza `NO_MODAL_DECISION_MS` abaixo de ~300ms sem evidência no PC da empresa.
