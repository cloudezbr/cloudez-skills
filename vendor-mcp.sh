#!/usr/bin/env bash
# Uso: ./vendor-mcp.sh [caminho-do-repo-cloudez-mcp]
#
# Traz as duas bibliotecas do cloudez-mcp que os scripts da skill importam:
#
#   cloudez-auth.mjs   o contrato do token, que o cloudez-login importa em vez
#                      de reimplementar.
#   cloudez-state.mjs  o contrato do estado do deploy, que o cloudez-sync e o
#                      cloudez-pull importam em vez de reimplementar.
#
# O servidor MCP nao vem: o usuario o registra a parte no agente dele.
#
# O contrato do ESTADO tem dois escritores, o MCP e o cloudez-sync. Enquanto o
# sync foi Go, os dois mantinham o schema em separado, e um round-trip pela struct
# de Go apagava em silencio o campo que ela nao conhecia. Importar em vez de
# reimplementar tira isso da disciplina de quem edita e passa para o build.
#
# A skill versiona as bibliotecas para quem a instala nao precisar de etapa de
# build. A fonte mora em OUTRO repositorio, entao este script nao compila: ele
# chama o bundle la e copia o resultado. As bibliotecas carregam a versao no
# cabecalho, o que permite saber de qual cloudez-mcp esta copia veio.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
fonte="${1:-../cloudez-mcp}"
destino="skills/cloudez/scripts/lib"

[ -f "$fonte/package.json" ] || {
  echo "cloudez: repositorio do MCP nao encontrado em '$fonte'." >&2
  echo "cloudez: passe o caminho como argumento: ./vendor-mcp.sh /caminho/cloudez-mcp" >&2
  exit 1
}

echo "── bundle em $fonte"
# npm_config_script_shell forca o bash deste processo a rodar os scripts do
# package.json. Sem isso, o npm do Windows chama cmd.exe por padrao, que nao
# entende "$npm_package_version" no banner do esbuild, e a biblioteca sai com a
# string literal em vez da versao.
(cd "$fonte" && npm_config_script_shell="$BASH" npm run bundle)

mkdir -p "$destino"
for artefato in cloudez-auth.mjs cloudez-state.mjs; do
  [ -f "$fonte/dist/$artefato" ] || {
    echo "cloudez: $fonte/dist/$artefato nao foi gerado pelo bundle." >&2
    exit 1
  }
  cp "$fonte/dist/$artefato" "$destino/$artefato"
  echo "── vendorado em $destino/$artefato"
done

grep -m1 '^// cloudez-mcp ' "$destino/cloudez-auth.mjs"
