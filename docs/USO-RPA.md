# Como usar a Praxis API no RPA com WebView

Este guia explica como o RPA em AutoHotkey v2 pode usar a API para liberar ou bloquear o acesso a partir de uma tela HTML dentro do WebView.

## Visão geral do fluxo

1. O RPA abre uma tela HTML no WebView.
2. O usuário digita o código de acesso.
3. O JavaScript do HTML envia esse código para a API.
4. A API responde se o acesso está autorizado ou não.
5. Se autorizado, o HTML chama uma função exposta pelo AHK para liberar o RPA.
6. Se não autorizado, o HTML mostra uma mensagem de erro e não inicia a automação.

```text
Usuário -> WebView HTML -> Praxis API -> WebView HTML -> AHK v2 -> RPA liberado
```

## URL base da API

Em desenvolvimento local:

```text
http://localhost:3000
```

Na SquareCloud, use a URL pública gerada pela plataforma:

```text
https://SUA-URL-DA-SQUARECLOUD
```

No HTML do WebView, configure:

```js
const apiBaseUrl = 'https://SUA-URL-DA-SQUARECLOUD';
```

## Endpoint de validação

### Requisição

```http
POST /v1/access/validate
Content-Type: application/json
```

Corpo:

```json
{
  "code": "CODIGO_DIGITADO_PELO_USUARIO"
}
```

### Resposta autorizada

Status HTTP:

```text
200 OK
```

Corpo:

```json
{
  "authorized": true,
  "requestId": "uuid"
}
```

### Resposta negada

Status HTTP:

```text
401 Unauthorized
```

Corpo:

```json
{
  "authorized": false,
  "error": {
    "code": "invalid_code",
    "message": "Código de acesso inválido.",
    "requestId": "uuid"
  }
}
```

## Exemplo de HTML para o WebView

Este exemplo mostra uma tela simples de acesso. Quando a API autoriza, ele tenta chamar uma função do AHK chamada `liberarRpa`.

A forma exata de expor funções do AHK para o JavaScript depende da biblioteca WebView que você está usando. Ajuste o trecho `window.chrome.webview.postMessage`, `window.liberarRpa` ou equivalente conforme sua implementação.

```html
<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Acesso ao RPA</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      max-width: 420px;
      margin: 48px auto;
      padding: 24px;
    }

    label,
    input,
    button {
      display: block;
      width: 100%;
      box-sizing: border-box;
    }

    input,
    button {
      margin-top: 8px;
      padding: 12px;
      font-size: 16px;
    }

    button {
      cursor: pointer;
    }

    #message {
      margin-top: 16px;
      min-height: 24px;
    }
  </style>
</head>
<body>
  <h1>Acesso ao RPA</h1>

  <form id="access-form">
    <label for="access-code">Código de acesso</label>
    <input
      id="access-code"
      name="access-code"
      type="password"
      autocomplete="off"
      placeholder="Digite o código"
      required
    />

    <button id="submit-button" type="submit">Liberar acesso</button>
    <p id="message" role="status"></p>
  </form>

  <script>
    const apiBaseUrl = 'https://SUA-URL-DA-SQUARECLOUD';

    function notifyAhkAccessGranted() {
      // Opção 1: WebView2 costuma disponibilizar window.chrome.webview.postMessage.
      if (window.chrome?.webview?.postMessage) {
        window.chrome.webview.postMessage({ type: 'access-granted' });
        return;
      }

      // Opção 2: algumas bibliotecas permitem expor uma função diretamente no window.
      if (typeof window.liberarRpa === 'function') {
        window.liberarRpa();
        return;
      }

      console.warn('Nenhuma ponte com AHK foi encontrada. Ajuste notifyAhkAccessGranted().');
    }

    document.getElementById('access-form').addEventListener('submit', async (event) => {
      event.preventDefault();

      const input = document.getElementById('access-code');
      const button = document.getElementById('submit-button');
      const message = document.getElementById('message');
      const code = input.value.trim();

      if (!code) {
        message.textContent = 'Digite o código de acesso.';
        return;
      }

      button.disabled = true;
      message.textContent = 'Validando acesso...';

      try {
        const response = await fetch(`${apiBaseUrl}/v1/access/validate`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ code }),
        });

        const result = await response.json();

        if (response.ok && result.authorized === true) {
          message.textContent = 'Acesso autorizado.';
          notifyAhkAccessGranted();
          return;
        }

        message.textContent = result.error?.message || 'Acesso negado.';
        input.value = '';
        input.focus();
      } catch (error) {
        message.textContent = 'Não foi possível validar o acesso. Verifique a conexão.';
      } finally {
        button.disabled = false;
      }
    });
  </script>
</body>
</html>
```

