FROM mcr.microsoft.com/vscode/devcontainers/base:ubuntu-24.04

ARG USERNAME=vscode

RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
    && mkdir /commandhistory \
    && touch /commandhistory/.bash_history \
    && chown -R $USERNAME /commandhistory \
    && echo "$SNIPPET" >> "/home/$USERNAME/.bashrc"

RUN apt-get update && apt-get install -y --no-install-recommends \
    sshpass \
    && rm -rf /var/lib/apt/lists/*
