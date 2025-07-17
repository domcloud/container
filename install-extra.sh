#!/bin/bash

# NGINX
BUILDER_DIR=/usr/local/lib/nginx-builder; [ ! -d "$BUILDER_DIR" ] && \
git clone https://github.com/domcloud/nginx-builder/ $BUILDER_DIR || git -C $BUILDER_DIR pull
cd $BUILDER_DIR/ && make install DOWNLOAD_V=1.2.0 && make clean && cd /root
ln -fs /usr/local/sbin/nginx /usr/sbin/nginx # nginx compatibility

# Composer
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Scripts
curl -sSLo /usr/local/bin/restart https://raw.githubusercontent.com/domcloud/bridge/main/userkill.sh && chmod 755 /usr/local/bin/restart
curl -sSLo /usr/local/bin/loadenv https://raw.githubusercontent.com/domcloud/bridge/main/userloadenv.sh && chmod 755 /usr/local/bin/loadenv

# Proxyfix
PROXYFIX=proxy-fix-linux-$( [ "$(uname -m)" = "aarch64" ] && echo "arm64" || echo "amd64" )
if ! command -v proxfix &> /dev/null; then
  curl -sSLO https://github.com/domcloud/proxy-fix/releases/download/v0.2.5/$PROXYFIX.tar.gz
  tar -xf $PROXYFIX.tar.gz && mv -f $PROXYFIX /usr/local/bin/proxfix && rm -rf $PROXYFIX*
fi

# Rdproxy
RDPROXY=rdproxy-linux-$( [ "$(uname -m)" = "aarch64" ] && echo "arm64" || echo "amd64" )
if ! command -v rdproxy &> /dev/null; then
  curl -sSLO https://github.com/domcloud/rdproxy/releases/download/v0.3.2/$RDPROXY.tar.gz
  tar -xf $RDPROXY.tar.gz && mv -f $RDPROXY /usr/local/bin/rdproxy && rm -rf $RDPROXY*
fi

# Pathman
PATHMAN_V=0.6.0
if ! command -v pathman &> /dev/null; then
  PATHMAN=pathman-v${PATHMAN_V}-linux-$( [ "$(uname -m)" = "aarch64" ] && echo "arm64" || echo "amd64_v1" )
  curl -sSLO https://github.com/therootcompany/pathman/releases/download/v$PATHMAN_V/$PATHMAN.tar.gz
  tar -xf $PATHMAN.tar.gz && mv -f $PATHMAN /usr/local/bin/pathman && rm -f $PATHMAN.tar.gz
fi

# NVIM for NvChad
NVIM_V=0.11.1
if ! command -v neovim &> /dev/null; then
  NVIM_F=nvim-linux-$( [ "$(uname -m)" = "aarch64" ] && echo "arm64" || echo "x86_64" )
  curl -sSLO https://github.com/neovim/neovim/releases/download/v$NVIM_V/$NVIM_F.tar.gz
  tar -xf $NVIM_F.tar.gz && chown -R root:root $NVIM_F && rsync -a $NVIM_F/ /usr/local/ && rm -rf $NVIM_F*
fi

# Lazygit for NVIM
LAZYGIT_V=0.53.0
if ! command -v lazygit &> /dev/null; then
  LAZYGIT=lazygit_${LAZYGIT_V}_Linux_$( [ "$(uname -m)" = "aarch64" ] && echo "arm64" || echo "x86_64" )
  curl -sSLO https://github.com/jesseduffield/lazygit/releases/download/v$LAZYGIT_V/$LAZYGIT.tar.gz
  tar -xf $LAZYGIT.tar.gz && mv lazygit /usr/local/bin/ && rm -f $LAZYGIT.tar.gz
fi

# Lazydocker
LAZYDOCK_V=0.24.1
if ! command -v lazydocker &> /dev/null; then
  LAZYDOCK=lazydocker_${LAZYDOCK_V}_Linux_$( [ "$(uname -m)" = "aarch64" ] && echo "arm64" || echo "x86_64" )
  curl -sSLO https://github.com/jesseduffield/lazydocker/releases/download/v$LAZYDOCK_V/$LAZYDOCK.tar.gz
  tar -xf $LAZYDOCK.tar.gz && mv lazydocker /usr/local/bin/ && rm -f $LAZYDOCK.tar.gz
fi

# Neofetch (Forked)
curl -sSLo /usr/local/bin/neofetch https://github.com/hykilpikonna/hyfetch/raw/1.99.0/neofetch

# Rdfind
RDFIND=rdfind-1.6.0
curl -sSL https://rdfind.pauldreik.se/$RDFIND.tar.gz | tar -xzf -
cd $RDFIND; ./configure --disable-debug ; make install; cd .. ; rm -rf $RDFIND*
