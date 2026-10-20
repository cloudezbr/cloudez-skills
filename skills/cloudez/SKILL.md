---
name: cloudez
description: >
  Desenvolve, publica e mantém sites na hospedagem Cloudez: login e criação de
  conta, contratação de cloud, ligação do projeto a um site, escrita do Docker
  Compose, execução local, deploy com ativação atômica da release, conversão de
  sites WordPress ou html para o tipo Claude e rollback para uma versão anterior.
  Use sempre que o usuário mencionar a Cloudez, ou pedir para subir, publicar,
  colocar no ar ou fazer deploy de um site, voltar uma versão, ver as releases,
  containerizar o projeto ou criar o docker-compose para produção, mesmo sem
  dizer "Cloudez", quando o projeto tiver um .cloudez.yaml. Não use para deploy
  em outros provedores (Vercel, Netlify, AWS) nem para Docker sem relação com a
  Cloudez.
license: MIT
compatibility: Requer o servidor MCP "cloudez" registrado no agente, Node 20+, ssh e tar.
metadata:
  author: cloudez
  version: "0.3.0"
---

# Cloudez

Leva um projeto da máquina do usuário até um site no ar na Cloudez, e de volta
para uma versão anterior quando algo quebra. O procedimento de cada operação
mora em `references/`; este arquivo diz qual ler e as regras que valem para
todas.

## Modelo da Cloudez

- **Conta**: o que paga. A Cloudez é white-label: o painel da conta pode ter o
  domínio de uma revenda, e é esse que se mostra ao usuário.
- **Cloud**: o servidor contratado. Uma conta tem uma ou mais.
- **Site**: um domínio hospedado numa cloud. Só um site do tipo **Claude**
  recebe deploy por esta skill; os de outro tipo (WordPress, html) passam antes
  pela conversão.
- **Environment**: uma chave dentro de `cloudez:` no `.cloudez.yaml` do projeto
  (`staging`, `production`...), cada uma apontando para um site.
- **Release**: um diretório em `<root>/releases/<release_id>` no servidor. O
  symlink **`current`** aponta para a ativa, e o diretório **`shared/`**, irmão
  de `releases/`, guarda o dado que sobrevive à troca de release.

## Quem faz o quê

| Peça | Faz | Não faz |
| --- | --- | --- |
| MCP `cloudez` (tools `cloudez_*`) | o control plane: descobre o destino, registra a release, ativa, reverte, consulta a conta | nunca move bytes |
| `scripts/` desta skill | o que precisa da máquina local: enviar e baixar arquivos (tar sobre ssh), criar o `.cloudez.yaml`, guardar o token | não decide nada sozinho; devolve JSON para você decidir |
| O usuário | o que exige um terminal de verdade: digitar o token | |

## Antes de qualquer operação

