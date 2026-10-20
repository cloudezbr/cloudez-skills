# Rodar o site localmente

Quando usar: Sobe o site localmente, pelo dev server do projeto ou em container, e abre no navegador.

Entradas: `[diretório]`, o diretório do projeto. Sem ele, o atual.

Subir a aplicação na máquina do usuário e abrir no navegador, para ele ver o que
mudou antes de publicar.

**Não é um deploy, e não fala com a Cloudez.** Nada daqui toca a conta, o
servidor ou o estado de deploy. Se o usuário quiser publicar, siga
[deploy.md](deploy.md).

## O que sobe é a configuração de DESENVOLVIMENTO

Nunca a de produção. Num Compose, um `docker compose up` sem argumento lê só o
arquivo base — a sobreposição (`docker-compose.cloudez.yml`) não entra, porque
ninguém passa `-f` aqui.

Isso importa em duas direções, e as duas merecem ser ditas ao usuário:

- o que ele vê aqui **não** é o que vai ao ar. Bind mount do fonte, porta em
  `0.0.0.0`, `command` de dev — tudo o que a sobreposição remove continua valendo
  localmente;
- e por isso mesmo o que funciona aqui pode falhar lá. Rodar aqui não substitui
  o passo de verificação de [deploy.md](deploy.md).

**No caminho do dev server (abaixo) o aviso é mais forte ainda**, porque ali nem o
Dockerfile é executado: o que roda é o Node da máquina do usuário, com as
dependências dela. Passar aqui diz menos sobre produção do que passar no
container.

## 1. Decidir o que subir

Duas leituras, e elas decidem o caminho:

```
cloudez_find_compose(directory: "<diretório>")
```

Sem essa tool no agente, procure o Compose você mesmo no diretório, pelos nomes
que o `docker compose` lê sem `-f` (`compose.yaml`, `compose.yml`,
`docker-compose.yaml`, `docker-compose.yml`), e leia os `ports` dele. Rodar
localmente não depende do MCP.

**`compose: false` — pare.** Esta skill publica aplicação em container: sem
Compose não há o que este procedimento prepare para o deploy. Ofereça escrever
um, seguindo [compose.md](compose.md).

Depois, **leia o `package.json`** do diretório.

| O que você encontra | O caminho |
|---|---|
| `scripts.dev` no `package.json` | **dev server** — `npm run dev`. É a exceção, e a seção seguinte explica |
| sem `scripts.dev` | **container** — `docker compose up --build` |

### A exceção: projeto Node roda pelo dev server

Num projeto Node — Next, Vite, Remix —, subir o container para desenvolver é o
pior dos dois mundos: `--build` refaz a imagem a cada alteração, e o que se quer
localmente é recarregar em um segundo. O `npm run dev` dá hot reload; o container
dá um `npm ci` completo por mudança de uma linha.

**Isto vale só aqui.** O deploy não muda em nada: no servidor continua sendo o
Dockerfile e o Compose, com a sobreposição por cima. A exceção é do ambiente de
desenvolvimento, não do projeto.

Três coisas a conferir antes de subir:

**As dependências estão instaladas?** Sem `node_modules`, o dev server morre na
primeira linha. Se faltar, diga ao usuário para rodar `npm ci` antes — não instale
por conta própria, é a máquina dele e o comando pode levar minutos.

**A aplicação depende de outros serviços?** Se o Compose tiver mais de um serviço
— banco, redis, fila —, o `npm run dev` sobe só a aplicação e os outros ficam de
fora. O arranjo certo é híbrido: os serviços de apoio pelo Compose
(`docker compose up -d <serviço>`) e a aplicação pelo npm. Diga isso ao usuário e
proponha os dois.

**Em que porta o dev server escuta?** Ela **não** é o `published` do Compose —
aquela é a porta do container, e aqui não há container. Leia o script: `next dev`
sem argumento é 3000, `vite` é 5173. Se o script não fixar a porta, prefira fixá-la
no comando (`npm run dev -- -p 3000` no Next, `npm run dev -- --port 5173` no
Vite), para o endereço que você verifica e abre não poder divergir do que a
aplicação abre. E **declare a suposição** quando tiver feito uma.

### A porta, no caminho do container

O retorno do `find_compose` traz `ports`, e o que interessa é o **`published`** —
a porta do host, não a do container:

| O que você vê | O que fazer |
|---|---|
| um `published` | É o endereço: `http://localhost:<published>` |
| vários serviços com `published` | **Pergunte** qual é a aplicação. Um deles pode ser banco ou painel auxiliar |
| nenhum `published` | **Pare.** O Compose só declara a porta do container, e o Docker publica numa porta alta aleatória que muda a cada `up`. Não há endereço estável para abrir. Isto se corrige no arquivo — ofereça seguir [compose.md](compose.md) |

Ignore o `cloudez_file` aqui: ele descreve produção, e não é lido neste caminho.
Se vier `parse_error`, diga que o arquivo não pôde ser lido e **não afirme nada
sobre a porta**.

