#!/usr/bin/env bats
# As duas bibliotecas vendoradas do cloudez-mcp em skills/cloudez/scripts/lib/.
#
# O servidor MCP nao vem mais junto: o usuario o registra a parte. Ficam so as
# duas bibliotecas que os scripts importam, cloudez-auth (o contrato do token,
# usado pelo cloudez-login) e cloudez-state (o contrato do estado do deploy,
# usado pelo cloudez-sync e pelo cloudez-pull). Reimplementa-las seria ter duas
# versoes de uma coisa so, com o pior modo de falha possivel: o login dizendo
# autenticado e o MCP dizendo que nao.
#
# O risco de versionar a copia e ela apodrecer: um arquivo truncado, uma versao
# antiga, um bundle gerado de um fonte quebrado. Estes testes exercitam o arquivo
# REAL, e nao afirmam sobre o fonte do outro repositorio.

load helpers/setup

LIB="skills/cloudez/scripts/lib/cloudez-auth.mjs"
ESTADO="skills/cloudez/scripts/lib/cloudez-state.mjs"

setup() {
  cd "$BATS_TEST_DIRNAME/.." || return 1
  command -v node >/dev/null 2>&1 || skip "node nao instalado"
}

versao() { grep -m1 -oE '^// cloudez-mcp [0-9]+\.[0-9]+\.[0-9]+' "$1" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'; }

# A regra e por FORMA, e nao por lista de nomes: todo import ou e relativo (".")
# ou e builtin ("node:"). Contar em vez de casar o complemento evita o ponto cego
# de uma regex negativa: `nanoid` passaria por "node:" numa comparacao apressada.
sem_node_modules() {
  total=$(grep -cE '^import .* from' "$1")
  permitidos=$(grep -cE '^import .* from "(node:|[.])' "$1")
  [ "$total" -eq "$permitidos" ] || {
    echo "import de pacote externo em $1:" >&2
    grep -nE '^import .* from' "$1" | grep -vE 'from "(node:|[.])' >&2
    false
  }
}

@test "as duas bibliotecas existem e dizem de qual versao vieram" {
  [ -n "$(versao "$LIB")" ]
  [ -n "$(versao "$ESTADO")" ]
}

# Versoes diferentes significam que alguem copiou uma e esqueceu a outra.
@test "as duas bibliotecas vieram da mesma versao" {
  [ "$(versao "$LIB")" = "$(versao "$ESTADO")" ]
}

@test "a biblioteca de auth nao depende de node_modules ao lado" {
  sem_node_modules "$LIB"
}

@test "a biblioteca de estado nao depende de node_modules ao lado" {
  sem_node_modules "$ESTADO"
}

# Importar o servidor sobe um transporte stdio e penduraria quem so queria uma
# funcao. Se o bundle:lib um dia apontar para o index.ts, isto estoura no timeout.
@test "importar a biblioteca de auth nao sobe servidor nenhum" {
  run node -e "
    const t = setTimeout(() => { console.error('pendurou'); process.exit(1) }, 5000)
    import('./$LIB').then((m) => {
      clearTimeout(t)
      const faltando = ['resolveToken','tokenSource','verifyToken','tokenFile','saveToken']
        .filter((n) => typeof m[n] !== 'function')
      if (faltando.length) { console.error('faltando: ' + faltando); process.exit(1) }
      process.exit(0)
    })
  "
  [ "$status" -eq 0 ]
}

@test "importar a biblioteca de estado nao sobe servidor nenhum" {
  run node -e "
    const t = setTimeout(() => { console.error('pendurou'); process.exit(1) }, 5000)
    import('./$ESTADO').then((m) => {
      clearTimeout(t)
      const faltando = ['loadState','saveState','statePath','loadPullState']
        .filter((n) => typeof m[n] !== 'function')
      if (faltando.length) { console.error('faltando: ' + faltando); process.exit(1) }
      process.exit(0)
    })
  "
  [ "$status" -eq 0 ]
}

# A skill e distribuida pelo que esta COMMITADO, e a suite roda contra a arvore de
# TRABALHO. Foi assim que o _ignore.mjs ficou de fora de um commit: `git commit -am`
# estagia os modificados e nao os novos, e o cloudez-sync morria no import com a
# suite verde.
@test "todo import relativo aponta para arquivo rastreado pelo git" {
  git -C "$PLUGIN_ROOT" rev-parse --git-dir >/dev/null 2>&1 || skip "nao e um repositorio git"

  run node "$PLUGIN_ROOT/test/helpers/imports.mjs" "$PLUGIN_ROOT"
  [ "$status" -eq 0 ] || {
    echo "$output"
    false
  }
}
