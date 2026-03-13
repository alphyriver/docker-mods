# Docker Mod: Claude Code for code-server

Installs the [Claude Code](https://claude.ai/code) CLI into
[linuxserver/code-server](https://docs.linuxserver.io/images/docker-code-server/) containers.

## Usage

| Variable | Required | Description |
| --- | --- | --- |
| `DOCKER_MODS` | Yes | Set to `<registry>/docker-mods:vscode-claude-code` |
| `ANTHROPIC_API_KEY` | Yes | Your Anthropic API key (`sk-ant-...`) |
| `DISABLE_AUTOUPDATER` | No | Set to `1` to disable Claude Code's built-in updater |

## Docker Compose

```yaml
services:
  code-server:
    image: lscr.io/linuxserver/code-server:latest
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
      - DOCKER_MODS=<your-registry>/docker-mods:vscode-claude-code
      - ANTHROPIC_API_KEY=sk-ant-your-key-here
      - DISABLE_AUTOUPDATER=1
    volumes:
      - ./config:/config
    ports:
      - 8443:8443
    restart: unless-stopped
```

## Notes

- Claude Code is installed to `/usr/local/bin/claude` (no PATH setup required).
- The binary is baked into the mod image at build time — no internet access required at container startup.
- Supports `linux/amd64` and `linux/arm64`.
- Requires glibc 2.30+ (Ubuntu Noble ships with 2.39).
