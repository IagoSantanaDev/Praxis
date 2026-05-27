# Avisos de componentes de terceiros

Este documento lista componentes, bibliotecas, runtimes, ferramentas ou arquivos de terceiros utilizados ou referenciados pelo projeto **Praxis**.

A licença proprietária do Praxis aplica-se ao código, documentação, interface, scripts, fluxos de automação e materiais próprios desenvolvidos para o projeto, mas não altera direitos, licenças ou obrigações relativos a componentes de terceiros.

## Código proprietário do Praxis

- Projeto: Praxis
- Titular declarado: Iago Santana Lima
- Licença: proprietária — todos os direitos reservados
- Escopo: código-fonte próprio, scripts de automação próprios, interface própria, documentação própria, fluxos de automação próprios e materiais técnicos próprios.

## Componentes de terceiros identificados

### AutoHotkey

O projeto é desenvolvido para AutoHotkey v2. AutoHotkey é um software de terceiros e permanece sujeito à sua própria licença, termos e avisos oficiais.

A licença proprietária do Praxis não altera os direitos e obrigações aplicáveis ao AutoHotkey.

### Microsoft Edge WebView2 / WebView2Loader.dll

O projeto utiliza Microsoft Edge WebView2 e/ou `WebView2Loader.dll` para carregar a interface HTML em ambiente desktop.

Esses componentes são de titularidade de seus respectivos proprietários e permanecem sujeitos aos termos, licenças e condições da Microsoft.

### Bibliotecas AutoHotkey em `lib/`

O diretório `lib/` contém ou pode conter bibliotecas AutoHotkey de terceiros, como bibliotecas relacionadas a WebView2, JSON, Promise, ComVar ou outras utilidades.

Antes de distribuir o projeto, verifique os cabeçalhos de cada arquivo e preserve os avisos de autoria, copyright e licença dos respectivos autores originais.

Arquivos identificados neste projeto:

- `lib/WebView2.ahk` — biblioteca de terceiros com cabeçalho de autoria original preservado.
- `lib/JSON.ahk` — biblioteca de terceiros com cabeçalho de autoria original preservado.
- `lib/Promise.ahk` — biblioteca de terceiros com cabeçalho de autoria original preservado.
- `lib/ComVar.ahk` — biblioteca de terceiros/utilidade COM; licença de origem a confirmar antes de distribuição externa.
- `lib/64bit/WebView2Loader.dll` — componente relacionado ao Microsoft Edge WebView2.

## Obrigação de preservação

Ao copiar, distribuir internamente, empacotar ou preparar build do Praxis, preserve todos os avisos de copyright, licença e atribuição de terceiros exigidos pelas respectivas licenças.

## Pendências

Antes de qualquer distribuição comercial ou externa, confirme:

- licença exata de cada arquivo em `lib/`;
- obrigações de atribuição;
- obrigação ou não de incluir cópia da licença original;
- possibilidade de distribuição junto com software proprietário;
- requisitos de distribuição do WebView2 Runtime/WebView2Loader;
- obrigações aplicáveis ao uso/distribuição do AutoHotkey.
