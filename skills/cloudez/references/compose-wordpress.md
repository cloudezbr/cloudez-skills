# WordPress vindo do servidor: OpenLiteSpeed, com o `wp-content` em `shared/`

Quando usar: o projeto é um WordPress baixado do servidor por [convert.md](convert.md) (há `wp-config.php` e `wp-includes/` na raiz). É a parte do passo 2 de [compose.md](compose.md) que vale para esse caso.

Volte para [compose.md](compose.md) depois desta receita: as restrições do passo 3 e os passos 4 a 6 continuam valendo.

Vale quando [convert.md](convert.md) baixou o site com o `cloudez-pull`: o projeto é
a raiz de um WordPress (`wp-config.php`, `wp-includes/`, `wp-content/`) e, se o
banco veio junto, há um dump em `.cloudez/db/dump.sql.gz`. Um site `html` baixado
do mesmo jeito não usa esta seção: é site estático, e segue o caminho normal
de [compose.md](compose.md).

**Há receita aqui, e ela não é para ser reinventada.** O arranjo abaixo foi
montado e medido com Docker local; cada linha resolve um problema que aparece
quando falta. Ajuste só as portas e o `wp-config.php`, como as regras pedem.

**Antes de tudo, o `wp-config.php` baixado contém a senha do banco de
produção e os salts.** Não deixe o usuário commitar nem publicar o projeto antes
de reescrevê-lo (logo abaixo). Depois da reescrita ela some do arquivo.

## Os arquivos

`Dockerfile`:

```dockerfile
FROM litespeedtech/openlitespeed:1.9.3-lsphp83
RUN cd /usr/local/lsws/conf && \
    awk '/^(listener (Default|HTTPS)|vhTemplate (centralConfigLog|EasyRailsWithSuEXEC))/{skip=1} skip&&/^}/{skip=0;next} !skip' httpd_config.conf \
    | sed -e 's/^disableWebAdmin.*/disableWebAdmin 1/' \
          -e 's/listeners *HTTP, HTTPS/listeners HTTP/' \
          -e 's/address *\*:80$/address CEZ_LISTEN/' > httpd_config.conf.cloudez
COPY docker/ols-start.sh /usr/local/bin/cloudez-start
COPY . /var/www/vhosts/localhost/html/
# O script já foi copiado acima, e no docroot ele seria servido pelo site.
RUN rm -rf /var/www/vhosts/localhost/html/docker
ENTRYPOINT ["/bin/sh", "/usr/local/bin/cloudez-start"]
```

`docker/ols-start.sh`:

```sh
#!/bin/sh
set -e
conf=/usr/local/lsws/conf/httpd_config.conf
sed "s|CEZ_LISTEN|${BIND_ADDRESS:-*}:${PORT:-8080}|" "$conf.cloudez" > "$conf"
uid="${WP_UID:-1000}" gid="${WP_GID:-1000}"
chown "$uid:$gid" /var/www/vhosts/localhost/html
env_php=/var/www/vhosts/localhost/cloudez-env.php
php -r '$o = []; foreach (getenv() as $k => $v) if (strpos($k, "WORDPRESS_") === 0) $o[$k] = $v; file_put_contents($argv[1], "<?php return " . var_export($o, true) . ";\n");' "$env_php"
chown "$uid:$gid" "$env_php"
chmod 600 "$env_php"
exec /entrypoint.sh "$@"
```

`wp-config.php`, o modelo (a reescrita do arquivo baixado parte dele):

