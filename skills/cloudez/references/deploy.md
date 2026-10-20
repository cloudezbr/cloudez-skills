# Deploy

Quando usar: o usuário pede para subir, publicar, pôr no ar ou fazer deploy do
site na Cloudez. Faz o deploy com ativação atômica da release e rollback.

Entradas: o environment e, opcionalmente, o diretório a publicar.

- [Preparar](#preparar)
  - [0. Autenticação, antes de qualquer coisa](#0-autenticação-antes-de-qualquer-coisa)
  - [1. O alvo: qual environment, qual site](#1-o-alvo-qual-environment-qual-site)
  - [2. O que publicar](#2-o-que-publicar)
  - [3. Medir antes](#3-medir-antes)
- [Publicar](#publicar)
  - [4. Registrar a release](#4-registrar-a-release)
  - [5. Sincronizar](#5-sincronizar)
  - [6. Construir a imagem](#6-construir-a-imagem)
  - [7. Ativar](#7-ativar)
  - [8. Subir o container](#8-subir-o-container)
- [Confirmar](#confirmar)
  - [9. Verificar que o site responde](#9-verificar-que-o-site-responde)
  - [10. Rollback](#10-rollback)
- [Como reportar](#como-reportar)
- [Inspeção sem deploy](#inspeção-sem-deploy)
- [Nota de implementação](#nota-de-implementação)

Dez passos, em três fases: **preparar** (nada muda), **publicar** (há estado no
servidor a partir daqui) e **confirmar** (ativar não é publicar). A fase do meio é
uma transação com estado entre os passos: registrar a release, sincronizar os
arquivos, construir, ativar, subir.

As pontas de control plane — `cloudez_begin_deploy`, `cloudez_finalize_deploy`,
`cloudez_compose_build` e `cloudez_compose_up` — são **tools do MCP**; o transporte
do meio (`cloudez-sync`) segue local, porque o MCP nunca move bytes. Tanto a tool quanto o adaptador
devolvem JSON estruturado — **leia esse JSON, não presuma sucesso pelo exit code
nem por a chamada ter retornado.** O único adaptador local que resta é o
transporte, `cloudez-sync`, chamado sempre como `node <skill>/scripts/cloudez-sync`,
com `<skill>` sendo a pasta do SKILL.md.

Os passos dizem **o que fazer**. O [deploy-porques.md](deploy-porques.md) diz
**por que** cada trava existe — quase tudo lá é defeito que já aconteceu. Não
precisa ler para executar, mas leia a entrada antes de afrouxar qualquer regra: a
maioria parece excesso de zelo até você conhecer o caso que a criou.

Todos os caminhos são relativos à raiz do projeto sendo publicado, que precisa
ter um `.cloudez.yaml`. Se não tiver, o passo 1 descobre o site pelo domínio e
encaminha para quem cria a config — não invente os dados de servidor.

Quando o arquivo existir, não anuncie isso ("já existe um .cloudez.yaml
configurado") — é mecanismo interno. Diga só que o projeto está pronto e siga
para o deploy.

# Preparar

Nada aqui muda nada — são as três leituras que dizem o que publicar, para onde, e
como o site estava antes. Se alguma falhar, o deploy não começou.

## 0. Autenticação, antes de qualquer coisa

Feita no SKILL.md, antes de chegar aqui. O login é feito por [login.md](login.md).

A nuance do deploy: com **`authenticated: false`**, **pare de verdade** até o
`cloudez_auth_status` responder `authenticated: true`. Não pergunte o
environment, não peça confirmação de produção, não adiante nenhum passo da
seção 1 "para ganhar tempo". Já aconteceu de o comando anunciar que ia parar,
seguir perguntando, arrancar um "sim, produção" do usuário e só então repetir que
faltava autenticar — duas perguntas para nada, e uma confirmação de produção dada
antes de existir deploy possível.

## 1. O alvo: qual environment, qual site

### Sem `.cloudez.yaml`: descobrir o site pelo domínio

**Não pare e não liste o que falta no projeto.** Pergunte só o domínio, em texto
livre, propondo um valor se o projeto der pista dele — como no passo 1 de
[setup.md](setup.md). Com a resposta:

```
cloudez_get_site(domain: "<domain>")
```

- **`match: "exact"` com `stack` que não é `claude` nem `container_docker`** — o
  site já existe na Cloudez com outro tipo. Diga isso em uma frase, nos termos do
  usuário ("o meusite.com.br já existe na Cloudez como WordPress; para publicar
  este projeto nele, ele precisa ser convertido"), e **pergunte** se ele quer
  converter, como no passo 3 de [convert.md](convert.md), com o aviso de que pode
  haver breves períodos de downtime. Pedir o deploy não é aceitar a conversão.
  **Se aceitar**, siga [convert.md](convert.md) com esse domínio: ele cria a
  config, converte e termina no deploy, então não volte a este procedimento.
  **Se recusar**, pare.
- **`match: "exact"` com `claude` ou `container_docker`** — o site já está pronto
  para receber o projeto. Siga [setup.md](setup.md) com esse domínio e, quando ele
  terminar, siga daqui do passo 1, com a config que ele criou.
- **`match: "candidates"` ou `site_not_found`** — o site ainda não existe com esse
  domínio. Siga [setup.md](setup.md) com esse domínio: ele mostra os parecidos e
  cria o site quando o usuário quiser. Depois, siga daqui do passo 1.

O que faltar no projeto (Compose, banco) aparece no passo em que importa, e não
antes — [A17](deploy-porques.md#a17).

### Environment

Os environments são as chaves de `cloudez:` no `.cloudez.yaml`. Se o usuário não
informou um no pedido, escolha nesta ordem: `default`, se existir; senão
`staging`, se existir; senão **pergunte** qual dos environments definidos é o
alvo, com as opções numeradas, e espere a resposta.

`production` nunca entra nessa escolha automática: se o usuário disse "sobe" sem
qualificar, não é produção.

**Produção exige confirmação explícita nesta conversa.** "Sobe pra prod",
"publica em produção", "manda pro ar" contam. Uma conclusão sua de que produção
seria o alvo lógico, não conta. Em dúvida, pergunte antes de rodar qualquer
coisa.

Se o environment pedido não existir no arquivo, **pare** e liste os que existem.

### Confirmar o site na Cloudez

Do bloco do environment, pegue o `domain` e busque o site:

```
cloudez_get_site(domain: "<domain>")
```

**`match: "exact"`** — é o alvo. O bloco `ssh` do retorno (`host`, `user`,
`port`) é informativo: serve para você dizer ao usuário para onde o deploy vai.
**Você não repassa esses valores a ninguém** — o `cloudez_begin_deploy` resolve o
destino sozinho pelo `domain` e o grava no estado do deploy, e é de lá que o
`cloudez-sync`, o `finalize` e o `compose_up` o leem.

Eles não estão no `.cloudez.yaml` de propósito — [A1](deploy-porques.md#a1).

**`stack` que não é `claude` nem `container_docker`** (WordPress, html, ...) —
**pare.** Diga que, para publicar nele, o site precisa ser convertido para o tipo
Claude, e **pergunte** se ele quer converter, como no passo 3 de
[convert.md](convert.md), com o aviso de que pode haver breves períodos de
downtime. Se aceitar, siga [convert.md](convert.md); se recusar, pare. Ver
[A16](deploy-porques.md#a16).

**`framework_missing`** — siga a instrução do campo aqui, antes do passo 2: leia
o projeto e grave só o `framework` com `cloudez_configure_site`, sem perguntar e
sem comentar. Não interrompe o deploy: se a gravação falhar, siga assim mesmo —
[A15](deploy-porques.md#a15).

**`match: "candidates"` ou `site_not_found`** — **pare.** O `domain` veio de um
arquivo versionado: se não casa exatamente com um site da conta, a config está
errada ou aponta para outra conta, e isso se corrige no `.cloudez.yaml`, não
escolhendo um vizinho aqui. Liste os candidatos, quando houver, para o usuário
entender o que existe.

**`ssh_unavailable` dizendo que o usuário não tem SSH liberado (`has_ssh:
false`)** — **pare.** O deploy é impossível até o acesso ser habilitado no painel
da Cloudez, e nenhum valor no `.cloudez.yaml` contorna isso. Sincronizar assim
falharia com permissão negada no meio do caminho.

**`upstream_unavailable`** — leia o `hint`. Se disser que a **rota** não existe,
o problema é o endpoint do servidor MCP: não afirme que o site sumiu da conta.

## 2. O que publicar

### O commit, se houver git

**Nem todo projeto é um repositório git, e o deploy não depende de um.** O que
identifica a release é o hash do conteúdo publicado, coletado no passo 3.

Rode `git rev-parse HEAD` **uma vez**. Se falhar — não é repositório, ou não há
commit — siga sem `ref`; não é erro e não merece comentário ao usuário.

Se houver repositório, rode também `git status --porcelain`. Saída não vazia
significa que o commit **não descreve** o que vai ao ar: há mudanças no disco
que o `ref` não representa. Isso **não interrompe o deploy** — o hash do conteúdo
identifica a release corretamente de qualquer forma. Avise o usuário em uma
linha, dizendo que o `release_id` vai sair marcado pelo conteúdo, e siga.

Isto já foi um bloqueio — [A2](deploy-porques.md#a2).

### O diretório

O diretório publicado é o que o usuário informou no pedido. Sem ele, confirme
onde está o Compose:

```
cloudez_find_compose(directory: "<diretório candidato>")
```

**`compose: false` — pare.** Esta skill publica aplicação em container, e só. Sem
Compose o deploy publicaria arquivos que ninguém executa. Ofereça escrever o
arquivo junto com o usuário, seguindo [compose.md](compose.md).

Publique o **diretório do arquivo de Compose**, que é o contexto de build — em
geral a raiz do projeto. É lá que estão o `Dockerfile` e o `compose`, e sem eles
não há o que subir do outro lado.

**Não rode o build local.** Quem constrói a imagem é o Docker, a partir do
`Dockerfile`; rodar `npm run build` aqui e publicar o `dist/` mandaria um
diretório sem `Dockerfile` e sem `compose`, e o container não teria como existir.

O `sync` exclui o `.git`, então publicar a raiz não carrega o histórico do
repositório. O resto vai inteiro: o que não deve entrar na imagem é assunto do
`.dockerignore`, aplicado no build.

## 3. Medir antes

### Como o site responde agora

```
cloudez_health_check(domain: "<domain>", attempts: 1)
```

**Guarde o `body_sha256`.** É a referência: comparado com o de depois, ele é o
único sinal independente de stack sobre a publicação ter mudado alguma coisa.

Sem ela, o passo 9 só consegue dizer que o site responde — e a release anterior
também responde. [A3](deploy-porques.md#a3).

Uma falha aqui **não interrompe o deploy**: site fora do ar antes de publicar é
justamente o que se está tentando consertar. Só registre e siga.

**Guarde só o `body_sha256`.** O `attempts: 1` é deliberado, e por isso
`latency_ms` e `attempts` **não são comparáveis** com os do passo 9 —
[A4](deploy-porques.md#a4).

### O hash do que vai subir

```
node <skill>/scripts/cloudez-sync --hash-only <diretório decidido no passo 2>
```

Devolve `content_sha256`, `files` e `bytes`. **Guarde o `content_sha256`** — é o
que identifica a release, com ou sem git.

Roda sobre o diretório do passo 2, depois do build e antes de qualquer coisa
tocar a rede. Não envia nada; só lê. Cobre **exatamente** o conjunto que o
`cloudez-sync` transmite: o transporte recebe esta mesma lista, então não há duas
regras para divergirem.

### O que fica de fora

Sempre o `.git`. Além dele, os padrões de **`.gitignore`** e **`.cloudezignore`**
da raiz do diretório publicado, nesta ordem — o último padrão que casa decide,
como no git, então o `.cloudezignore` consegue desfazer com `!` o que o
`.gitignore` excluiu.

O `.dockerignore` **não** é lido, e isso é decisão e não esquecimento: ali é
correto excluir o `Dockerfile` e o `docker-compose.yml`, porque o Docker os recebe
por outro caminho — mas o deploy publica o diretório para construir depois, no
servidor. Respeitá-lo faria todo site em container falhar com `compose_missing`.

Havendo algum dos dois arquivos, o retorno traz `ignored` com as `sources` lidas,
quantos caminhos foram podados (`pruned`) e quais (`paths`). **Mencione ao
usuário** o que foi podado quando não for óbvio: um `dist/` no `.gitignore` que o
servidor precisava é o tipo de coisa que só aparece como 404 depois.

### Quando os números não fecham

**Erro `build_output_empty`** — o diretório não tem nada publicável. A mensagem
diz qual das duas causas é: só `.git`, ou padrão amplo demais. No primeiro caso,
quase sempre o passo 2 apontou para a raiz de um repositório sem build em vez do
diretório de saída; volte ao passo 2. No segundo, o padrão é do usuário e ele
precisa saber qual arquivo o causou.

Se `files` ou `bytes` ainda vierem absurdos para o projeto (dezenas de milhares
de arquivos para o que o projeto é), **pare e confirme com o usuário** antes de
publicar. Com os dois arquivos de padrão em uso isso ficou raro — mas um projeto
sem `.gitignore` continua mandando `node_modules` inteiro.

# Publicar

A partir daqui há estado no servidor. Cada passo devolve JSON — **leia o JSON**,
não presuma sucesso por a chamada ter retornado.

## 4. Registrar a release

```
cloudez_begin_deploy(
  domain: "<domain>",
  // `root` só quando o .cloudez.yaml do projeto o tiver — ver a nota abaixo.
  content_sha256: "<content_sha256 do passo 3>",
  ref: "<sha do passo 2, se houver>",
  environment: "<environment>"
)
```

**`content_sha256` vai sempre.** O `ref` vai só quando o passo 2 conseguiu o
commit — omita o campo fora de um repositório, não mande string vazia.

O `release_id` que volta é `<timestamp>-<sufixo>`, e a letra do sufixo diz de
onde ele veio: `g1a2b3c` é commit, `c9f8e7d` é conteúdo. Use o `release_id` do
retorno ao falar com o usuário; não o monte por conta própria.

**Erro `release_unidentifiable`** — a chamada foi sem os dois. Volte ao passo 3;
não invente um `ref`.

A tool resolve o destino ssh sozinha, pelo `domain` (o mesmo `cloudez_get_site`
do passo 1) — **não passe host, user nem port**. O `root`, quando existir, vem do `.cloudez.yaml`
(o bloco do environment): é a única fonte dele, e a tool não o busca na API de
propósito.

Este passo **já conecta por ssh** — ele prepara o diretório de release no
servidor. Uma falha de permissão aqui volta como `ssh_failed` (retryable), o
mesmo caso descrito no passo 5, com a mesma exceção para a chave recém-autorizada.

**Não passe `idempotency_key`.** O servidor gera uma. O campo existe para um
retry não virar um segundo deploy, e ele aceita a sua se você tiver a mesma chave
de uma chamada anterior — mas **não invente uma**: você não tem como gerar valor
aleatório de forma confiável, e uma chave repetida por engano devolve um deploy
antigo em vez de criar o novo.

[A5](deploy-porques.md#a5) conta por que isto já foi obrigatório e deixou de ser.

Guarde o `deploy_id` do retorno. O destino ssh já foi gravado no estado do
deploy, e é de lá que o `cloudez-sync` o lê no passo 5.

> **Não passe `root`.** O diretório do site no servidor é sempre
> `~/<domain>/www/claude`, e as tools o derivam do domínio — ele saiu do
> `.cloudez.yaml` porque a Cloudez RENOMEIA o diretório quando o domínio do site
> muda, e um valor escrito passaria a apontar para o que deixou de existir.
>
> A exceção é config antiga: havendo `root:` no bloco do environment, **passe-o** —
> ele vence o derivado, e ignorá-lo publicaria noutro lugar sem avisar. Não
> reescreva o arquivo do usuário para tirá-lo.

## 5. Sincronizar

```sh
node <skill>/scripts/cloudez-sync <deploy_id> <diretorio>
```

**Este é o único que não leva as variáveis**, e não é esquecimento —
[A6](deploy-porques.md#a6).

Falha aqui é quase sempre SSH: chave não configurada, host desconhecido,
permissão. O campo `logs` do erro traz a saída do `tar` e do `ssh`. Chave ausente
é coisa que só o usuário resolve — reporte e pare, não tente contornar.

**Uma exceção, antes de reportar chave ausente.** Se a chave desta máquina
acabou de ser autorizada — por [setup.md](setup.md) ou pelo painel —, um `Permission
denied (publickey)` é esperado: a conta registra a autorização na hora, mas
propagá-la até o servidor do site leva um tempo, em geral menos de um minuto e
eventualmente mais. Diga isso ao usuário e **tente novamente em alguns minutos**,
reusando a mesma `idempotency_key`. Só trate como chave ausente se continuar
falhando depois disso — mandá-lo conferir o cadastro que ele acabou de fazer o
faz procurar defeito onde não há.

## 6. Construir a imagem



```
cloudez_compose_build(deploy_id: "<deploy_id>")
```

Roda `docker compose build` no **diretório da release**, com o symlink ainda
apontando para a versão anterior.

**Antes do `finalize`, e é o ponto todo:** aqui, build quebrado é deploy que não
começou. [A7](deploy-porques.md#a7).

**`compose_build_failed`** é falha do **projeto**: Dockerfile, dependência,
contexto. Leia o `hint`, que traz a saída do build. Corrija e recomece o deploy;
nada foi ativado. É diferente do `compose_failed` do passo 8, que é quase sempre
do servidor.

`compose_missing` e `docker_missing` significam aqui o mesmo que no passo 8.

Pular este passo **não quebra o deploy**: o passo 8 reconstrói sozinho. Só perde
a garantia acima.

## 7. Ativar

```
cloudez_finalize_deploy(deploy_id: "<deploy_id>")
```

Troca o symlink `current` de forma atômica. Se der `activation_failed`, a release
**não** foi ativada e o site continua no ar na versão anterior — reporte e pare.

Se vier `replaced_directory` no retorno, o `current` era um **diretório de
verdade** e não um symlink: o site já tinha conteúdo antes de a skill entrar.
Ele foi **movido**, nunca apagado, para o caminho que o campo informa. **Diga
isso ao usuário** — é conteúdo dele posto de lado, e só ele decide se ainda
serve para alguma coisa. Sem esse aviso vira um diretório órfão no servidor que
só aparece quando alguém for olhar.

Se vier `pruned_replaced`, esse número de diretórios substituídos **antigos** foi
apagado para o servidor não acumular cópias inteiras do document root. Reporte
também: é conteúdo do usuário, e apagar em silêncio seria pior do que acumular.
Os dois mais recentes sempre ficam.

`previous_release_id` **não aparece** quando não havia release anterior — é o
caso do primeiro deploy do site. Campo ausente, não string vazia.

Este passo também grava o **manifesto da release** no servidor, em
`<root>/.cloudez/deploys/<release_id>.json`: release, commit, hash do conteúdo e
a hora do servidor. É o que responde "o que está no ar e de qual commit veio" a
quem não tem o estado local — inclusive a outra pessoa da equipe.

O campo **`manifest`** do retorno traz o caminho gravado. Ele só aparece quando a
escrita deu certo, então a **ausência dele é informação**: o deploy segue válido
(a escrita é best-effort e não invalida uma release já ativada), mas aquele
servidor ficou sem registro do que está rodando. **Mencione ao usuário quando
faltar** — em silêncio, um manifesto que nunca foi gravado é indistinguível de um
gravado, e ninguém descobre até precisar dele.

## 8. Subir o container

Publicar os arquivos não põe uma aplicação em container no ar —
[A9](deploy-porques.md#a9).

```
cloudez_compose_up(deploy_id: "<deploy_id>")
```

Roda `docker compose up -d` na release recém-ativada. **Depois do `finalize`,
nunca antes** — é este passo que troca o container em serviço, e invertida a
ordem ele subiria a release anterior.

Se o passo 6 rodou, a imagem já existe e o `up` só recria o container: segundos,
em vez do build inteiro. Se não rodou, ele reconstrói com `--build` — o caminho
antigo, correto e mais lento.

O retorno traz `compose.project` e `compose.containers`, com `name`, `state` e
`ports` de cada um. **Confira o `state`**: um container em `restarting` ou
`exited` é deploy fracassado com JSON de sucesso.

**Confira também o `compose.recreated`.** Ele diz se algum container foi de fato
trocado. `false` significa que o Compose não recriou nada — o conteúdo saiu
idêntico ao do deploy anterior, então a imagem saiu idêntica. Costuma ser
legítimo (republicar o mesmo conteúdo), mas é a diferença entre "a release nova está
servindo" e "a release nova está no disco". O `state` responde `running` nos dois
casos. Quando vier `false` e o deploy deveria ter mudado alguma coisa, cruze com
o `body_sha256` do passo 9.

Ao relatar isto ao usuário, não cite `recreated`, `state` nem nenhum outro nome
de campo — diga em termos simples: "o container foi recriado e está rodando",
ou, quando `recreated: false`, "o container não precisou ser recriado, porque o
conteúdo não mudou".

**Se vier `compose.shared_merged`**, diga ao usuário que aquele diretório já
estava parcialmente no armazenamento que sobrevive aos deploys e foi completado
com o que a versão anterior do site tinha, sem apagar nem sobrescrever nada, e
diga onde ficou a cópia da versão anterior (`compose.shared_merge_backup`). Com
`compose.shared_merge_conflicts`, liste esses arquivos: ficou a versão que já
estava no armazenamento, e a outra está na cópia. Peça para o usuário conferir se
algum deles precisa da versão antiga.

O `project` vem do domínio, não do diretório, e sobrepõe um `name:` do usuário —
[A8](deploy-porques.md#a8).

Erros que **não se resolvem no projeto** e cujo `hint` você deve repassar como
está — os dois são ação da Cloudez, não do usuário:

- **`compose_failed` com permissão negada no `docker.sock`** — o usuário do site
  não está no grupo `docker`;
- **`compose_failed` com `iptables: No chain/target/match`** — as chains do
  Docker sumiram do host e nenhuma porta publicada funciona. Não tente contornar
  com `network_mode: host`: resolve o sintoma e amarra o projeto a um defeito
  daquele servidor.

**`compose_missing`** é outra coisa: o deploy publicou um diretório sem Compose.
Quase sempre significa que o passo 2 publicou a saída de um build em vez do
contexto de build. O container continua rodando a versão anterior.

**Verifique o site depois.** Este é o único passo cujo sucesso não se comprova
pelo próprio retorno: o container pode subir e a aplicação não responder. Bata no
domínio e confira o que voltou antes de declarar o deploy pronto.

# Confirmar

Ativar não é publicar. O que decide é o site responder — e o usuário saber onde
ver o resultado.

## 9. Verificar que o site responde

Ativar a release, ou subir o container, **não prova que a aplicação está no ar**.
Este é o passo que fecha essa lacuna.

```
cloudez_health_check(domain: "<domain>")
```

Ele tenta mais de uma vez por padrão. Um container recém-recriado leva segundos
para escutar, e uma checagem única logo depois do deploy pega o intervalo em que
ele ainda está subindo.

**`healthy: false`** — o deploy **fracassou**, mesmo com todos os passos
anteriores em `succeeded`. Reporte assim, sem suavizar. O que o `status_code`
sugere:

| Sintoma | Provável causa |
|---|---|
| `502` em site container | O container não está escutando. Confira o `state` do passo 8 e os logs do build |
| `404` | O document root aponta para o lugar errado, ou o symlink `current` está quebrado |
| sem `status_code`, com `error` | DNS, TLS ou o servidor fora — pode não ter relação com o deploy |

Ofereça o rollback (passo 10, e em site container o passo 8 de novo depois dele).

**`healthy: true`, mas `body_sha256` igual ao do passo 3** — o site responde e
está servindo **exatamente o mesmo conteúdo de antes do deploy**. Não afirme que
a publicação deu certo.

Diga ao usuário, sem citar `body_sha256` nem qualquer outro nome de campo: "o
site está respondendo, mas a página está servindo exatamente o mesmo conteúdo
de antes do deploy." Pergunte se a release deveria ter mudado o que a home
mostra: pode ser legítimo — nem toda release muda a home — ou pode ser um
deploy que não surtiu efeito.

**`attempts` maior que 1** — vale mencionar. A aplicação demorou a subir, e isso
é informação sobre ela que só este passo revela.

**Não compare `latency_ms` nem `attempts` com os do passo 3** — o único campo
comparável entre os dois passos é o `body_sha256`. [A4](deploy-porques.md#a4).

### Supabase: o Studio precisa recusar quem chega sem senha

Se o Compose tem o Studio do Supabase (imagem `supabase/studio`), este passo só
termina depois de provar que ele está protegido. Sem credencial nenhuma, os dois
caminhos precisam responder **401**:

```
cloudez_health_check(domain: "studio.<domain>", expect_status: 401)
cloudez_health_check(domain: "studio.<domain>", path: "/api/platform/profile", expect_status: 401)
```

**Os dois com `healthy: true`** — o Studio pede a senha. Diga isso em uma frase.

**Qualquer um com outro `status_code`** — o Studio está **exposto**, e o deploy
**fracassou**, mesmo com o site respondendo. Não espere o usuário decidir:

- **com release anterior**, faça o rollback agora (passo 10, com o passo 8 de
  novo depois dele). A anterior passou por esta mesma checagem;
- **sem release anterior**, diga que o Studio está aberto, corrija a rota do
  Studio no gateway (ver [compose-supabase.md](compose-supabase.md)) e
  publique de novo, já.

Depois, rode estas duas checagens de novo. Nunca encerre o deploy dizendo que deu
certo com o Studio aberto.

**Sem `status_code`, com `error`** — o subdomínio ainda não chega ao servidor,
quase sempre DNS. Isso **não** prova que o Studio está protegido. Diga que a
proteção não pôde ser verificada e que o DNS de `studio.<domain>` precisa apontar
para a Cloudez, e rode estas checagens de novo quando apontar.

### Onde ver a versão nova

São dois endereços, e eles falham por motivos diferentes
([A10](deploy-porques.md#a10)):

```
cloudez_check_dns(domain: "<domain>")
```

O `temporary_address` veio do `cloudez_get_site` do passo 1. **Não guarde esse
valor** — releia sempre. [A11](deploy-porques.md#a11).

**Abra o site no navegador**, em vez de deixar o endereço como texto para o
usuário copiar: informe a URL `https://<endereço>` e abra-a com a ferramenta de
navegador do agente, se houver uma; senão, mostre a URL ao usuário.

O endereço é **o oficial quando ele veio ✅**, e o temporário quando não. É a
diferença entre mostrar o site onde ele de fato vai viver e mostrar um endereço de
passagem — e quando o oficial ainda não responde, abrir o temporário é a única
forma de o usuário ver a versão nova agora.

Um link em texto obriga o usuário a sair da conversa para conferir o próprio
deploy. Abrir pelo navegador do agente é o mesmo jeito que [dev.md](dev.md) usa
para mostrar a versão local, e ver as duas do mesmo jeito é o que torna a
comparação possível.

Feche o relato com este bloco, exatamente nesta forma:

```
Nova versão da aplicação disponível em:
  https://<temporary_address>   ✅
  https://<domain>              ✅  ou  ⚠️
```

O bloco continua, mesmo com o navegador aberto: ele carrega o que a página não
mostra — QUAIS dos dois endereços responderam, e que o ⚠️ é do DNS e não da
aplicação. O navegador entrega o link; o bloco entrega o diagnóstico.

**Quando o oficial vier ⚠️**, acrescente duas linhas logo abaixo — a primeira
sempre igual, a segunda vinda do `summary` do retorno, **sem reescrever**:

```
⚠️  Use o endereço temporário por enquanto.
    <summary>
```

A primeira linha é a única acionável, e é fixa de propósito: o usuário não precisa
ler o resto para saber o que fazer agora. E ela fala só de **ação**, nunca de
causa — [A13](deploy-porques.md#a13).

O `summary` já vem em uma linha, pronto para exibir. O `note` é outra coisa: é a
explicação inteira, para quando alguém for diagnosticar. **Não cole o `note` no
bloco** e não resuma o `summary` por conta própria — a saída ser igual toda vez é
o motivo de ele existir.

**O endereço temporário é sempre ✅** quando o passo 9 deu `healthy: true`: ele
aponta para o servidor por construção, sem depender de DNS de ninguém. E ele
aparece **sempre**, inclusive quando o oficial está ✅ — é o endereço que continua
funcionando se o DNS mudar depois.

**O oficial depende do `points_to_server`:**

| Retorno | Marca | O que dizer |
|---|---|---|
| `true`, `method: "dns"` | ✅ | Nada. Os dois funcionam |
| `true`, `method: "header"` | ✅ | Nada. O domínio está atrás de um CDN e chega à Cloudez assim mesmo. **Não mencione DNS** — está tudo certo |
| `false` | ⚠️ | **Leia o `note`**, que diz qual dos três casos é: registro ainda não propagado, apontado para o lugar errado, ou checagem que não conseguiu verificar. Repasse o que ele diz, e use o endereço temporário enquanto isso |

A tabela tinha uma quarta linha, que existia porque "resolve para outro lugar" era
indistinguível entre CDN e erro de configuração. O header `cez-verify` desempata
isso, e a linha deixou de ser necessária — [A12](deploy-porques.md#a12).

Se o site não tem `temporary_address`, mostre só o oficial — não invente um
endereço nem prometa que existe.

**Não fale em ativar o HTTPS, em nenhum dos casos.** Um domínio que acabou de
apontar pode responder sem certificado por alguns minutos; quem cuida disso é a
Cloudez, sozinha, e não há passo para o usuário executar —
[A14](deploy-porques.md#a14).

## 10. Rollback

Fora de um deploy, isto é o [rollback.md](rollback.md), que confirma o alvo com o
usuário e verifica o resultado. Aqui está inline porque um rollback disparado no
meio de um deploy que falhou acontece dentro deste fluxo, e não deve sair dele.
**Os dois textos precisam mudar juntos.**

O `root`, se o `.cloudez.yaml` o tiver, vem do bloco do environment, como no
passo 4. Não tendo, omita: a tool o deriva do domínio.

```
cloudez_rollback(domain: "<domain>", root: "<root>")                          # volta para a anterior
cloudez_rollback(domain: "<domain>", root: "<root>", to_release_id: "<id>")   # volta para uma específica
```

O servidor mantém as 5 releases mais recentes; o rollback alcança até ali. Alvo
que não existe mais volta `release_not_found` com a lista do que sobrou — não
escolha outro por conta. Se o rollback também falhar (`rollback_failed`), isso é
um incidente — reporte imediatamente com todos os logs, sem tentar mais nada.

**Em aplicação em container, o rollback não termina aqui.** Ele troca o symlink,
e só: o container segue rodando a imagem construída no deploy anterior, então o
site continua servindo o que você acabou de tentar tirar do ar. É preciso
reconstruir a imagem a partir da release de destino — `cloudez_compose_build`
seguido de `cloudez_compose_up`, ambos com o `deploy_id` dela. O
`cloudez_compose_build` aceita release já ativa justamente para isto.

Se não houver um deploy ativo para essa release, um `cloudez_begin_deploy` novo
com os mesmos identificadores (o `content_sha256` do passo 3, e o `ref` se
houver), seguido de sync + compose_build + finalize + compose_up, é o caminho
que reconstrói e religa tudo.

**Rode o passo 9 de novo depois do rollback.** Voltar o symlink é o remédio, não
a confirmação — e um rollback que não devolve o site ao ar é o pior estado
possível para se declarar resolvido.

## Como reportar

Comece pelo resultado: subiu ou não subiu, em qual ambiente, qual `release_id`.
Depois o detalhe.

Diga o `release_id` inteiro, não só o sufixo: é o que o usuário vai digitar num
rollback. Quando houver commit, mencione-o junto — a pessoa reconhece o commit,
não o hash de conteúdo.

Não descreva os passos que correram bem — o usuário não precisa saber que o envio
funcionou. Descreva o que ele precisa fazer alguma coisa a respeito: falhas e
rollbacks executados.

O bloco de endereços do passo 9 fecha o relato, e não se resume nem se substitui:
é por ele que o usuário sabe onde olhar.

Se houve rollback, diga explicitamente **qual versão está no ar agora**.

## Inspeção sem deploy

Quando o usuário só quer saber o estado:

```
cloudez_list_releases(domain: "<domain>", root: "<root>")   # o que está no servidor, qual é a atual
```

Também aqui o destino vem do `cloudez_get_site` — passos 1 a 2 antes.

---

## Nota de implementação

Havendo `root` no `.cloudez.yaml`, ele vem **sempre** de lá, nunca da API: duas fontes para o
destino dos arquivos criariam a pergunta "qual vale?" para a decisão mais
destrutiva daqui, e ela só apareceria quando as duas divergissem.

Todo o control plane já é tool do servidor MCP: `cloudez_begin_deploy`,
`cloudez_finalize_deploy`, `cloudez_compose_build`, `cloudez_compose_up`,
`cloudez_list_releases` e
`cloudez_rollback`. O passo 5 é a exceção permanente: o transporte (`cloudez-sync`)
continua local, já que o MCP nunca transporta arquivos.
