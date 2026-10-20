/**
 * Confere a estrutura da skill: frontmatter, links entre referências, scripts
 * citados e vocabulário que só funciona num agente específico.
 *
 * Uso: node test/helpers/skill.mjs <raiz> <checagem>
 * Imprime uma linha por problema e sai com 1. Silêncio e 0 é sucesso.
 */

import { execFileSync } from "node:child_process"
import { existsSync, readdirSync, readFileSync } from "node:fs"
import { dirname, join, relative, resolve } from "node:path"

const raiz = resolve(process.argv[2] ?? ".")
const checagem = process.argv[3]
const SKILL = join(raiz, "skills", "cloudez")

// Cada um só funciona no Claude Code, ou aponta para um layout que não existe mais.
const PROIBIDOS = [
  "/cloudez:",
  "AskUserQuestion",
  "mcp__",
  "allowed-tools",
  "argument-hint",
  "$ARGUMENTS",
  "CLAUDE_PLUGIN_ROOT",
  "preview_start",
  "launch.json",
  "commands/",
]

const markdowns = () => [join(SKILL, "SKILL.md"), ...referencias().map((f) => join(SKILL, "references", f))]
const referencias = () => readdirSync(join(SKILL, "references")).filter((f) => f.endsWith(".md"))
const rel = (f) => relative(raiz, f).split("\\").join("/")

/**
 * O frontmatter é YAML simples: chave no início da linha, e o bloco dobrado
 * (`>`) continua enquanto as linhas estiverem indentadas. Não vale a pena um
 * parser de YAML só para isto.
 */
function frontmatter(texto) {
  const m = texto.replace(/\r\n/g, "\n").match(/^---\n([\s\S]*?)\n---\n/)
  if (!m) return null
  const campos = {}
  let atual = null
  for (const linha of m[1].split("\n")) {
    const chave = linha.match(/^([a-z-]+):\s*(.*)$/)
    if (chave) {
      atual = chave[1]
      campos[atual] = chave[2] === ">" ? "" : chave[2].replace(/^"(.*)"$/, "$1")
    } else if (atual && /^\s+\S/.test(linha)) {
      campos[atual] = `${campos[atual]} ${linha.trim()}`.trim()
    }
  }
  return campos
}

// Links Markdown relativos, sem os externos e sem os que só têm âncora.
function links(arquivo) {
  const texto = readFileSync(arquivo, "utf8").replace(/```[\s\S]*?```/g, "")
  return [...texto.matchAll(/\]\(([^)\s]+)\)/g)]
    .map((m) => m[1])
    .filter((alvo) => !/^[a-z]+:/i.test(alvo) && !alvo.startsWith("#"))
}

/**
 * Âncoras de um arquivo: `id`/`name` explícitos e o slug de cada título, no
 * formato do GitHub (minúsculas, sem pontuação, espaço vira hífen).
 */
function ancoras(arquivo) {
  const texto = readFileSync(arquivo, "utf8")
  const explicitas = [...texto.matchAll(/<a\s+(?:id|name)="([^"]+)"/g)].map((m) => m[1])
  const slugs = [...texto.matchAll(/^#{1,6}\s+(.+)$/gm)].map((m) =>
    m[1]
      .trim()
      .toLowerCase()
      .replace(/[^\p{L}\p{N}\s_-]/gu, "")
      .replace(/\s/g, "-"),
  )
  return new Set([...explicitas, ...slugs])
}

const checagens = {
  frontmatter() {
    const arquivo = join(SKILL, "SKILL.md")
    if (!existsSync(arquivo)) return ["skills/cloudez/SKILL.md não existe"]
    const campos = frontmatter(readFileSync(arquivo, "utf8"))
    if (!campos) return ["SKILL.md sem frontmatter"]
    const problemas = []
    if (campos.name !== "cloudez") problemas.push(`name é '${campos.name}', deveria ser 'cloudez', o nome da pasta`)
    if (!campos.description) problemas.push("description ausente")
    else if (campos.description.length > 1024) problemas.push(`description tem ${campos.description.length} caracteres, o limite é 1024`)
    return problemas
  },

  links() {
    const problemas = []
    for (const arquivo of markdowns()) {
      for (const alvo of links(arquivo)) {
        const [caminho, ancora] = alvo.split("#")
        const destino = caminho ? resolve(dirname(arquivo), caminho) : arquivo
        if (!existsSync(destino)) problemas.push(`${rel(arquivo)} aponta para ${alvo}, que não existe`)
        else if (ancora && destino.endsWith(".md") && !ancoras(destino).has(ancora))
          problemas.push(`${rel(arquivo)} aponta para ${alvo}, mas a âncora não existe`)
      }
    }
    return problemas
  },

  // Toda referência precisa ser alcançável a partir do SKILL.md, senão o modelo nunca a lê.
  alcance() {
    const vistos = new Set()
    const fila = [join(SKILL, "SKILL.md")]
    while (fila.length) {
      const arquivo = fila.shift()
      if (vistos.has(arquivo) || !existsSync(arquivo)) continue
      vistos.add(arquivo)
      for (const alvo of links(arquivo)) {
        const caminho = alvo.split("#")[0]
        if (caminho.endsWith(".md")) fila.push(resolve(dirname(arquivo), caminho))
      }
    }
    return referencias()
      .map((f) => join(SKILL, "references", f))
      .filter((f) => !vistos.has(f))
      .map((f) => `${rel(f)} não é alcançável a partir do SKILL.md`)
  },

  scripts() {
    const problemas = []
    for (const arquivo of markdowns()) {
      const texto = readFileSync(arquivo, "utf8")
      for (const m of texto.matchAll(/<skill>\/scripts\/([\w.-]+)/g)) {
        if (!existsSync(join(SKILL, "scripts", m[1]))) problemas.push(`${rel(arquivo)} cita scripts/${m[1]}, que não existe`)
      }
    }
    return problemas
  },

  vocabulario() {
    const problemas = []
    for (const arquivo of markdowns()) {
      readFileSync(arquivo, "utf8")
        .split("\n")
        .forEach((linha, i) => {
          for (const termo of PROIBIDOS) if (linha.includes(termo)) problemas.push(`${rel(arquivo)}:${i + 1} contém '${termo}'`)
        })
    }
    return problemas
  },

  /**
   * O `npx skills add` lista todo SKILL.md que acha no repositório. Pelo git, e
   * não pelo disco, porque o que é ignorado (`.agents/`, `test/bats/`) não vai
   * para o GitHub e não aparece no menu de quem instala.
   */
  unica() {
    const saida = execFileSync(
      "git",
      ["-C", raiz, "ls-files", "--cached", "--others", "--exclude-standard", "*SKILL.md"],
      { encoding: "utf8" },
    )
    const achados = saida.split("\n").filter(Boolean)
    return achados.filter((f) => f !== "skills/cloudez/SKILL.md").map((f) => `${f}: SKILL.md fora de skills/cloudez/`)
  },
}

if (!checagens[checagem]) {
  process.stderr.write(`uso: node test/helpers/skill.mjs <raiz> <${Object.keys(checagens).join("|")}>\n`)
  process.exit(2)
}

const problemas = checagens[checagem]()
for (const p of problemas) console.log(p)
process.exit(problemas.length === 0 ? 0 : 1)
