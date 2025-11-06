FROM ocaml/opam:ubuntu-24.04-ocaml-5.2

USER root

RUN \
  rm -rf /var/lib/apt/lists/* && \
  apt-get update

RUN \
  apt update && \
  apt install -y git build-essential cmake ninja-build pkg-config libtool autoconf automake gettext curl && \
  git clone --single-branch -b stable https://github.com/neovim/neovim.git && \
  cd neovim && \
  make CMAKE_BUILD_TYPE=RelWithDebInfo && \
  make install


ARG ARCH=arm64
RUN \
  VERSION=0.54.2 && \
  PLATFORM=linux && \
  FILENAME=lazygit_${VERSION}_${PLATFORM}_${ARCH}.tar.gz && \
  apt update && \
  apt install -y wget && \
  cd /usr/local/bin && \
  mkdir tmp-lazygit && \
  cd tmp-lazygit && \
  wget https://github.com/jesseduffield/lazygit/releases/download/v${VERSION}/${FILENAME} && \
  tar xzf ${FILENAME} && \
  rm ${FILENAME} && \
  cd .. && \
  mv tmp-lazygit/lazygit . && \
  rm -rf tmp-lazygit && \
  lazygit --version

RUN \
  apt update && apt install -y \
    build-essential \
    ca-certificates \
    git \
    inotify-tools \
    libffi-dev \
    libgmp-dev \
    libssl-dev \
    m4 \
    pkg-config \
    ripgrep \
    wget \
    zlib1g-dev \
    && \
  rm -rf /var/lib/apt/lists/*

RUN chown -R opam:opam /home/opam/.local
RUN mkdir -p /home/opam/app && chown opam:opam /home/opam/app

USER opam

RUN \
  opam-2.4 update && opam-2.4 install -y \
    ocamlformat.0.27.0 \
    ocaml-lsp-server

ARG TAG
COPY ${TAG}.opam /home/opam/app/${TAG}.opam
RUN opam-2.4 install /home/opam/app --deps-only && rm -f /home/opam/app/${TAG}.opam

RUN mkdir -p /home/opam/app/_build && chown opam:opam /home/opam/app/_build
RUN mkdir -p /home/opam/.config && chown opam:opam /home/opam/.config
ENV SHELL=/bin/bash
COPY --chmod=0755 entrypoint.sh /home/opam/entrypoint.sh
ENTRYPOINT ["/home/opam/entrypoint.sh"]
