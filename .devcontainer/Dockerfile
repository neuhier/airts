FROM mcr.microsoft.com/devcontainers/base:ubuntu

ARG GODOT_VERSION=4.3

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
        fluxbox \
        libxcursor1 \
        novnc \
        unzip \
        websockify \
        x11vnc \
        x11-utils \
        xvfb \
    && curl --fail --location --retry 3 \
        "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" \
        --output /tmp/godot.zip \
    && unzip /tmp/godot.zip -d /usr/local/bin \
    && mv "/usr/local/bin/Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot4 \
    && chmod +x /usr/local/bin/godot4 \
    && rm /tmp/godot.zip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
