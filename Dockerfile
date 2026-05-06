# JDK 17 required by AGP 8.1.2 (CI config has wrong JDK version)
FROM eclipse-temurin:17-jdk AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    unzip \
    git \
    && rm -rf /var/lib/apt/lists/*

ENV ANDROID_HOME=/opt/android-sdk
ENV PATH="${PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools"

# Install Android SDK
RUN mkdir -p ${ANDROID_HOME}/cmdline-tools && \
    wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O /tmp/cmdline-tools.zip && \
    unzip -q /tmp/cmdline-tools.zip -d ${ANDROID_HOME}/cmdline-tools && \
    mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest && \
    rm /tmp/cmdline-tools.zip

RUN yes | sdkmanager --licenses > /dev/null 2>&1 || true
RUN sdkmanager "platforms;android-33" "build-tools;33.0.2" "platform-tools"

WORKDIR /app

COPY PipePipeClient/ PipePipeClient/
COPY PipePipeExtractor/ PipePipeExtractor/

RUN chmod +x PipePipeClient/gradlew PipePipeExtractor/gradlew

# Build
RUN cd PipePipeClient && ./gradlew assembleDebug --stacktrace --info -DskipFormatKtlint 2>&1