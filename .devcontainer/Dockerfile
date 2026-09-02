FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
        fluxbox \
        git-lfs \
        libasound2t64 \
        libxcursor1 \
        libpulse0 \
        novnc \
        unzip \
        x11-utils \
        x11vnc \
        websockify \
        xvfb \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /opt/godot-4.3 \
    && curl -fsSL -o /tmp/godot.zip https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip \
    && unzip -q /tmp/godot.zip -d /opt/godot-4.3 \
    && rm /tmp/godot.zip \
    && mkdir -p /home/vscode/.local/share/godot/export_templates/4.3.stable \
    && curl -fsSL -o /tmp/godot-templates.tpz https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz \
    && unzip -q /tmp/godot-templates.tpz -d /tmp/godot-templates \
    && mv /tmp/godot-templates/templates/* /home/vscode/.local/share/godot/export_templates/4.3.stable/ \
    && rm -rf /tmp/godot-templates /tmp/godot-templates.tpz \
    && chown -R vscode:vscode /home/vscode/.local/share/godot \
    && ln -s /opt/godot-4.3/Godot_v4.3-stable_linux.x86_64 /usr/local/bin/godot4

USER vscode
