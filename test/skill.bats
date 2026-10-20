#!/usr/bin/env bats
# A estrutura da skill em skills/cloudez/.
#
# Um link quebrado ou uma referencia que ninguem aponta nao da erro em lugar
# nenhum: o modelo simplesmente nunca le aquele procedimento, e o sintoma aparece
# longe daqui, como um passo pulado no meio de um deploy.

load helpers/setup

setup() {
  command -v node >/dev/null 2>&1 || skip "node nao instalado"
}

checa() {
  run node "$REPO_ROOT/test/helpers/skill.mjs" "$REPO_ROOT" "$1"
  [ "$status" -eq 0 ] || {
    echo "$output"
    false
  }
}

@test "skill: o SKILL.md tem name igual a pasta e description de ate 1024 caracteres" {
  checa frontmatter
}

@test "skill: todo link relativo, com ancora, aponta para algo que existe" {
  checa links
}

@test "skill: toda referencia e alcancavel a partir do SKILL.md" {
  checa alcance
}

@test "skill: todo script citado existe em scripts/" {
  checa scripts
}

# Cada um destes so funciona num agente especifico, ou aponta para um layout que
# nao existe mais.
@test "skill: nenhum vocabulario especifico de um agente" {
  checa vocabulario
}

# O menu do `npx skills add` mostra um item por SKILL.md encontrado no repositorio.
@test "skill: o unico SKILL.md do repositorio e o da skill cloudez" {
  git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1 || skip "nao e um repositorio git"
  checa unica
}
