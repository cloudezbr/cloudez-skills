# Cloudez Skill

Skill de agente para desenvolver, publicar e reverter sites na hospedagem Cloudez, em qualquer agente compatível com Agent Skills (Claude Code, Codex, Cursor, OpenCode e outros).

## Requisitos

- Node.js 22.20+ (o `npx skills` exige; os scripts da skill rodam em 20+)
- `ssh` e `tar` na máquina, com uma chave SSH em `~/.ssh/`
- Servidor MCP da Cloudez registrado no agente (ver Configuração)
- Conta na Cloudez (a skill também cria uma)

## Tecnologias

- Agent Skills (`SKILL.md` + `references/` + `scripts/`)
- MCP `cloudez` como control plane; transporte por tar sobre ssh
- Node.js sem dependências externas
- bats-core + `node:test` + shellcheck

## Configuração

Registre o servidor MCP da Cloudez no agente:

```bash
claude mcp add cloudez -s user -- npx -y cloudez-mcp   # Claude Code
codex mcp add cloudez -- npx -y cloudez-mcp            # Codex
```

Nos demais agentes, adicione um servidor MCP `cloudez` com o comando `npx -y cloudez-mcp`. O token não vai na configuração: a skill conduz o login e guarda o token em `~/.cloudez/`.

| Variável | Descrição |
|---|---|
| `CLOUDEZ_TOKEN` | Token da Cloudez, se preferir não guardar em arquivo |
| `CLOUDEZ_API_URL` | URL da API, só para apontar para outro ambiente |

## Instalação e execução

```bash
npx skills add cloudezbr/cloudez-skill -g   # escolha os agentes no menu
```

Instale com `-g` (no usuário): instalada dentro do projeto, a pasta da skill iria para o servidor junto com o site no deploy. Depois, peça ao agente em linguagem natural, por exemplo "publica meu site na Cloudez" ou "volta o site para a versão anterior".

## Outros comandos

```bash
npx skills update cloudez     # atualiza a skill
test/run.sh                   # suíte completa
test/run.sh --strict          # igual, com ferramenta ausente virando erro (CI)
test/run.sh --coverage        # acrescenta a cobertura dos scripts
./vendor-mcp.sh [caminho]     # traz as libs do cloudez-mcp para scripts/lib/
```
