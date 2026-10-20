# Por que cada trava do deploy existe

É o porquê dos passos de [deploy.md](deploy.md), e só precisa ser lido por quem questiona uma trava.

- [A1](#a1): Por que o destino ssh não mora no .cloudez.yaml
- [A2](#a2): Por que árvore suja não bloqueia mais o deploy
- [A3](#a3): Por que medir o site ANTES de publicar
- [A4](#a4): Por que as duas medições de saúde não são comparáveis
- [A5](#a5): Por que não se inventa uma idempotency_key
- [A6](#a6): Por que o sync não recebe host, user nem port
- [A7](#a7): Por que o build vem ANTES do finalize
- [A8](#a8): Por que o nome do projeto Compose vem do domínio
- [A9](#a9): Por que o passo 8 existe
- [A10](#a10): Por que o bloco de endereços fecha o deploy
- [A11](#a11): Por que o temporary_address não é guardado
- [A12](#a12): Por que a verificação do domínio tem DUAS checagens
- [A13](#a13): Por que a linha de alerta fala de ação, e não de causa
- [A14](#a14): Por que não se fala em "ativar o HTTPS"
- [A15](#a15): Por que o deploy grava o framework
- [A16](#a16): Por que o deploy confere o tipo do site
- [A17](#a17): Por que, sem config, o deploy pergunta o domínio em vez de parar

Os passos de [deploy.md](deploy.md) dizem **o que fazer**. Isto diz **por que**, e
quase tudo aqui é defeito que já aconteceu — não precaução teórica.

Ler não é obrigatório para executar o deploy. Mas antes de remover, afrouxar ou
"simplificar" qualquer regra dos passos, leia a entrada dela: a maioria parece
excesso de zelo até você conhecer o caso que a criou.

<a id="a1"></a>

### A1 — Por que o destino ssh não mora no .cloudez.yaml

Uma cópia do host num arquivo versionado envelhece: se a Cloudez mover o site de
servidor, o valor escrito continua apontando para o antigo, e o deploy vai para o
lugar errado sem reclamar. Buscá-los a cada deploy é o que evita isso.

É a mesma razão pela qual o `temporary_address` também não é guardado ([A11](#a11)).

<a id="a2"></a>

### A2 — Por que árvore suja não bloqueia mais o deploy

Era a razão certa na época: o `ref` era a única referência da release, e um commit
que não correspondia ao disco deixava o rollback sem destino confiável.

Com o hash do conteúdo essa preocupação deixou de existir, e parar o deploy passou
a custar mais do que resolvia — a árvore suja costuma ser exatamente a correção às
pressas que se está tentando publicar.

<a id="a3"></a>

### A3 — Por que medir o site ANTES de publicar

Foi assim que um `app_root_path` errado passou por deploy bem-sucedido enquanto o
site servia o conteúdo velho: todos os passos em `succeeded`, o site no ar, e nada
publicado.

O `body_sha256` é o único sinal independente de stack sobre a publicação ter
mudado alguma coisa.

<a id="a4"></a>

### A4 — Por que as duas medições de saúde não são comparáveis

O `attempts: 1` aqui é assimétrico em relação ao passo 9, que usa o padrão. Lá as
tentativas existem porque um container recém-recriado leva segundos para escutar;
aqui não há nada subindo, e insistir só atrasaria o deploy quando o site já está
fora do ar.

A consequência é que a diferença de latência entre as duas medições não diz nada
sobre a aplicação. Na prática a primeira requisição a um domínio vem bem mais lenta
que as seguintes — cache frio de borda e handshake de TLS, não o seu deploy. **Não
apresente essa queda ao usuário como melhora.**

<a id="a5"></a>

### A5 — Por que não se inventa uma idempotency_key

O campo já foi obrigatório, com o valor vindo de `uuidgen`. O binário não existe no
subconjunto que o Git Bash do Windows embarca, então o deploy simplesmente não
passava deste passo naquela plataforma.

Hoje o servidor gera a chave. Ele aceita a sua se você tiver a mesma de uma chamada
anterior — mas uma chave repetida por engano devolve um deploy antigo em vez de
criar o novo, e você não tem como gerar valor aleatório de forma confiável.

<a id="a6"></a>

### A6 — Por que o sync não recebe host, user nem port

O `begin_deploy` resolveu o destino uma vez e o gravou no estado do deploy, e é de
lá que o `sync` o lê.

Passá-las de novo aqui não teria efeito — e se uma delas viesse diferente, o envio
iria para um servidor e a ativação para outro.

<a id="a7"></a>

### A7 — Por que o build vem ANTES do finalize

Enquanto o build roda — e num projeto de verdade ele leva minutos — o site inteiro
segue no ar coerente: symlink antigo, container antigo.

Construindo depois de ativar, como era antes, o servidor passa o build inteiro num
estado misto: arquivos novos no disco, container servindo os antigos. E se o build
quebra, esse estado FICA — o deploy retorna erro com a release já ativada, e o site
continua na versão velha sem nada que o desfaça.

O build lê `releases/<release_id>` explicitamente, nunca `current`. Era justamente a
dependência do symlink que obrigava a ordem antiga.

<a id="a8"></a>

### A8 — Por que o nome do projeto Compose vem do domínio

O daemon do Docker é um só para todos os sites da máquina, e o nome derivado do
diretório seria `current` para todos eles.

Dois sites publicados por esta skill no mesmo servidor viravam o mesmo projeto
Compose, e o deploy de um derrubava o container do outro.

<a id="a9"></a>

### A9 — Por que o passo 8 existe

O nginx da Cloudez encaminha `/` para uma porta local, e quem escuta ali é o
container do usuário.

Sem este passo o deploy termina em `succeeded` com o site respondendo **502** no
primeiro deploy, ou servindo a **release anterior** nos seguintes — falha que não
aparece em nenhum JSON de retorno, só no navegador.

<a id="a10"></a>

### A10 — Por que o bloco de endereços fecha o deploy

Um deploy que termina sem dizer onde olhar obriga o usuário a adivinhar.

No caso mais comum — o primeiro deploy de um domínio recém-apontado — o endereço
oficial ainda não funciona, e ele conclui que o deploy falhou quando não falhou.

<a id="a11"></a>

### A11 — Por que o temporary_address não é guardado

Ele muda quando a Cloudez move o site, e uma cópia num arquivo do projeto
envelheceria em silêncio.

É a mesma razão pela qual o bloco `ssh` saiu do `.cloudez.yaml` ([A1](#a1)) — dado
derivado do servidor não se copia para o projeto.

<a id="a12"></a>

### A12 — Por que a verificação do domínio tem DUAS checagens

Comparar o A/AAAA do domínio com o IP do servidor responde bem no caso simples e
erra no caso comum: um domínio atrás de Cloudflare resolve para o **proxy**, não
para o servidor, e o site funciona perfeitamente.

Só com DNS, esse cenário é **indistinguível** de um domínio apontado para o lugar
errado. A saída era mostrar ⚠️ e perguntar ao usuário se havia CDN na frente — ou
seja, pedir que ele fizesse o diagnóstico por nós, no fim de um deploy que deu
certo.

O header `cez-verify` é servido pela Cloudez, então recebê-lo prova que a
requisição ao domínio **chegou** num servidor dela, com CDN na frente ou sem. Ele
só é consultado quando o DNS não bate: quando bate, não há o que desempatar e não
se gasta uma requisição ao site do usuário.

Qualquer código de status serve. Um **502 com o header presente** é justamente o
caso que interessa distinguir — o tráfego chegou, e o problema é a aplicação;
dizer "o DNS não aponta" ali mandaria procurar no lugar errado.

<a id="a13"></a>

### A13 — Por que a linha de alerta fala de ação, e não de causa

A linha fixa diz "use o endereço temporário por enquanto", e não "o domínio não
chega ao servidor". A diferença importa num dos três casos.

Quando o servidor do site não resolve, quem está cega é a **checagem** — não há
informação sobre o domínio. Uma linha fixa que afirmasse causa estaria errada ali,
e mandaria o usuário mexer num DNS que pode estar perfeito.

É o mesmo exagero que o `cez-verify` acabou de eliminar do caso do CDN ([A12](#a12)),
e reintroduzi-lo numa linha fixa desfaria o ganho. A causa vai no `summary`, que é
escrito por caso e admite não saber quando não sabe.

<a id="a14"></a>

### A14 — Por que não se fala em "ativar o HTTPS"

Esta entrada existe por um defeito de comportamento observado: sem nenhum passo
mandando, o modelo vinha dizendo ao usuário que faltava ativar o HTTPS no painel
depois de o site ser provisionado. Não falta, e não há onde ativar.

A Cloudez pede o certificado sozinha quando o domínio passa a apontar para ela, e
uma rotina periódica repete o pedido enquanto o site hospedado não tiver um. A
emissão é assíncrona: pode levar minutos, e nesse intervalo o site responde por
`http`. É por isso, aliás, que o `cloudez_health_check` tenta `https` e cai para
`http` — um site sem certificado **ainda** não é um site quebrado.

Um deploy é o momento mais provável para o usuário abrir o domínio pela primeira
vez, e portanto o momento em que essa frase errada custa mais: ela manda procurar
no painel um botão que não existe. Se ele perguntar, a resposta é que o
certificado sai sozinho.

<a id="a15"></a>

### A15 — Por que o deploy grava o framework

O `framework` do site passou a existir depois de muitos sites já criados, e o
único ponto que o preenchia era o passo 5 de [setup.md](setup.md) — e só quando o
document root ou a porta também precisavam de ajuste. Um site já configurado
nunca voltava ao setup, então ficava com o campo vazio para sempre.

O deploy é a interação que todo site repete, e já lê o site no passo 1 com o
projeto aberto no diretório local: é o momento em que o modelo tem as duas coisas
de que precisa para escolher o valor certo. A instrução vem no próprio retorno do
`cloudez_get_site`, e não só aqui, para valer em qualquer leitura do site.

Ele não pede aceite porque não muda o que o site serve, e não interrompe o deploy
quando falha pelo mesmo motivo: publicar não depende dele.

O caso em que há algo a fazer é outro: DNS apontado há bastante tempo e site
ainda sem HTTPS. Aí existe uma tool — `cloudez_request_certificate` —, mas ela é
para pedido explícito do usuário, não para ser chamada no fim de um deploy.
Pedir antes de o domínio apontar cria um certificado pendente que nunca entra na
fila, e a emissão automática passa a pular o site: pedir cedo demais impede a
emissão em vez de antecipá-la. O detalhe está no apêndice B do contrato das
tools, no repositório da skill.

<a id="a16"></a>

### A16 — Por que o deploy confere o tipo do site

Até aqui, só o passo 5 de [setup.md](setup.md) olhava o tipo. Um `.cloudez.yaml`
escrito à mão, ou um setup feito antes de o site ser trocado de tipo, levava o
deploy inteiro até o fim num site `html` ou WordPress: release registrada, imagem
construída, container de pé — e a Cloudez seguindo a servir os arquivos antigos,
porque nesses tipos o nginx não encaminha para o container. Nenhum passo falha, e
o usuário só descobre comparando o que publicou com o que o navegador mostra.

Parar no passo 1 custa uma leitura que o deploy já faz. O caminho para seguir é a
conversão ([convert.md](convert.md)), e não "troque no painel", porque converter
também precisa guardar os arquivos que o site serve hoje, e o painel não faz isso.

<a id="a17"></a>

### A17 — Por que, sem config, o deploy pergunta o domínio em vez de parar

O deploy parava ao não achar o `.cloudez.yaml` e mandava o usuário rodar o setup
([setup.md](setup.md)). Num pedido real — "quero publicar meu site na Cloudez", num
projeto WordPress sem config —, a resposta foi uma lista de pendências: rodar o
setup com domínio e environment, escrever o Compose, trocar as credenciais do
banco, e só no fim um "se o site já existe como WordPress, use a conversão"
([convert.md](convert.md)). Nenhuma pergunta, o usuário de volta ao terminal
digitando comando, e nomes de arquivo na conversa.

O que decide o caminho é uma coisa só: se o site já existe na Cloudez, e com qual
tipo. Isso se descobre com o domínio e uma leitura, então o deploy pergunta o
domínio e encaminha — site novo vai para o setup, que o cria; site de outro tipo
vai para a conversão; site pronto vai para o setup só para criar a config. O que
falta no projeto aparece depois, no passo em que importa.
