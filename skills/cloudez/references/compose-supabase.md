# Supabase: só self-hosted, com o Studio em `studio.<domínio>`

Quando usar: a aplicação usa Supabase (`@supabase/supabase-js`, `@supabase/ssr`, um diretório `supabase/`, `SUPABASE_URL` no ambiente). É a parte do passo 2 de [compose.md](compose.md) que vale para esse caso.

Volte para [compose.md](compose.md) depois de ler: os passos 3 a 6 continuam valendo.

Supabase não é só um PostgreSQL: é autenticação, storage, realtime, RLS e edge
functions em volta dele. A única forma de hospedar na Cloudez uma aplicação que
usa Supabase é o **Supabase self-hosted**. Não ofereça migrar para Node +
PostgreSQL, e **nunca troque a aplicação para um PostgreSQL comum**. O código da
aplicação não muda; o que migra são os dados (dump e restore do banco, cópia do
storage).

Avise o usuário antes de começar: a stack tem mais de dez containers e pede uma
cloud com mais memória.

**O Compose** é o da stack oficial (o `docker/docker-compose.yml` do repositório
`supabase/supabase`), fixado numa tag e ajustado às restrições do passo 3 de [compose.md](compose.md):

- **Uma só porta.** O nginx da Cloudez manda o domínio e os aliases do site para
  a `custom_port`, repassando o `Host` original, então o gateway da stack
  (`api-gw`) é quem a publica, em `127.0.0.1`, e roteia pelo host. No domínio, as
  rotas do Supabase (`/auth/v1`, `/rest/v1`, `/storage/v1`, `/realtime/v1`,
  `/functions/v1`) seguem como estão e o resto vai para a aplicação. Em
  `studio.<domínio>`, tudo vai para o Studio.
- **Arquivos de configuração ficam como estão.** Bind de arquivo (os do gateway,
  os `.sql` de init do banco, o `pooler.exs`) fica na release e acompanha cada
  deploy. Já bind de diretório vai para `shared/` e congela no primeiro deploy,
  então o diretório de edge functions, que é código, vai para dentro da imagem do
  `functions`, com um Dockerfile que o copia.
- **Dado vai em volume nomeado**: o datadir do banco e o storage. O banco é
  exceção à regra das engines: fica no container, com o backup da seção de banco
  no container de [compose-banco.md](compose-banco.md#banco-no-container-com-volume-nomeado-o-padrão-para-as-demais-engines).
- **Segredos** (`JWT_SECRET`, `ANON_KEY`, `SERVICE_ROLE_KEY`, senha do banco,
  `DASHBOARD_PASSWORD`) são gerados novos e vão pelo `cloudez_set_env`, nunca para
  o arquivo. `SUPABASE_PUBLIC_URL`, `API_EXTERNAL_URL` e `SITE_URL` são
  `https://<domínio>`.

**O Studio vai sempre junto, em `studio.<domínio>`.** Ele é um alias do mesmo
site, e não um site a mais: grave-o com `cloudez_configure_site(domain,
add_aliases: ["studio.<domínio>"])`, depois de o usuário concordar com o
subdomínio. A API acrescenta também `www.studio.<domínio>` e pede o certificado de
novo sozinha. O DNS do subdomínio precisa apontar para a Cloudez como o do
domínio; diga isso ao usuário.

Na raiz do subdomínio, o Studio roda com a imagem oficial `supabase/studio`, sem
build próprio. Não use um subdiretório como `/studio`: o caminho base dele é
fixado no build, e a imagem oficial sai sem ele.

**O Studio sempre sobe com autenticação (basic auth).** Ele é a área sensível da
aplicação: dá acesso ao banco inteiro, sem passar pelo RLS. O Studio não tem login
próprio, então quem pede a senha é o gateway, e estas regras não têm exceção:

- a rota do host `studio.<domínio>` tem basic auth em todos os caminhos, com o
  `DASHBOARD_USERNAME` e o `DASHBOARD_PASSWORD`;
- a senha é gerada nova, longa e aleatória, e vai pelo `cloudez_set_env`. Nunca o
  valor de exemplo do `.env` oficial, nunca vazia, e nunca escrita no arquivo;
- nenhuma outra rota chega ao Studio. No Compose oficial, o que não casa com
  nenhuma rota cai no Studio; aqui esse resto vai para a aplicação;
- a porta do Studio nunca é publicada no host.

Diga ao usuário o usuário do dashboard e onde a senha está guardada (o arquivo de
ambiente do servidor), sem mostrar a senha na conversa. O deploy ([deploy.md](deploy.md))
confere, depois de cada publicação, que o Studio recusa quem chega sem a senha.

Se o usuário só quer hospedar a aplicação na Cloudez e continuar usando o
Supabase da supabase.com, nada disso se aplica: a aplicação segue apontando para
lá.