1. **O MCP está presente?** Se nenhuma tool `cloudez_*` estiver disponível,
   pare. Diga em uma frase que falta o servidor da Cloudez no agente e mostre a
   seção de configuração do README desta skill
   (<https://github.com/cloudezbr/cloudez-skill#configuração>). Não tente
   chegar à API por outro caminho: sem o MCP, nenhuma operação tem como
   terminar, e uma tentativa no escuro só adia a mesma resposta.
2. **Autenticação.** Chame `cloudez_auth_status`. Com `authenticated: false`,
   siga [login.md](references/login.md) e só depois volte à operação pedida.
   Fica aqui, e não em cada procedimento, porque quem chega em linguagem natural
   é justamente quem nunca fez login, e descobrir a falta de token no meio de um
   deploy interrompe a conversa no pior lugar. Com `authenticated: true`, siga
   em silêncio: "você está autenticado" é ruído para quem pediu outra coisa.

A exceção é [dev.md](references/dev.md): rodar o site localmente não toca a
Cloudez e não precisa de nenhum dos dois.

## Qual referência ler

Leia só o que a operação pede. Quando o pedido cruza duas áreas, leia as duas e
entregue uma resposta só.

| O usuário quer | Referência |
| --- | --- |
| entrar, criar conta, trocar o token, "meu token expirou" | [login.md](references/login.md) |
| contratar, comprar ou testar uma cloud nova | [hire-cloud.md](references/hire-cloud.md) |
| ligar o projeto a um domínio, criar um environment, "o deploy não acha a configuração" | [setup.md](references/setup.md) |
| criar ou ajustar o docker-compose, containerizar, acrescentar um banco | [compose.md](references/compose.md), que indica quando ler [compose-banco.md](references/compose-banco.md), [compose-supabase.md](references/compose-supabase.md) e [compose-wordpress.md](references/compose-wordpress.md) |
| rodar ou ver o site na máquina dele | [dev.md](references/dev.md) |
| subir, publicar, pôr no ar, fazer deploy | [deploy.md](references/deploy.md) |
| publicar num site que hoje é WordPress ou html, ou baixar esse site para mexer | [convert.md](references/convert.md) |
| voltar uma versão, desfazer o deploy, ver as releases, "o site quebrou depois de publicar" | [rollback.md](references/rollback.md) |

Três distinções que custam caro quando erradas:

- **Reverter é rollback, nunca deploy.** Quem pede para voltar uma versão
  costuma estar com o site fora do ar; mandá-lo para o deploy publica de novo o
  que quebrou.
- **"Sobe o site" é ambíguo.** Pode ser rodar aqui ([dev.md](references/dev.md))
  ou pôr no ar ([deploy.md](references/deploy.md)). Na dúvida, pergunte: um mexe
  em produção e o outro não.
- **Site de outro tipo é conversão.** O deploy confere o tipo e encaminha para
  [convert.md](references/convert.md) quando o site não é do tipo Claude.

## Fluxos compostos

- **Primeiro deploy, do zero:** basta seguir [deploy.md](references/deploy.md).
  Ele conduz o login, o setup e o compose no caminho, na ordem certa.
- **Site WordPress que já existe na Cloudez:** [convert.md](references/convert.md)
  baixa o site, monta o Compose e publica.
- **Site fora do ar depois de um deploy:** [rollback.md](references/rollback.md)
  direto, sem diagnóstico antes. Investigar vem depois de o site voltar.

## Como rodar os scripts

`<skill>` é a pasta onde está este arquivo. Nas referências, todo script aparece
como:

```bash
node "<skill>/scripts/cloudez-sync" <deploy_id> <diretório>
```

Troque `<skill>` pelo caminho absoluto, entre aspas: no Windows a pasta do
usuário costuma ter espaço no nome. É sempre `node` mais o caminho, e não o nome
puro, porque nada põe esta pasta no PATH, e no Windows o shebang não vale nada.

Todo script e toda tool devolvem JSON. Leia o JSON e decida por ele. Exit code
zero, ou a chamada ter voltado, não quer dizer que deu certo.

## O comando que só o usuário roda

`node "<skill>/scripts/cloudez-login"`, sem `--stdin`, exige um terminal
interativo de propósito: o token é digitado num prompt que não ecoa. Digitado na
conversa, ele entraria no contexto e no histórico. Rodado por você, sem
terminal, o script falha com `no_tty`, e o erro já traz o comando pronto, com o
caminho absoluto.

Quando ele for necessário: explique em uma frase o que ele faz, mostre o comando
exato, espere o usuário dizer que rodou e confira com `cloudez_auth_status`. No
Claude Code, o usuário pode enviar o comando com `!` na frente, que executa no
terminal da sessão. O caminho preferido, que dispensa isto, é o do clipboard em
[login.md](references/login.md).

## Regras de execução

1. **O token nunca passa pela conversa.** Não peça, não repita, não use um token
   que o usuário colou no chat: ele já está no histórico, então o caminho é
   gerar outro no painel e entregá-lo pelo script, como diz
   [login.md](references/login.md).
2. **Não escreva na aplicação publicada para testar.** `curl` ou `wget` com
   POST, PUT, PATCH, DELETE, `-d` ou `-F` nos domínios do site, nos subdomínios
   ou nos endereços temporários da Cloudez (`*.cloudezapp.io`,
   `*.configr.cloud`) só com o usuário pedindo aquela escrita. Verificar se algo
   funciona se faz por leitura (GET, HEAD). Testes assim já gravaram um recado
   num mural público e uma imagem num site de uploads, e nos dois casos a
   escrita parecia parte do pedido.
3. **O MCP nunca move bytes.** Enviar e baixar arquivos é sempre
   `cloudez-sync` ou `cloudez-pull`, locais.
4. **Não confira o projeto antes de o procedimento mandar.** Cada referência já
   lê o que precisa no passo certo. Ler antes não acelera nada e é a origem mais
   comum de vazar mecanismo para o usuário (regra 6).
5. **Confirme antes do que é difícil de desfazer:** criar site, converter tipo,
   ativar release, contratar. Cada referência diz onde perguntar.
6. **Não narre o mecanismo.** Nome de campo (`panel_host`), arquivo consultado
   (`.cloudez.yaml`, `Dockerfile`, `docker-compose.yml`), "ainda não
   encontrado": isso é vocabulário de implementação. Diga o resultado que
   importa para o usuário, nos termos dele, e vá direto à pergunta ou à ação
   seguinte. Vale também para o que você descobriu por conta própria, fora de
   qualquer passo.

## Como perguntar e responder

- **Pergunta com opções:** liste as opções numeradas, com uma linha de contexto
  cada, e espere a resposta antes de seguir. Se o agente tiver uma ferramenta
  própria de pergunta com opções, use-a.
- **Ao terminar uma operação:** o que foi feito, o resultado (endereço do site,
  release ativa) e o próximo passo, se houver. Cada referência tem um "Como
  reportar" com o formato exato quando ele importa.
