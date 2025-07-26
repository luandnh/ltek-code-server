# Base Image: A full TeX Live installation
FROM texlive/texlive:latest-full

# --- Build-time Arguments ---
# Set versions for all installed tools to be easily configurable
ARG BUILD_DATE
ARG VERSION="2.0"
ARG CODE_RELEASE="4.102.2"
ARG GO_VERSION="1.24.5"
ARG NODE_VERSION="20.19.4"
ARG PYTHON_VERSION="3.12.4"
ARG USERNAME=ltek

# --- Metadata ---
LABEL build_version="Combined TeXLive+code-server v${VERSION} Build-date:${BUILD_DATE}"
LABEL maintainer="LuanDNH <luandnh98@gmail.com>"

# --- Environment Configuration ---
# Set non-interactive mode for package installers
ARG DEBIAN_FRONTEND="noninteractive"
# Define home directory for the new user
ENV HOME="/home/${USERNAME}"
# Configure paths for pyenv, Go, and NVM
ENV PYENV_ROOT="${HOME}/.pyenv"
ENV GOPATH="${HOME}/go"
ENV NVM_DIR="${HOME}/.nvm"
ENV PATH="${PYENV_ROOT}/shims:${PYENV_ROOT}/bin:${NVM_DIR}/versions/node/v${NODE_VERSION}/bin:/usr/local/go/bin:${GOPATH}/bin:${PATH}"

# --- Installation Steps ---

# Step 1: Install System Dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        sudo \
        git \
        curl \
        nano \
        zsh \
        make \
        build-essential \
        libssl-dev \
        zlib1g-dev \
        libbz2-dev \
        libreadline-dev \
        libsqlite3-dev \
        wget \
        llvm \
        libncurses5-dev \
        xz-utils \
        tk-dev \
        libxml2-dev \
        libxmlsec1-dev \
        libffi-dev \
        liblzma-dev

# Step 2: Create non-root user with sudo privileges
RUN useradd -m -s /bin/zsh -G sudo ${USERNAME} && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Step 3: Install Golang
RUN curl -o go.tar.gz -L "https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz" && \
    tar -C /usr/local -xzf go.tar.gz && \
    rm go.tar.gz

# Step 4: Install code-server
RUN mkdir -p /app/code-server && \
    curl -o /tmp/code-server.tar.gz -L \
    "https://github.com/coder/code-server/releases/download/v${CODE_RELEASE}/code-server-${CODE_RELEASE}-linux-amd64.tar.gz" && \
    tar xf /tmp/code-server.tar.gz -C /app/code-server --strip-components=1

# The following steps are run as the new user to ensure correct ownership and paths
# Step 5: Install Oh My Zsh
RUN sudo -u ${USERNAME} sh -c 'CHSH=no RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'

# Step 6: Install NVM and Node.js
RUN sudo -u ${USERNAME} bash -c "mkdir -p ${NVM_DIR} && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash && \
    . ${NVM_DIR}/nvm.sh && \
    nvm install ${NODE_VERSION} && \
    nvm alias default ${NODE_VERSION} && \
    nvm use default"

# Step 7: Install Pyenv and Python
RUN sudo -u ${USERNAME} bash -c "git clone https://github.com/pyenv/pyenv.git ${PYENV_ROOT} && \
    ${PYENV_ROOT}/bin/pyenv install ${PYTHON_VERSION} && \
    ${PYENV_ROOT}/bin/pyenv global ${PYTHON_VERSION}"

# Step 8: Final Shell Configuration
RUN sudo -u ${USERNAME} tee -a ${HOME}/.zshrc > /dev/null <<'EOF'

# Shell Configuration
export ZSH_THEME="agnoster"

# Pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
EOF

# Step 9: System Cleanup
RUN apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# --- Runtime Configuration ---
# Switch to the non-root user
USER ${USERNAME}
# Set the working directory
WORKDIR /workspaces

# Expose the code-server port
EXPOSE 8443

# Define volumes for persistent data and configuration
# The home directory /home/ltek will persist user-specific configs (zsh, pyenv, nvm)
# /workspaces is the default folder opened in code-server
# /data and /config are extra persistent directories for your projects
VOLUME ["/config", "/data", "/workspaces"]

# Default command to start the container
# Runs as the 'ltek' user
CMD ["/app/code-server/bin/code-server", "--bind-addr", "0.0.0.0:8443", "--auth", "password", "/workspaces"]
