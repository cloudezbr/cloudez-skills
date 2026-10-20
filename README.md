# Cloudez Skills

Skill de agente para desenvolver, publicar e reverter sites na hospedagem Cloudez, em qualquer agente compatível com Agent Skills (Claude Code, Codex, Cursor, OpenCode e outros).

## Requisitos

- Node.js 22.20+
- `ssh` e `tar` na máquina, com uma chave SSH em `~/.ssh/`

## Tecnologias

- Agent Skills (`SKILL.md` + `references/` + `scripts/`)
- MCP `cloudez` como control plane; transporte por tar sobre ssh
- Node.js sem dependências externas
- bats-core + `node:test` + shellcheck

## Instalação

```bash
# Instalar a skill (o MCP é configurado por ela no primeiro uso)
npx skills add cloudezbr/cloudez-skills -g

# Atualizar a skill (o MCP se atualiza sozinho a cada sessão nova)
npx skills update cloudez -g
```

Abaixo, o passo a passo de cada agente, inclusive para configurar o MCP manualmente, se preferir. Depois de configurar o MCP, abra uma sessão nova do agente.

<details>
<summary><b>Claude Code</b></summary>

```bash
npx skills add cloudezbr/cloudez-skills -g -a claude-code
claude mcp add cloudez -s user -- npx -y @cloudez/cloudez-mcp@latest   # MCP manual (opcional)
```

Conferir: `claude mcp list`.

</details>

<details>
<summary><b>Codex</b></summary>

```bash
npx skills add cloudezbr/cloudez-skills -g -a codex
codex mcp add cloudez -- npx -y @cloudez/cloudez-mcp@latest   # MCP manual (opcional)
```

Conferir: `codex mcp list`.

</details>

<details>
<summary><b>Cursor</b></summary>

```bash
npx skills add cloudezbr/cloudez-skills -g -a cursor
```

MCP manual (opcional): [Adicionar ao Cursor](https://cursor.com/link/mcp/install?name=cloudez&config=eyJjb21tYW5kIjoibnB4IiwiYXJncyI6WyIteSIsIkBjbG91ZGV6L2Nsb3VkZXotbWNwQGxhdGVzdCJdfQ==), ou acrescente em `~/.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "cloudez": { "command": "npx", "args": ["-y", "@cloudez/cloudez-mcp@latest"] }
  }
}
```

</details>

<details>
<summary><b>VS Code (GitHub Copilot)</b></summary>

```bash
npx skills add cloudezbr/cloudez-skills -g -a github-copilot
```

MCP manual (opcional): [Instalar no VS Code](https://vscode.dev/redirect?url=vscode%3Amcp%2Finstall%3F%257B%2522name%2522%253A%2522cloudez%2522%252C%2522type%2522%253A%2522stdio%2522%252C%2522command%2522%253A%2522npx%2522%252C%2522args%2522%253A%255B%2522-y%2522%252C%2522%2540cloudez%252Fcloudez-mcp%2540latest%2522%255D%257D), ou pelo terminal:

```bash
code --add-mcp '{"name":"cloudez","type":"stdio","command":"npx","args":["-y","@cloudez/cloudez-mcp@latest"]}'
```

</details>

<details>
<summary><b>GitHub Copilot CLI</b></summary>

```bash
npx skills add cloudezbr/cloudez-skills -g -a github-copilot
```

MCP manual (opcional): `/mcp add` dentro do `copilot`, ou acrescente em `~/.copilot/mcp-config.json`:

```json
{
  "mcpServers": {
    "cloudez": { "type": "stdio", "command": "npx", "args": ["-y", "@cloudez/cloudez-mcp@latest"] }
  }
}
```

</details>

<details>
<summary><b>Gemini CLI</b></summary>

```bash
npx skills add cloudezbr/cloudez-skills -g -a gemini-cli
gemini mcp add -s user cloudez npx -y @cloudez/cloudez-mcp@latest   # MCP manual (opcional)
```

Conferir: `gemini mcp list`.

</details>

<details>
<summary><b>Windsurf / Devin Desktop</b></summary>

```bash
npx skills add cloudezbr/cloudez-skills -g -a windsurf
```

MCP manual (opcional): acrescente em `~/.config/devin/mcp_config.json` (Windows: `%APPDATA%\devin\mcp_config.json`; em versões antigas do Windsurf, `~/.codeium/windsurf/mcp_config.json`):

```json
{
  "mcpServers": {
    "cloudez": { "command": "npx", "args": ["-y", "@cloudez/cloudez-mcp@latest"] }
  }
}
```

</details>

<details>
<summary><b>Antigravity</b></summary>

```bash
npx skills add cloudezbr/cloudez-skills -g -a antigravity
```

MCP manual (opcional): no painel do agente, **… → MCP Servers → Manage MCP Servers → View raw config**, ou direto em `~/.gemini/config/mcp_config.json`:

```json
{
  "mcpServers": {
    "cloudez": { "command": "npx", "args": ["-y", "@cloudez/cloudez-mcp@latest"] }
  }
}
```

</details>

<details>
<summary><b>Zed</b></summary>

```bash
npx skills add cloudezbr/cloudez-skills -g -a zed
```

MCP manual (opcional): **Settings → AI → MCP Servers → Add Local Server**, ou no arquivo de configurações (`zed: open settings file`):

```json
{
  "context_servers": {
    "cloudez": { "command": "npx", "args": ["-y", "@cloudez/cloudez-mcp@latest"], "env": {} }
  }
}
```

</details>

<details>
<summary><b>OpenCode</b></summary>

```bash
npx skills add cloudezbr/cloudez-skills -g -a opencode
```

MCP manual (opcional): acrescente em `~/.config/opencode/opencode.json`. O `timeout` dá tempo para o primeiro download do pacote:

```json
{
  "mcp": {
    "cloudez": {
      "type": "local",
      "command": ["npx", "-y", "@cloudez/cloudez-mcp@latest"],
      "enabled": true,
      "timeout": 60000
    }
  }
}
```

</details>

<details>
<summary><b>Kilo Code</b></summary>

```bash
npx skills add cloudezbr/cloudez-skills -g -a kilo
```

MCP manual (opcional): acrescente em `~/.config/kilo/kilo.json`. O `timeout` dá tempo para o primeiro download do pacote:

```json
{
  "mcp": {
    "cloudez": {
      "type": "local",
      "command": ["npx", "-y", "@cloudez/cloudez-mcp@latest"],
      "enabled": true,
      "timeout": 60000
    }
  }
}
```

</details>

<details>
<summary><b>Grok</b></summary>

```bash
npx skills add cloudezbr/cloudez-skills -g -a grok
grok mcp add cloudez -- npx -y @cloudez/cloudez-mcp@latest   # MCP manual (opcional)
```

Conferir: `grok mcp list`.

</details>

Agentes que rodam só no navegador (Lovable, v0, Bolt, Replit) não são suportados: o MCP da Cloudez precisa rodar na máquina do usuário, com acesso a `ssh` e aos arquivos do projeto.

## Outros comandos

```bash
test/run.sh                   # suíte completa
test/run.sh --strict          # igual, com ferramenta ausente virando erro (CI)
./vendor-mcp.sh [caminho]     # traz as libs do cloudez-mcp para scripts/lib/
```