## Pseudocódigo AHK v2

Abaixo está o fluxo recomendado no AHK. O código exato depende da biblioteca WebView usada no seu RPA.

```ahk
#Requires AutoHotkey v2.0

acessoLiberado := false

; 1. Criar/abrir o WebView com o HTML de acesso.
; webview := CriarWebView()
; webview.Navigate("file:///C:/caminho/login.html")

; 2. Registrar um callback para receber mensagem do JavaScript.
; A forma exata varia conforme a lib WebView.
;
; Exemplo conceitual:
; webview.OnMessage((message) => {
;     global acessoLiberado
;
;     if (message.type = "access-granted") {
;         acessoLiberado := true
;         IniciarRpa()
;     }
; })

IniciarRpa() {
    ; Coloque aqui o início real da automação.
    ; Só chame esta função depois de a API responder authorized: true.
    MsgBox "Acesso autorizado. Iniciando RPA..."
}
```

## Teste manual da API antes de usar no RPA

Antes de integrar no WebView, teste se a API está online:

```text
https://SUA-URL-DA-SQUARECLOUD/health
```

A resposta deve conter:

```json
{
  "status": "ok",
  "accessConfigured": true
}
```

Se `accessConfigured` vier `false`, significa que nenhum código foi configurado na API.

## Regras importantes

- Não coloque o código aceito hardcoded no HTML.
- O HTML deve apenas enviar o que o usuário digitou.
- A liberação do RPA deve acontecer somente depois de `authorized: true`.
- Em produção, prefira configurar o código na SquareCloud usando a variável `ACCESS_CODES`.
- Se trocar o código na SquareCloud, reinicie/republique a aplicação se a plataforma não aplicar variáveis automaticamente.
- Não registre o código digitado em logs do RPA.

## Problemas comuns

### `accessConfigured: false`

A API está online, mas não encontrou códigos configurados.

Corrija configurando uma destas opções:

```text
ACCESS_CODES
```

ou, localmente:

```text
config/access-codes.json
```

### Erro de CORS no WebView

Por padrão, a API usa:

```text
ALLOWED_ORIGINS=*
```

Isso costuma funcionar bem com WebView local. Se você restringir `ALLOWED_ORIGINS`, garanta que a origem usada pelo WebView esteja permitida.

### `401 invalid_code`

O código enviado pelo HTML não está na lista de códigos aceitos pela API.

### `422 invalid_payload`

O HTML não enviou o JSON no formato esperado. O corpo precisa ser:

```json
{
  "code": "texto"
}
```

### API não abre na SquareCloud

Verifique:

1. Se `squarecloud.app` está no ZIP.
2. Se `package.json` está no ZIP.
3. Se `src/server.js` está no ZIP.
4. Se a aplicação é Node.js.
5. Se a plataforma configurou a porta automaticamente em `PORT`.

## Resumo para integração

No WebView:

```js
const response = await fetch(`${apiBaseUrl}/v1/access/validate`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ code }),
});

const result = await response.json();

if (response.ok && result.authorized) {
  // Chamar AHK e liberar o RPA.
}
```
