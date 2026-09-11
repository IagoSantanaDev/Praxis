# Avisos de componentes de terceiros

Este documento lista os componentes, bibliotecas, runtimes, ferramentas e arquivos de terceiros usados ou referenciados pelo projeto **Praxis**.

A licença proprietária do Praxis cobre o código, a documentação, a interface, os scripts, os fluxos de automação e os materiais próprios do projeto. Ela não altera os direitos, as licenças nem as obrigações referentes a componentes de terceiros.

## Código proprietário do Praxis

- Projeto: Praxis
- Titular declarado: Iago Santana Lima
- Licença: proprietária — todos os direitos reservados
- Escopo: código-fonte próprio, scripts de automação próprios, interface própria, documentação própria, fluxos de automação próprios e materiais técnicos próprios.

## Componentes de terceiros identificados

### AutoHotkey v2 / Ahk2Exe

O projeto foi desenvolvido para AutoHotkey v2 e o executável de distribuição pode ser gerado pelo Ahk2Exe usando o binário base do AutoHotkey.

- Projeto upstream: AutoHotkey
- Site/repositório: <https://www.autohotkey.com/> / <https://github.com/AutoHotkey/AutoHotkey>
- Licença identificada no repositório oficial da série v2: GNU General Public License v2, com avisos adicionais de componentes como PCRE/BSD no arquivo de licença upstream.

A licença proprietária do Praxis não altera os direitos e as obrigações aplicáveis ao AutoHotkey, ao Ahk2Exe, ao binário base incorporado no executável compilado ou aos componentes de terceiros distribuídos junto com o AutoHotkey.

Ao distribuir builds compilados, preserve os avisos exigidos pelo AutoHotkey e disponibilize aos destinatários os termos de licença aplicáveis ao componente usado para gerar o executável.

### Microsoft Edge WebView2 / WebView2Loader.dll

O projeto utiliza Microsoft Edge WebView2 e/ou `WebView2Loader.dll` para carregar a interface HTML em ambiente desktop.

- Titular: Microsoft Corporation
- Componentes no projeto: `lib/64bit/WebView2Loader.dll` e, quando presente, `lib/32bit/WebView2Loader.dll`
- Documentação e termos oficiais: <https://developer.microsoft.com/microsoft-edge/webview2/>

Esses componentes são de propriedade de seus respectivos titulares e continuam sujeitos aos termos, licenças e condições da Microsoft. A licença proprietária do Praxis não concede direitos sobre Microsoft Edge, WebView2 Runtime, SDK, loader ou qualquer outro componente Microsoft.

Antes da distribuição externa, confirme se a forma de empacotamento escolhida usa runtime evergreen, bootstrapper, fixed version runtime ou apenas loader, e preserve os avisos e licenças exigidos pela Microsoft para esse modelo.

### Bibliotecas AutoHotkey de `thqby/ahk2_lib`

O diretório `lib/` contém bibliotecas AutoHotkey de terceiros originadas ou derivadas do projeto `thqby/ahk2_lib`.

- Projeto upstream: <https://github.com/thqby/ahk2_lib>
- Licença identificada: MIT License
- Componentes identificados neste projeto:
  - `lib/WebView2.ahk`
  - `lib/JSON.ahk`
  - `lib/Promise.ahk`
  - `lib/ComVar.ahk`

Os cabeçalhos de autoria preservados nos arquivos indicam autoria de `thqby`, e em `JSON.ahk` também há derivação ou modificação de trabalho de HotKeyIt/Yaml. A licença MIT permite uso, cópia, modificação e distribuição, inclusive junto de software proprietário, desde que o aviso de copyright e a permissão sejam incluídos em todas as cópias ou porções substanciais do software.

#### Texto da licença MIT aplicável a `thqby/ahk2_lib`

```text
MIT License

Copyright (c) 2023 thqby

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Obrigação de preservação

Ao copiar, distribuir internamente, empacotar ou preparar um build do Praxis, preserve todos os avisos de copyright, licença e atribuição de terceiros exigidos pelas respectivas licenças.

Em especial:

- não remova os cabeçalhos de autoria dos arquivos em `lib/`;
- inclua este documento ou equivalente nos pacotes distribuídos quando houver componentes de terceiros;
- deixe claro que a licença proprietária do Praxis cobre apenas o código e os materiais próprios;
- confirme as obrigações do AutoHotkey/Ahk2Exe e do WebView2 conforme o formato real do build distribuído.

## Pendências antes da distribuição comercial ou externa

Antes de qualquer distribuição comercial ou externa, confirme com revisão técnica e jurídica:

- as obrigações exatas da licença AutoHotkey/Ahk2Exe no modelo de executável gerado;
- os requisitos de distribuição do Microsoft Edge WebView2 Runtime/WebView2Loader;
- se o pacote final inclui todos os notices e textos de licença exigidos;
- se o pacote portátil apresenta e disponibiliza corretamente os avisos de terceiros.
