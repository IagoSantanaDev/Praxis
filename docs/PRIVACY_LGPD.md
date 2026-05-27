# Política Operacional de Privacidade, Segurança e LGPD — Praxis

> Modelo operacional. Este documento deve ser revisado por advogado ou responsável de privacidade antes de uso contratual real.

## 1. Finalidade

Esta política orienta o uso, desenvolvimento, teste, suporte, debug e distribuição do software **Praxis** em ambientes que possam envolver dados pessoais, dados sensíveis, credenciais, informações hospitalares, XMLs, protocolos, contas, guias, prints, logs e evidências operacionais.

## 2. Princípios

O Praxis deve ser utilizado com observância aos seguintes princípios:

- minimização de dados;
- necessidade;
- finalidade específica;
- segurança;
- confidencialidade;
- rastreabilidade;
- prevenção de vazamentos;
- não exposição de dados sensíveis;
- respeito às políticas internas do ambiente autorizado.

## 3. Dados que não devem ser versionados

É proibido commitar, publicar, compartilhar ou enviar para repositórios, chats, ferramentas de IA, serviços online ou ambientes não autorizados:

- credenciais, senhas, tokens, chaves ou arquivos de configuração sensíveis;
- `config.ini`, `.env`, logs e dumps;
- prints de sistemas hospitalares com dados reais;
- nomes de pacientes, CPF, cartão SUS, convênios, matrículas ou identificadores;
- XMLs reais, guias, contas, protocolos ou relatórios contendo dados reais;
- imagens de debug com informação sensível;
- dados de usuários internos, operadores, médicos, prestadores ou setores;
- caminhos de rede, servidores, bases, endpoints ou informações de infraestrutura sensível.

## 4. Logs

Logs devem ser mínimos e técnicos. Sempre que possível, devem registrar apenas:

- data/hora;
- etapa executada;
- status da operação;
- código técnico não sensível;
- mensagens de erro sem dados pessoais.

Evite logs contendo:

- nome de paciente;
- documentos;
- dados de saúde;
- senhas;
- usuário e senha do ERP;
- XML completo;
- número de guia ou conta quando permitir identificação indevida;
- prints automáticos com dados reais.

## 5. Prints e imagens de debug

Imagens de debug devem ser tratadas como informação confidencial.

Antes de compartilhar, versionar ou usar imagens em documentação:

- oculte dados pessoais;
- oculte dados de pacientes;
- oculte credenciais;
- oculte nomes de usuários internos;
- oculte identificadores de ambiente;
- use dados fictícios sempre que possível.

A pasta `Imagens_Debug/` deve permanecer fora do versionamento sempre que contiver evidências reais ou sensíveis.

## 6. Credenciais

Credenciais não devem ser armazenadas em texto puro. Quando necessário, devem ser protegidas por mecanismos locais seguros, como DPAPI do Windows ou solução equivalente aprovada.

Credenciais não devem aparecer em:

- logs;
- prints;
- documentação;
- mensagens de erro;
- commits;
- prompts;
- arquivos enviados a terceiros.

## 7. Ambientes autorizados

O Praxis só deve ser executado em ambiente autorizado, conforme contrato, EULA, proposta, termo interno ou autorização formal.

É proibido usar o software em outro hospital, CNPJ, unidade, setor, máquina, usuário, base de dados, ambiente de teste ou produção sem autorização prévia e expressa.

## 8. Uso de ferramentas de IA

Antes de enviar trechos de código, logs, prints, XMLs, documentação ou dados de ambiente para ferramentas de IA, remova informações sensíveis e confirme se há autorização para esse compartilhamento.

Nunca envie dados reais de pacientes, credenciais, telas internas sensíveis ou informações protegidas por sigilo para ferramentas externas sem autorização adequada.

## 9. Incidentes

Qualquer perda, vazamento, compartilhamento indevido, acesso não autorizado ou exposição acidental de dados, código, credenciais, logs ou prints deve ser comunicado imediatamente ao responsável pelo projeto e, quando aplicável, ao responsável de segurança/privacidade do ambiente afetado.

## 10. Responsabilidades

Usuários, desenvolvedores, prestadores, agentes de IA, consultores e operadores que tenham acesso ao Praxis devem cumprir esta política, o `LICENSE`, o `EULA.md`, o `NDA.md`, o `NOTICE.md` e as regras internas do ambiente autorizado.
