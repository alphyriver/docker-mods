# Docker Mod: Java (Eclipse Temurin) for code-server

A [Docker mod](https://linuxserver.io/blog/2019-09-14-customizing-our-containers) that installs
the latest [Eclipse Temurin](https://adoptium.net/) LTS JDK into
[linuxserver/code-server](https://docs.linuxserver.io/images/docker-code-server/) containers.

Eclipse Temurin is the free, open-source, production-quality OpenJDK distribution from the
[Eclipse Adoptium](https://adoptium.net/) project. This mod bakes the full JDK (not just JRE)
into the mod image — no network access is required at container startup.

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
      - DOCKER_MODS=ghcr.io/alphyriver/docker-mods:code-server-java
    volumes:
      - ./config:/config
    ports:
      - 8443:8443
    restart: unless-stopped
```

Once the container starts, open a terminal in code-server and run:

```bash
java -version
javac -version
```

## Environment Variables

| Variable | Description |
| --- | --- |
| `DOCKER_MODS` | Set to `ghcr.io/alphyriver/docker-mods:code-server-java` to enable this mod |

## What the Mod Provides

- **JDK binaries** installed to `/usr/local/lib/jdk/` (full JDK, not JRE)
- **Symlinks** created in `/usr/local/bin/` for: `java`, `javac`, `jar`, `jshell`, `jlink`, `jpackage`, `keytool`
- **`JAVA_HOME`** set to `/usr/local/lib/jdk` and exported via `/etc/profile.d/java-mod.sh`
- **`JAVA_HOME`** also written to the s6 container environment so the code-server process inherits it
- **VS Code Java extensions** (e.g. `redhat.java`) will auto-detect the JDK via `JAVA_HOME`. Install extensions yourself through the marketplace — this mod does not manage extensions.

## LTS Version

The default LTS version is **Java 21** (Eclipse Temurin 21). This is a build-time `ARG`:

```bash
docker buildx build --build-arg JAVA_LTS_VERSION=21 .
```

To upgrade to a newer LTS (e.g. Java 25), change `JAVA_LTS_VERSION` in the Dockerfile `ARG` line
and the CI workflow `check-release` step.

## How It Works

### Build time

The mod uses a multi-stage Docker build:

1. An Ubuntu Noble builder stage fetches the latest Temurin GA release for the given LTS version
   using the [Adoptium API](https://adoptium.net/temurin/releases/)
2. The JDK tarball is extracted to `/root-layer/usr/local/lib/jdk/`
3. A version file is written to `/root-layer/usr/local/lib/jdk/.mod-version`
4. The final `FROM scratch` layer merges the s6 init scripts and the JDK into one thin image layer

### Container boot

When the container starts with `DOCKER_MODS` pointing to this image:

```text
s6 boot
  → init-mods                    LinuxServer base init
    → init-mod-java              This mod's init script
      → Verify java binary       Confirms /usr/local/lib/jdk/bin/java exists
      → Symlink binaries         Creates /usr/local/bin/java etc.
      → Write profile.d          Exports JAVA_HOME for login shells
      → Write s6 env             Makes JAVA_HOME available to code-server process
      → init-mods-end            All mods finished
        → code-server starts
```

## File Structure

```
root/
└── etc/
    └── s6-overlay/
        └── s6-rc.d/
            ├── init-mod-java/
            │   ├── type              # oneshot
            │   ├── up                # s6 up script
            │   ├── run               # init script (chmod +x)
            │   └── dependencies.d/
            │       └── init-mods     # empty marker
            └── user/
                └── contents.d/
                    └── init-mod-java # empty marker
```

## Building Locally

```bash
docker buildx build --platform linux/amd64 --load -t docker-mods:code-server-java .
docker run --rm --entrypoint /usr/local/lib/jdk/bin/java docker-mods:code-server-java -version
```

Expected output: `openjdk version "21.x.x" ...` from Eclipse Temurin.

## Troubleshooting

**`java: command not found` in terminal**

The symlinks are set up by the s6 init script at container start. Ensure:
- `DOCKER_MODS` is correctly set in your container environment
- The container logs show `**** Java mod: done ****` during startup

**VS Code Java extension not detecting JDK**

The `redhat.java` extension reads `JAVA_HOME`. The mod sets this in the s6 container environment
so code-server inherits it. If the extension still doesn't detect it:
1. Open VS Code settings and search for `java.home`
2. Set it to `/usr/local/lib/jdk`

**Checking installed version**

```bash
cat /usr/local/lib/jdk/.mod-version
java -version
```
