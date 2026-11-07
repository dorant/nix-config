# Image for the containerised Kiro CLI.
#
# Steering rules are NOT baked in: they are mounted read-only at runtime from
# the nix-config flake (see home/modules/agents), so editing a rule does not
# require an image rebuild and the same rules reach every agent.
#
# The binaries come from the extracted release tarball vendored at
# kirocli-<version>/ next to this file. 2.28.0 is BUILD_HASH
# <fill-from-2.28.0-release>, target
# x86_64-unknown-linux-gnu (so this image is amd64-only).
#
# Build:
#   docker build -t kiro-cli:latest --build-arg KIRO_VERSION=2.28.0 \
#     containers/kiro-cli/
#
# One-time volume setup (the image runs as uid 1000):
#   docker volume create kiro-config
#   docker run --rm -v kiro-config:/data alpine sh -c "chown -R 1000:1000 /data"
#
# Run via the `kiro-cli` wrapper that home-manager installs, not by hand.

FROM debian:bookworm-slim

ARG KIRO_VERSION=2.28.0

# A Debian base rather than a Nix-built image on purpose: an agent installs and
# runs things that were not declared up front, which needs the FHS layout
# (/usr/bin/env, the glibc loader, /etc/ssl/certs) that a store-only image
# lacks.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    bash git grep file curl build-essential strace \
    jq wget shellcheck \
    ca-certificates \
    && \
    rm -rf /var/lib/apt/lists/*

# kubectl, for working against the kind cluster that runs on the host. The
# cluster is reached over the Kubernetes API with a mounted kubeconfig, which
# needs no access to the host Docker socket.
ARG KUBECTL_VERSION=v1.31.4
RUN curl -fsSLo /usr/local/bin/kubectl \
      "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    && chmod 0755 /usr/local/bin/kubectl \
    && kubectl version --client

# kind, for the kiro-fi wrapper's build-and-load chain: `docker build` the
# operator image and `kind load docker-image` it onto the cluster nodes. These
# need the host Docker socket, which only the kiro-fi and claude-fi wrappers
# mount; the everyday kiro-cli wrapper leaves this binary unused.
ARG KIND_VERSION=v0.24.0
RUN curl -fsSLo /usr/local/bin/kind \
      "https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-linux-amd64" \
    && chmod 0755 /usr/local/bin/kind \
    && kind version

# Docker CLI (client only, no engine). The kiro-fi and claude-fi wrappers
# mount the host Docker socket; this is the client that talks to it, and the
# binary kind shells out to as its node provider. The static client tarball
# rather than apt's docker.io, which would pull the whole daemon the container
# must not run.
ARG DOCKER_CLI_VERSION=27.3.1
RUN curl -fsSL "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_CLI_VERSION}.tgz" \
      | tar -xz -C /tmp \
    && mv /tmp/docker/docker /usr/local/bin/docker \
    && rm -rf /tmp/docker \
    && chmod 0755 /usr/local/bin/docker \
    && docker --version

# Buildx, as a Docker CLI plugin. The static docker client tarball above ships
# no plugins, and Docker 27 routes `docker build` through buildx, so without
# this the build subcommand fails even with the host socket mounted: buildx is
# a client-side plugin that must exist in the container, independent of which
# daemon the socket reaches. Installed into the CLI-plugins search path.
ARG BUILDX_VERSION=v0.17.1
RUN mkdir -p /usr/local/libexec/docker/cli-plugins \
    && curl -fsSLo /usr/local/libexec/docker/cli-plugins/docker-buildx \
      "https://github.com/docker/buildx/releases/download/${BUILDX_VERSION}/buildx-${BUILDX_VERSION}.linux-amd64" \
    && chmod 0755 /usr/local/libexec/docker/cli-plugins/docker-buildx \
    && docker buildx version

# Go, for building and testing the operator in-container. Pinned only as a
# bootstrap: projects that set GOTOOLCHAIN from a .go-version (as
# valkey-operator does) make this Go fetch the matching toolchain itself, so
# the pin here only needs to be recent enough to honour that. The official
# tarball rather than Debian's golang, which lags. gofmt ships inside it.
ARG GO_VERSION=1.26.2
RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" \
      | tar -C /usr/local -xz \
    && /usr/local/go/bin/go version

# Helm, for the local chart render/lint the release and review skills run. No
# cluster mutation: the allowlist only grants template/lint/version.
ARG HELM_VERSION=v3.16.3
RUN curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" \
      | tar -xz -C /tmp \
    && mv /tmp/linux-amd64/helm /usr/local/bin/helm \
    && rm -rf /tmp/linux-amd64 \
    && chmod 0755 /usr/local/bin/helm \
    && helm version

# GitHub CLI, for the read-only PR and issue lookups the issue/review skills
# depend on. The allowlist grants only read verbs (pr view, pr diff, search).
ARG GH_VERSION=2.63.2
RUN curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz" \
      | tar -xz -C /tmp \
    && mv "/tmp/gh_${GH_VERSION}_linux_amd64/bin/gh" /usr/local/bin/gh \
    && rm -rf "/tmp/gh_${GH_VERSION}_linux_amd64" \
    && chmod 0755 /usr/local/bin/gh \
    && gh --version

# Go toolchain and user-level Go binaries on PATH for every shell.
ENV PATH="/home/user/.local/bin:/usr/local/go/bin:/home/user/go/bin:${PATH}"

# uid 1000 to match the host user, so files written into the mounted project
# are owned correctly. Note this means the container user is not a security
# boundary against the host user's own files; the short mount list is.
RUN useradd -m -u 1000 user

COPY --chown=user:user kirocli-${KIRO_VERSION}/bin/kiro-cli /home/user/.local/bin/
COPY --chown=user:user kirocli-${KIRO_VERSION}/bin/kiro-cli-chat /home/user/.local/bin/
COPY --chown=user:user kirocli-${KIRO_VERSION}/bin/kiro-cli-term /home/user/.local/bin/

# Mount points for the config the wrapper supplies, created up front so the
# read-only mounts land on an existing path owned by the right user.
RUN mkdir -p /home/user/.kiro/steering /home/user/.kiro/skills /home/user/.kiro/agents \
    /home/user/.kiro/sessions/cli \
    && chown -R user:user /home/user/.kiro

USER user
WORKDIR /home/user

ENTRYPOINT ["kiro-cli", "--classic"]