```php
<?php
// Gerado pelo entrypoint da imagem, porque a OpenLiteSpeed não repassa o ambiente do container ao PHP.
if (!function_exists('cloudez_env')) {
  function cloudez_env(string $name, string $default = ''): string {
    static $env = null;
    $env ??= (@include '/var/www/vhosts/localhost/cloudez-env.php') ?: [];
    return $env["WORDPRESS_$name"] ?? $default;
  }
}

define('DB_NAME', cloudez_env('DB_NAME'));
define('DB_USER', cloudez_env('DB_USER'));
define('DB_PASSWORD', cloudez_env('DB_PASSWORD'));
define('DB_HOST', cloudez_env('DB_HOST', '127.0.0.1'));
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');

foreach (['AUTH_KEY', 'SECURE_AUTH_KEY', 'LOGGED_IN_KEY', 'NONCE_KEY', 'AUTH_SALT', 'SECURE_AUTH_SALT', 'LOGGED_IN_SALT', 'NONCE_SALT'] as $chave) {
  define($chave, cloudez_env($chave));
}

$table_prefix = cloudez_env('TABLE_PREFIX', 'wp_');

if (cloudez_env('HOME') !== '') {
  define('WP_HOME', cloudez_env('HOME'));
  define('WP_SITEURL', cloudez_env('HOME'));
}

// O nginx da Cloudez termina o TLS e repassa em HTTP.
if (($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https') {
  $_SERVER['HTTPS'] = 'on';
}

define('DISALLOW_FILE_EDIT', true);
// O core pertence ao root na imagem, e sem isto o wp-admin pede FTP para instalar plugin.
define('FS_METHOD', 'direct');
define('WP_DEBUG', false);

if (!defined('ABSPATH')) {
  define('ABSPATH', __DIR__ . '/');
}
require_once ABSPATH . 'wp-settings.php';
```

`docker-compose.yml`:

```yaml
services:
  wordpress:
    build: .
    ports:
      - "127.0.0.1:8080:8080"
    environment:
      PORT: "8080"
      WP_UID: "${CLOUDEZ_UID:-1000}"
      WP_GID: "${CLOUDEZ_GID:-1000}"
      WORDPRESS_DB_HOST: db
      WORDPRESS_DB_NAME: wordpress
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: wordpress
      WORDPRESS_TABLE_PREFIX: wp_
      WORDPRESS_HOME: http://localhost:8080
    volumes:
      - ./wp-content:/var/www/vhosts/localhost/html/wp-content
    depends_on:
      - db
    restart: unless-stopped

  db:
    image: mariadb:11.4
    environment:
      MARIADB_DATABASE: wordpress
      MARIADB_USER: wordpress
      MARIADB_PASSWORD: wordpress
      MARIADB_RANDOM_ROOT_PASSWORD: "1"
    volumes:
      - db:/var/lib/mysql
      - ./.cloudez/db:/docker-entrypoint-initdb.d:ro
    restart: unless-stopped

volumes:
  db:
```

`docker-compose.cloudez.yml`:

```yaml
services:
  db:
    profiles: ["dev"]

  wordpress:
    depends_on: !reset null
    network_mode: host
    ports: !reset null
    env_file:
      - .cloudez.env
    environment:
      BIND_ADDRESS: 127.0.0.1
      PORT: "3000"
      WORDPRESS_DB_HOST: !reset null
      WORDPRESS_DB_NAME: !reset null
      WORDPRESS_DB_USER: !reset null
      WORDPRESS_DB_PASSWORD: !reset null
      WORDPRESS_TABLE_PREFIX: !reset null
      WORDPRESS_HOME: !reset null
```

`.dockerignore`:

```
.git
.agents
.claude
.codex
.cursor
.gemini
.windsurf
.vscode
.idea
skills-lock.json
.cloudez
.cloudez.env
.cloudez.yaml
.cloudezignore
.gitignore
.dockerignore
Dockerfile
docker-compose*.yml
wp-content
```

## Por que cada peça existe

- **A imagem escuta só na porta configurada.** A
  `litespeedtech/openlitespeed` abre 80, 443, 8088 e o admin em 7080; em
  `network_mode: host` isso colidiria com o nginx do servidor. O Dockerfile tira
  os listeners HTTPS e Default e o admin, e o `ols-start.sh` troca o
  `CEZ_LISTEN` por `${BIND_ADDRESS:-*}:${PORT:-8080}` a cada start.
- **O PHP roda como o dono do docroot.** O vhost da imagem usa `setUIDMode 2`, e o
  `ols-start.sh` dá ao docroot o dono `WP_UID:WP_GID`. Em produção esses são o
  `CLOUDEZ_UID`/`CLOUDEZ_GID` que o deploy exporta, o mesmo usuário dono do
  `shared/`, e é por isso que não há `user:` na sobreposição: o container sobe
  como root e o PHP grava no `wp-content` montado.
- **A OpenLiteSpeed não repassa o ambiente do container ao PHP.** O
  `ols-start.sh` grava as `WORDPRESS_*` num arquivo PHP fora do docroot, modo
  600, e o `wp-config.php` as lê com `cloudez_env()`.
- **`FS_METHOD direct`.** O core pertence ao root na imagem; sem isto o
  WordPress pede FTP para instalar plugin.
