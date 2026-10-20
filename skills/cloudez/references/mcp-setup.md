# Configurar o MCP da Cloudez

Quando usar: nenhuma tool `cloudez_*` está disponível e o agente não informou
uma falha de conexão de um servidor já registrado. O SKILL.md manda para cá.

O MCP é o pacote npm `@cloudez/cloudez-mcp`, registrado no agente com o nome
`cloudez` e o comando `npx -y @cloudez/cloudez-mcp@latest`. O `@latest` faz o
`npx` buscar a versão mais nova a cada sessão: é assim que o MCP se atualiza
sozinho. Sem ele, o agente fica preso na versão guardada no cache.

## 1. Perguntar antes

Diga em uma frase que, para continuar, falta configurar o servidor da Cloudez
neste agente, e pergunte se pode fazer isso agora. Mexer na configuração do
agente é decisão do usuário, mesmo sendo para o próprio pedido dele.

Com "não", mostre o comando da seção 2 para ele rodar quando quiser e pare.

## 2. Registrar

Use o jeito do agente em que você está rodando. Todos registram para o usuário
inteiro, e não só para este projeto: a skill está instalada para todos os
projetos, e o MCP precisa estar também.

| Agente | Como registrar |
| --- | --- |
| Claude Code | `claude mcp add cloudez -s user -- npx -y @cloudez/cloudez-mcp@latest` |
| Codex | `codex mcp add cloudez -- npx -y @cloudez/cloudez-mcp@latest` |
| Gemini CLI | `gemini mcp add -s user cloudez npx -y @cloudez/cloudez-mcp@latest` |
| Grok | `grok mcp add cloudez -- npx -y @cloudez/cloudez-mcp@latest` |
| VS Code (Copilot) | `code --add-mcp '{"name":"cloudez","type":"stdio","command":"npx","args":["-y","@cloudez/cloudez-mcp@latest"]}'` |
| Copilot CLI | entrada em `~/.copilot/mcp-config.json` (formato `mcpServers`, com `"type": "stdio"`) |
| Cursor | entrada em `~/.cursor/mcp.json` (formato `mcpServers`) |
| Windsurf / Devin Desktop | entrada em `~/.config/devin/mcp_config.json` (Windows: `%APPDATA%\devin\mcp_config.json`); em versões antigas do Windsurf, `~/.codeium/windsurf/mcp_config.json`. Use o que existir (formato `mcpServers`) |
| Antigravity | entrada em `~/.gemini/config/mcp_config.json` (formato `mcpServers`) |
| Zed | entrada em `context_servers` no arquivo de configurações do Zed |
| OpenCode | entrada em `~/.config/opencode/opencode.json` (formato `mcp`) |
| Kilo Code | entrada em `~/.config/kilo/kilo.json` (formato `mcp`) |

Formato `mcpServers` (Cursor, Windsurf/Devin, Antigravity; no Copilot CLI,
acrescente `"type": "stdio"`):

```json
{
  "mcpServers": {
    "cloudez": { "command": "npx", "args": ["-y", "@cloudez/cloudez-mcp@latest"] }
  }
}
```

Zed, em `context_servers`:

```json
{
  "context_servers": {
    "cloudez": { "command": "npx", "args": ["-y", "@cloudez/cloudez-mcp@latest"], "env": {} }
  }
}
```

Formato `mcp` (OpenCode e Kilo Code). Os dois esperam as tools só 5 segundos por
padrão. Na primeira vez o `npx` ainda está baixando o pacote, e o servidor
falharia por tempo; por isso o `timeout`:

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

Ao editar um desses arquivos:

- **acrescente** a entrada `cloudez` e preserve o que já existe. O arquivo pode
  ter outros servidores do usuário;
- se já houver uma entrada `cloudez`, não crie outra: corrija o comando dela, se
  estiver diferente;
- se o arquivo não existir, crie com só esse conteúdo.

Se o agente não estiver na tabela, procure na documentação dele como adicionar
um servidor MCP local (stdio) para o usuário, com o nome `cloudez` e o comando
`npx -y @cloudez/cloudez-mcp@latest`.

## 3. Se não conseguir registrar

Sem permissão para rodar o comando ou editar o arquivo, mostre ao usuário o
comando ou o trecho de JSON exato da seção 2 e peça para ele aplicar. É o mesmo
registro; só muda quem executa.

## 4. Depois de registrar

A maioria dos agentes só carrega um servidor MCP novo numa sessão nova. Diga ao
usuário:

1. que o servidor da Cloudez foi configurado;
2. que é preciso abrir uma sessão nova (ou reconectar os servidores MCP, se o
   agente permitir) e repetir o pedido;
3. que, na primeira vez, o servidor pode aparecer como falho por alguns
   segundos enquanto o pacote é baixado; tentar de novo resolve.

Não siga com a operação nesta sessão: as tools `cloudez_*` ainda não existem
aqui, e qualquer passo adiante falharia.