## 2. Subir

Antes, veja se já há algo de pé: `curl -sI http://localhost:<porta>` respondendo,
ou `docker compose ps` com o serviço rodando. Se a porta já responde, pode ser
este projeto de pé desde antes ou outra coisa ocupando a porta: diga ao usuário
em vez de presumir. No container, rodar o `up --build -d` de novo é seguro: ele
refaz a imagem e recria só o que mudou. No dev server, não suba um segundo
processo por cima do primeiro: os dois disputariam a porta.

Rode tudo no diretório do projeto, pelo shell.

**Dev server.** O processo não termina sozinho, então vai em segundo plano: pela
execução em background do agente, se houver, que guarda a saída para o passo 5;
senão, com `nohup` e a saída redirecionada para um arquivo fora do projeto.

```bash
cd <diretório> && nohup npm run dev -- -p 3000 > "${TMPDIR:-/tmp}/cloudez-dev.log" 2>&1 & echo $!
```

Guarde o PID que ele imprime: é por ele que se para o processo no passo 6.

Confira na saída a URL que ele anunciou (`Local: http://localhost:...`): com a
porta ocupada, alguns dev servers pulam para a seguinte sem parar, e o endereço
certo passa a ser esse.

**Container.**

```bash
cd <diretório> && docker compose up --build -d
```

O `-d` devolve o terminal depois que os containers sobem, e eles seguem de pé
sozinhos: nenhum processo do agente precisa ficar vivo, e os passos seguintes
funcionam em qualquer shell. O build roda antes de o comando voltar, então a
saída dele traz o erro de build, se houver.

O dev server responde em segundos. **O container não**: o primeiro `up` leva o
tempo do build da imagem, que num projeto Node é minuto — **avise antes**, senão o
silêncio parece travamento, e dê ao comando um tempo limite à altura.

### O que não varia

A porta é a do passo 1, **sempre**, e nunca um número presumido: o `published` do
Compose no caminho do container, o do dev server no outro. Errar aqui dá página em
branco — o navegador abre num endereço onde não há nada.

O `--build` é deliberado: sem ele o `up` reaproveita a imagem da última vez, e o
usuário olharia para o código anterior achando que está vendo o novo. É o mesmo
erro que o `--build` do `cloudez_compose_up` evita no servidor.

**Nunca ponha `-p`.** Sem ele, o Compose nomeia o projeto pelo diretório, que é o
que se quer numa máquina de desenvolvimento. Um `-p` fixo faria dois projetos
diferentes virarem o MESMO projeto Compose na máquina do usuário, e subir um
derrubaria o container do outro — o mesmo bug que o deploy evita no servidor
derivando o nome do domínio.

## 3. Verificar que respondeu

```bash
curl -sI --retry 10 --retry-connrefused --retry-delay 2 http://localhost:<porta>
```

Só leitura: nunca POST, nem `-d`, para testar. Qualquer linha `HTTP/` na resposta
quer dizer que há alguém escutando; um 5xx é a aplicação de pé e com erro, e vai
para o passo 5 do mesmo jeito. Sem resposta depois das tentativas, passo 5.

## 4. Abrir

Se o agente tiver uma ferramenta de navegador, abra `http://localhost:<porta>`
com ela. Senão, mostre a URL ao usuário, para ele abrir no navegador dele. Nos
dois casos o valor deste procedimento é o mesmo: achar a porta certa e subir a
coisa certa.

## 5. Quando não responde

Leia a saída do processo: a do background do agente, ou o arquivo de log do
dev server. No container, o build aparece na saída do próprio `up --build -d`, e o
que veio depois em:

```bash
docker compose logs --tail 100
```

Os casos comuns:

| Sintoma | Quase sempre é |
|---|---|
| falha no build | O mesmo que falharia no deploy: Dockerfile, dependência, contexto. Corrija e suba de novo |
| `port is already allocated` | Outra coisa já ocupa a porta do host — inclusive um `up` anterior deste mesmo projeto. `docker compose ps` mostra o que está de pé neste projeto, `docker ps` na máquina inteira |
| sobe, mas a página não carrega | A aplicação escuta em `127.0.0.1` DENTRO do container, e o mapeamento não alcança. Precisa ser `0.0.0.0` — a mesma restrição do passo 3 de [compose.md](compose.md) |
| `Cannot find module` ou `command not found: next` | Caminho do dev server sem `npm ci`. As dependências não estão instaladas |
| a página abre mas falha ao buscar dados | Caminho do dev server num projeto com serviços de apoio: o banco não subiu junto. Suba-o pelo Compose |

## 6. Parar

- **Dev server:** encerre o processo, pela própria execução em background do
  agente ou com `kill <PID>`.
- **Container:** `docker compose down` no diretório do projeto. Sem `-v`: com
  ele, os volumes vão junto, inclusive o do banco local.

No arranjo híbrido, os dois.
