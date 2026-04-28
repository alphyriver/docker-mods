# docker-mods

Custom [Docker mods](https://linuxserver.io/blog/2019-09-14-customizing-our-containers) for
[LinuxServer.io](https://www.linuxserver.io/) containers. Each mod lives on its own branch and
is distributed as a single-layer OCI image that gets extracted into a container at boot.

## Available Mods

| Mod | Branch | Base Image | Description |
| --- | --- | --- | --- |
| Claude Code | `vscode-claude-code` | `linuxserver/code-server` | Installs the Claude Code CLI |

## How It Works

```text
┌─────────────────────────────────────────────────────────┐
│  Container Boot                                                   │
│                                                                   │
│  1. DOCKER_MODS env var detected                                  │
│  2. Mod image pulled from registry                                │
│  3. Single layer extracted into container filesystem              │
│  4. s6-overlay runs mod init scripts                              │
│  5. Normal container startup continues                            │
│                                                                   │
└─────────────────────────────────────────────────────────┘
```

Docker mods are OCI images built `FROM scratch` containing only the files to overlay onto the
container. They are downloaded and extracted **before** any container init logic runs.
The [s6-overlay](https://github.com/just-containers/s6-overlay) init system then executes the
mod's scripts as part of the boot sequence.

## Quick Start

Add the `DOCKER_MODS` environment variable to your container, pointing to the mod image tag.
Multiple mods are separated with `|`.

```yaml
services:
  code-server:
    image: lscr.io/linuxserver/code-server:latest
    environment:
      - DOCKER_MODS=<registry>/docker-mods:vscode-claude-code
```

Each mod branch has its own README with detailed usage instructions and required environment variables.

## Repository Architecture

### Branch-per-mod strategy

```text
main                          Documentation, repo-level config
├── vscode-claude-code        Mod: Claude Code for code-server
├── <image>-<mod-name>        Mod: future mods follow this pattern
│   └── feat/<description>    Short-lived feature branches
```

- **`main`** contains only documentation and shared configuration. No mod code.
- **Mod branches** (`<base-image>-<mod-name>`) are independently buildable and deployable.
- **Feature branches** branch off a mod branch, receive commits, then merge back with `--no-ff`.

### File structure (per mod branch)

Every mod branch follows this layout:

```text
.
├── Dockerfile                          # Multi-stage or simple FROM scratch
├── README.md                           # Mod-specific usage documentation
├── .dockerignore
├── .gitattributes
├── .forgejo/
│   └── workflows/
│       └── build.yml                   # CI: build, push, smoke test
└── root/
    └── etc/
        └── s6-overlay/
            └── s6-rc.d/
                ├── init-mod-<name>/           # Mod init service
                │   ├── type                   # "oneshot" or "longrun"
                │   ├── run                    # Init script (chmod +x)
                │   ├── up                     # Path to run script
                │   └── dependencies.d/
                │       └── init-mods          # Dependency marker (empty)
                └── user/
                    └── contents.d/
                        └── init-mod-<name>    # Service registration (empty)
```

### Build pipeline

Each mod branch has a Forgejo Actions workflow that:

1. Triggers on push and pull request to the mod branch
2. Builds a multi-arch image (`linux/amd64` + `linux/arm64`) using Docker Buildx + QEMU
3. Pushes to the container registry on direct push (not on PRs)
4. Runs architecture-specific smoke tests to verify the mod works

### s6-overlay init system

Mods hook into the container's [s6-overlay v3](https://github.com/just-containers/s6-overlay)
init system. Two service types are supported:

| Type | Use case | Runs |
| --- | --- | --- |
| `oneshot` | Initialization, setup, verification | Once at boot, then exits |
| `longrun` | Background daemons, persistent services | Continuously in foreground |

Services declare dependencies via empty files in `dependencies.d/`. The typical chain:

```text
s6 boot
  → init-mods                          Base LinuxServer init
    → init-mods-package-install        Package queue processing
      → init-mod-<your-mod>            Your mod's init script
        → init-mods-end                All mods finished
          → container services start
```

### Dockerfile patterns

**Simple (overlay files only):**

```dockerfile
FROM scratch
COPY root/ /
```

**Multi-stage (download or compile during build):**

```dockerfile
FROM alpine:3.20 AS downloader
RUN curl -fsSL ... -o /root-layer/usr/local/bin/tool

FROM scratch
COPY root/ /
COPY --from=downloader /root-layer/ /
```

The final image is always `FROM scratch` — a single layer containing only the files to overlay.

## Development

See [CLAUDE.md](CLAUDE.md) for detailed conventions covering:

- Branch and merge strategy
- Commit message format (Conventional Commits)
- Development workflow (Plan → Design → Implement → Test)
- s6-overlay script patterns and examples
- Forgejo CI/CD configuration
- Quality standards and testing checklist
- Naming conventions

### Creating a new mod

1. Create a new branch from `main` named `<base-image>-<mod-name>`
2. Copy the file structure from an existing mod branch
3. Implement your s6 init script in `root/etc/s6-overlay/s6-rc.d/init-mod-<name>/run`
4. Write a `Dockerfile` (simple or multi-stage as needed)
5. Add a Forgejo workflow in `.forgejo/workflows/build.yml`
6. Update the mod table in this README on `main`

### Requirements

- Docker with Buildx (multi-arch support)
- QEMU user-static (for cross-platform builds on x86 hosts)
- Forgejo instance with Actions enabled and registry secrets configured

## License

See [LICENSE](LICENSE).
