# Docker Mod: Claude Code for code-server

A [Docker mod](https://linuxserver.io/blog/2019-09-14-customizing-our-containers) that installs
the [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) CLI into
[linuxserver/code-server](https://docs.linuxserver.io/images/docker-code-server/) containers.

Claude Code is Anthropic's agentic coding tool that runs in your terminal alongside your editor.
This mod makes it available inside your self-hosted code-server environment with zero manual setup.

## Quick Start

Add the mod to your code-server container via the `DOCKER_MODS` environment variable:

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
    volumes:
      - ./config:/config
    ports:
      - 8443:8443
    restart: unless-stopped
```

Once the container starts, open a terminal in code-server and run:

```bash
claude
```

## Environment Variables

### Required

| Variable | Description |
| --- | --- |
| `DOCKER_MODS` | Set to `<registry>/docker-mods:vscode-claude-code` to enable this mod |
| `ANTHROPIC_API_KEY` | Your Anthropic API key (starts with `sk-ant-...`). Get one at [console.anthropic.com](https://console.anthropic.com/) |

### Optional

| Variable | Default | Description |
| --- | --- | --- |
| `DISABLE_AUTOUPDATER` | _(unset)_ | Set to `1` to prevent Claude Code from checking for updates at runtime. Recommended since the binary version is managed by the mod image |
| `PUID` | `1000` | User ID for the `abc` user inside the container |
| `PGID` | `1000` | Group ID for the `abc` user inside the container |
| `TZ` | `Etc/UTC` | Container timezone |

## How It Works

### Build time

The mod uses a multi-stage Docker build:

1. An Alpine-based builder stage downloads the Claude Code native binary using the
   [official installer](https://docs.anthropic.com/en/docs/claude-code/getting-started)
2. The binary is copied to `/usr/local/bin/claude` in a `FROM scratch` final layer
3. The s6-overlay init scripts are included alongside the binary

This means the binary is **baked into the mod image** — no network access is required at
container startup.

### Container boot

When the container starts with `DOCKER_MODS` pointing to this image:

```text
s6 boot
  → init-mods                    LinuxServer base init
    → init-mod-claude-code       This mod's init script
      → Verify claude binary     Confirms /usr/local/bin/claude exists
      → Check ANTHROPIC_API_KEY  Warns in logs if not set
      → init-mods-end            All mods finished
        → code-server starts
```

The init script output is visible in `docker logs`:

```text
**** Claude Code mod: initializing ****
**** Claude Code installed: 2.x.x ****
**** ANTHROPIC_API_KEY is configured ****
**** Claude Code mod: done ****
```

## Architecture Support

| Platform | Status |
| --- | --- |
| `linux/amd64` | Supported |

The mod requires **glibc 2.30+**. The linuxserver/code-server image is based on Ubuntu Noble
(24.04) which ships with glibc 2.39.

## Building From Source

### Standard build (latest Claude Code)

```bash
docker buildx build \
  --platform linux/amd64 \
  -t <your-registry>/docker-mods:vscode-claude-code \
  --push \
  .
```

### Single-platform build for local testing

```bash
docker buildx build \
  --platform linux/amd64 \
  --load \
  -t docker-mods:vscode-claude-code \
  .
```

### Verifying the build

Extract the binary from the mod image and run it against the base image:

```bash
MOD_ID=$(docker create docker-mods:vscode-claude-code)
docker cp "${MOD_ID}:/usr/local/bin/claude" ./claude-test
docker rm "${MOD_ID}"

docker run --rm \
  -v "${PWD}/claude-test:/usr/local/bin/claude:ro" \
  ghcr.io/linuxserver/baseimage-ubuntu:noble \
  /usr/local/bin/claude --version

rm ./claude-test
```

## Combining With Other Mods

Use the pipe `|` separator to load multiple mods:

```yaml
environment:
  - DOCKER_MODS=<registry>/docker-mods:vscode-claude-code|linuxserver/mods:universal-package-install
  - INSTALL_PACKAGES=git|ripgrep
```

Mods are loaded in order and their init scripts respect the s6 dependency chain.

## File Structure

```text
.
├── Dockerfile                                          # Multi-stage build
├── README.md                                           # This file
├── .dockerignore
├── .gitattributes
├── .forgejo/
│   └── workflows/
│       └── build.yml                                   # CI pipeline
└── root/
    └── etc/
        └── s6-overlay/
            └── s6-rc.d/
                ├── init-mod-claude-code/
                │   ├── type                            # oneshot
                │   ├── run                             # Init script
                │   ├── up                              # Path to run
                │   └── dependencies.d/
                │       └── init-mods                   # Dependency marker
                └── user/
                    └── contents.d/
                        └── init-mod-claude-code        # Service registration
```

## Troubleshooting

### `claude: command not found`

The binary is installed at `/usr/local/bin/claude`. If it's missing, the init script will log
an error and the container will still start (code-server itself is unaffected). Check
`docker logs` for the init output.

### `ANTHROPIC_API_KEY is not set` warning

The mod installs the binary but does not provide an API key. You must pass your own key via
the `ANTHROPIC_API_KEY` environment variable. The warning is informational — the container
will start normally, but `claude` commands will fail until a key is provided.

### Mod not loading

Verify that:

1. The `DOCKER_MODS` value exactly matches the image tag (including registry prefix)
2. The container can reach the registry to pull the mod image
3. The mod image was built for the correct platform (`linux/amd64` or `linux/arm64`)

Check `docker logs` for lines containing `[mod-init]` to see the mod loading sequence.

## Related

- [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code/overview)
- [LinuxServer code-server documentation](https://docs.linuxserver.io/images/docker-code-server/)
- [LinuxServer Docker mods guide](https://linuxserver.io/blog/2019-09-14-customizing-our-containers)
- [s6-overlay documentation](https://github.com/just-containers/s6-overlay)
