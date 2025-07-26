# Base Image: A full TeX Live installation
FROM texlive/texlive:latest-full

# --- Build-time Arguments ---
# Set versions for all installed tools to be easily configurable
ARG BUILD_DATE
ARG VERSION="2.0"
ARG CODE_RELEASE="4.102.2"
ARG GO_VERSION="1.22.5"
ARG NODE_VERSION="20.15.1"
ARG PYTHON_VERSION="3.12.4"

# --- Metadata ---
LABEL build_version="Combined TeXLive+code-server v${VERSION} Build-date:${BUILD_DATE}"
LABEL maintainer="LuanDNH <luandnh98@gmail.com>"

# --- Environment Configuration ---
# Set non-interactive mode for package installers
ARG DEBIAN_FRONTEND="noninteractive"
# Define home directory for user configuration and tools
ENV HOME="/config"
# Configure paths for pyenv, Go, and NVM
ENV PYENV_ROOT="${HOME}/.pyenv"
ENV GOPATH="${HOME}/go"
ENV PATH="${PYENV_ROOT}/shims:${PYENV_ROOT}/bin:/usr/local/go/bin:${GOPATH}/bin:${PATH}"

# --- Main Installation Block ---
# Combine all installation steps into a single RUN command to minimize image layers
RUN \
    # Step 1/7: Install System Dependencies
    echo "====> Step 1/7: Installing system dependencies..." && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    # Dependencies for TeXLive, code-server, and version managers
    git \
    curl \
    sudo \
    nano \
    zsh \
    # Python build dependencies for pyenv
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

RUN \
    # Step 2/7: Install Golang
    echo "====> Step 2/7: Installing Golang v${GO_VERSION}..." && \
    curl -o go.tar.gz -L "https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz" && \
    tar -C /usr/local -xzf go.tar.gz && \
    rm go.tar.gz && \
    # Create a default Go workspace
    mkdir -p ${GOPATH}/src ${GOPATH}/pkg ${GOPATH}/bin && \
    chmod -R 777 ${GOPATH}

RUN \
    # Step 3/7: Install code-server
    echo "====> Step 3/7: Installing code-server v${CODE_RELEASE}..." && \
    mkdir -p /app/code-server && \
    curl -o /tmp/code-server.tar.gz -L \
    "https://github.com/coder/code-server/releases/download/v${CODE_RELEASE}/code-server-${CODE_RELEASE}-linux-amd64.tar.gz" && \
    tar xf /tmp/code-server.tar.gz -C /app/code-server --strip-components=1 

RUN \
    # Step 4/7: Install Oh My Zsh
    echo "====> Step 4/7: Installing Oh My Zsh..." && \
    # Install non-interactively, don't run zsh or change shell for root during build
    CHSH=no RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

RUN \
    # Step 5/7: Install NVM and Node.js
    echo "====> Step 5/7: Installing NVM and Node.js v${NODE_VERSION}..." && \
    export NVM_DIR="${HOME}/.nvm" && \
    mkdir -p ${NVM_DIR} && \
    # Download and run the NVM install script
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash && \
    # Source NVM and install the specified Node.js version
    . ${NVM_DIR}/nvm.sh && \
    nvm install ${NODE_VERSION} && \
    nvm alias default ${NODE_VERSION} && \
    nvm use default


RUN \
    # Step 6/7: Install Pyenv and Python
    echo "====> Step 6/7: Installing Pyenv and Python v${PYTHON_VERSION}..." && \
    git clone https://github.com/pyenv/pyenv.git ${PYENV_ROOT} && \
    # Install the specified Python version and set it as global default
    ${PYENV_ROOT}/bin/pyenv install ${PYTHON_VERSION} && \
    ${PYENV_ROOT}/bin/pyenv global ${PYTHON_VERSION}


RUN \
    # Step 7/7: System Cleanup
    echo "====> Step 7/7: Cleaning up the system..." && \
    # Configure shell environment for interactive sessions
    echo 'export ZSH_THEME="agnoster"' >> ${HOME}/.zshrc && \
    echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ${HOME}/.zshrc && \
    echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ${HOME}/.zshrc && \
    echo 'eval "$(pyenv init --path)"' >> ${HOME}/.zshrc && \
    echo 'export NVM_DIR="$HOME/.nvm"' >> ${HOME}/.zshrc && \
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm' >> ${HOME}/.zshrc && \
    echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion' >> ${HOME}/.zshrc && \
    # Remove unnecessary packages and clear cache
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# --- Runtime Configuration ---
# Expose the code-server port
EXPOSE 8443

# Define volumes for persistent data and configuration
VOLUME ["/config", "/data"]

# Default command to start the container
# This starts code-server and sets the default shell to zsh if it's launched
# WARNING: --auth none is insecure for public access.
# Use `/data` as the default workspace in code-server.
CMD ["/bin/zsh", "-c", "/app/code-server/bin/code-server --bind-addr 0.0.0.0:8443 --auth password /data"]