- **`DISALLOW_FILE_EDIT`**, não `DISALLOW_FILE_MODS`: o editor de tema e de
  plugin do wp-admin sai, e instalar e atualizar plugin continua funcionando.
- **O dump restaura sozinho na primeira subida.** O MariaDB executa o que está
  em `.cloudez/db` quando o volume é novo. Com o volume já criado, o dump não é
  relido; para restaurar de novo, o volume precisa ser apagado.
- **O `.dockerignore`** tira da imagem o dump, o arquivo de ambiente e o
  `wp-content`, que chega sempre pelo bind. E tira os arquivos do projeto
  (`Dockerfile`, Compose, `.cloudez.yaml`, `.gitignore`): o `COPY .` vai para o
  docroot, e tudo que entra ali o site serve para qualquer um. Pelo mesmo motivo
  o `docker/` é apagado logo depois da cópia. Medido: o docroot fica só com o
  WordPress. Se o projeto tiver outros arquivos que não são do site, como um
  `README.md`, acrescente-os aqui.
- **O script fica em `docker/`, e não em `.cloudez/`.** O setup ([setup.md](setup.md)) põe
  `.cloudez/` no `.gitignore`, e o deploy não envia o que o `.gitignore` exclui:
  dentro de `.cloudez/`, o build no servidor não acharia o script.

## As regras

1. **Reescreva o `wp-config.php` baixado a partir do modelo.** Mantenha todo
   `define` próprio do site (`WP_MEMORY_LIMIT`, `WP_ALLOW_MULTISITE`,
   `MULTISITE` e os demais de multisite, `WP_CACHE`, `WP_POST_REVISIONS` e afins)
   e troque `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_HOST`, os oito salts e o
   `$table_prefix` pelas linhas do modelo, com `cloudez_env()`. Saem também os
   `WP_HOME`/`WP_SITEURL` cravados, que o modelo define só quando há
   `WORDPRESS_HOME`. Nenhuma constante pode ficar definida duas vezes. Leia o
   arquivo só para essa reescrita, e não mostre na conversa nenhum valor de
   senha ou salt dele.
2. **`WORDPRESS_TABLE_PREFIX` local é o prefixo do arquivo original**, que é o
   das tabelas do dump. Com o prefixo errado, o WordPress local abre o instalador.
3. **`WORDPRESS_HOME` local é `http://localhost:<porta>`**, a mesma porta do
   `ports`. É o que faz o site local não redirecionar para o domínio de
   produção, que é o `siteurl` gravado no banco. Links absolutos dentro dos posts
   continuam apontando para o domínio.
4. **Em produção não há `WORDPRESS_HOME`**: vale o `siteurl` do banco, que já é
   o domínio.
5. **`PORT` na sobreposição é a `custom_port` do site.** Com `network_mode: host`
   não há mapeamento: a OpenLiteSpeed escuta direto em `127.0.0.1:<custom_port>`.
6. **O `wp-content` inteiro vai para `shared/`**, pelo bind `./wp-content`. O
   `cloudez_prepare_wordpress`, chamado depois da conversão, já o semeia a partir
   do backup que a conversão deixou no servidor, e grava as `WORDPRESS_*` de
   produção no arquivo de ambiente. Por isso o conteúdo de `wp-content` do
   projeto só seria usado num primeiro deploy sem essa semente. Para o deploy não
   enviar uploads que produção já tem, ponha `wp-content/uploads/` no
   `.cloudezignore`. Um site que compartilhava só `uploads`, `plugins` e
   `themes` não perde nada ao passar para o `wp-content` inteiro: o deploy
   completa o `shared/wp-content` com o que a release anterior tinha.
7. **O banco de produção é o que o WordPress já usava**, na instância da
   Cloudez. Não crie outro: registre `--database cloudez` com
   `node <skill>/scripts/cloudez-setup`.

## O que não foi verificado

Diga ao usuário, sem afirmar o contrário:

- se o nginx da Cloudez manda `X-Forwarded-Proto`. Sem ele, o WordPress atrás do
  TLS pode gerar links `http://` e entrar em redirecionamento;
- se o MySQL do servidor aceita conexão TCP em `127.0.0.1`. O container em host
  mode não tem o socket do servidor, e é por isso que o `localhost` do
  `DB_HOST` original vira `127.0.0.1`;
- se o servidor tem `mysqldump` (ou `mariadb-dump`) e `du`, que o download usa.
