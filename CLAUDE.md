# CLAUDE.md — Docker Mods Repository

## Project Overview

This repository mirrors the structure of [linuxserver/docker-mods](https://github.com/linuxserver/docker-mods). Each **git branch** contains one self-contained Docker mod. The `main` branch holds only shared documentation and configuration.

Current mods in development:
| Branch | Target Image | Description |
|--------|-------------|-------------|
| `vscode-claude-code` | `linuxserver/code-server` | Installs Claude Code CLI into the vscode-server container |

---

## Branch & Workflow Conventions

### Branch Strategy

```
main                  ← documentation + shared CI config only
└── vscode-claude-code ← mod branch (one branch per mod)
    └── feat/...       ← short-lived feature branches off the mod branch
```

**Rules:**
- Never commit code directly to a mod branch. Always branch off it (`feat/`, `fix/`, `chore/`), commit, then merge back with a merge commit (not squash).
- Never commit code to `main`; it receives only documentation and CI skeleton changes.
- Mod branches must remain independently buildable and deployable.

### Commit Message Format

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <short description>

[optional body]

[optional footer]
```

Types: `feat`, `fix`, `chore`, `docs`, `ci`, `refactor`, `test`
Scope: the mod branch name or component (e.g., `vscode-claude-code`, `ci`)

Examples:
```
feat(vscode-claude-code): add s6 init script to install claude-code npm package
ci(vscode-claude-code): add forgejo workflow for build and push
fix(vscode-claude-code): handle arm64 architecture in install script
```

---

## Development Workflow

Every change follows this sequence — no exceptions:

1. **Plan** — outline approach, identify unknowns, consider edge cases
2. **Design** — determine file structure, s6 service type, env vars, dependencies
3. **Implement** — write code on a feature branch
4. **Test** — validate locally with `docker build` and `docker run`, then CI

### Starting a Feature

```bash
git checkout vscode-claude-code   # or whichever mod branch
git pull origin vscode-claude-code
git checkout -b feat/my-feature
# ... implement ...
git add <specific files>
git commit -m "feat(vscode-claude-code): description"
git checkout vscode-claude-code
git merge --no-ff feat/my-feature
git branch -d feat/my-feature
```

---

## Mod File Structure (per branch)

Each mod branch must contain exactly this layout:

```
root/
└── etc/
    └── s6-overlay/
        └── s6-rc.d/
            └── init-mod-<modname>/
                ├── type          # "oneshot" or "longrun"
                ├── run           # executable init script
                ├── up            # absolute path to run (oneshot only)
                └── dependencies.d/
                    └── init-mods # or init-mods-package-install
Dockerfile            # FROM scratch + COPY root/ /
README.md             # usage docs for this mod
.gitattributes
.dockerignore
.forgejo/
└── workflows/
    └── build.yml     # Forgejo CI pipeline
```

### Dockerfile Patterns

**Simple (overlay files only):**

```dockerfile
# syntax=docker/dockerfile:1
FROM scratch
LABEL maintainer="your-handle"
COPY root/ /
```

**Multi-stage (download or compile during build):**

```dockerfile
# syntax=docker/dockerfile:1
FROM --platform=${BUILDPLATFORM} alpine:3.20 AS downloader
ARG TARGETPLATFORM
RUN # ... download binary for ${TARGETPLATFORM} ...
RUN cp /path/to/binary /root-layer/usr/local/bin/tool

FROM scratch
LABEL maintainer="your-handle"
COPY root/ /
COPY --from=downloader /root-layer/ /
```

Use multi-stage when the mod needs to download binaries or compile assets at build time. The final image is always `FROM scratch` — a single layer.

---

## S6-Overlay Patterns

### Oneshot (initialization, runs once at boot)

`root/etc/s6-overlay/s6-rc.d/init-mod-<name>/type`:
```
oneshot
```

`root/etc/s6-overlay/s6-rc.d/init-mod-<name>/up`:
```
/etc/s6-overlay/s6-rc.d/init-mod-<name>/run
```

`root/etc/s6-overlay/s6-rc.d/init-mod-<name>/run` (executable `chmod +x`):
```bash
#!/usr/bin/env bash
# mod init logic here
```

> **Note:** Use `#!/usr/bin/env bash` for oneshot init scripts. Use `#!/usr/bin/with-contenv bash` only for longrun services that need the container environment injected.

`root/etc/s6-overlay/s6-rc.d/init-mod-<name>/dependencies.d/init-mods`:
```
(empty file)
```

### Dependency on package install step

Replace `init-mods` dependency with `init-mods-package-install` when the mod needs packages pre-installed.

---

## Forgejo CI/CD Workflow

File: `.forgejo/workflows/build.yml` on each mod branch.

The pipeline must:
1. Trigger on push to the mod branch and on pull requests targeting it
2. Build the Docker image (multi-arch: `linux/amd64`, `linux/arm64`)
3. Push to the configured container registry on merge to mod branch
4. Run a smoke test (`docker run --rm` with relevant env vars)

### Required Forgejo Secrets

| Secret | Purpose |
|--------|---------|
| `REGISTRY_URL` | Container registry host |
| `REGISTRY_USER` | Registry username |
| `REGISTRY_TOKEN` | Registry password/token |

---

## Quality Standards

- **No hardcoded credentials** — all secrets via environment variables or Forgejo secrets
- **No root-owned files** — respect the linuxserver PUID/PGID model
- **Multi-arch** — every mod must support `linux/amd64` and `linux/arm64`
- **Idempotent init scripts** — scripts must be safe to run more than once
- **No side effects on other mods** — do not modify system-level files outside the mod's declared scope
- **Script headers** — oneshot `run` scripts use `#!/usr/bin/env bash`; longrun services use `#!/usr/bin/with-contenv bash`
- **Executable bits** — all `run` and `up` files must have `chmod +x` before commit; verify with `git ls-files --stage`

---

## Testing Checklist (before merging a feature branch)

- [ ] `docker build -t test-mod .` succeeds with no warnings
- [ ] Container starts without errors (`docker run --rm -e DOCKER_MODS=... ...`)
- [ ] Mod functionality works end-to-end
- [ ] Mod does not break container when disabled (env var removed)
- [ ] Both amd64 and arm64 builds pass
- [ ] Forgejo pipeline is green

---

## Naming Conventions

| Thing | Convention | Example |
|-------|-----------|---------|
| Mod branch | `<image>-<function>` | `vscode-claude-code` |
| Feature branch | `feat/<short-desc>` | `feat/add-s6-init` |
| s6 service dir | `init-mod-<modname>` | `init-mod-claude-code` |
| Docker image tag | `<registry>/<repo>:<branch>` | `ghcr.io/user/docker-mods:vscode-claude-code` |
| Env var prefix | `CLAUDE_CODE_*` (mod-specific) | `CLAUDE_CODE_VERSION` |
