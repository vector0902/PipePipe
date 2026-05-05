# Stage 1: Use JDK 17 to set up Android SDK
FROM eclipse-temurin:17-jdk AS sdk-setup

RUN apt-get update && apt-get install -y --no-install-recommends wget unzip && rm -rf /var/lib/apt/lists/*

ENV ANDROID_HOME=/opt/android-sdk
ENV PATH="${PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools"

RUN mkdir -p ${ANDROID_HOME}/cmdline-tools && \
    wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O /tmp/cmdline-tools.zip && \
    unzip -q /tmp/cmdline-tools.zip -d ${ANDROID_HOME}/cmdline-tools && \
    mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest && \
    rm /tmp/cmdline-tools.zip

RUN yes | sdkmanager --licenses > /dev/null 2>&1 || true
RUN sdkmanager "platforms;android-33" "build-tools;33.0.2" "platform-tools"

# Stage 2: Use JDK 11 to build the project (matching CI)
FROM eclipse-temurin:11-jdk AS builder

RUN apt-get update && apt-get install -y --no-install-recommends git && rm -rf /var/lib/apt/lists/*

# Copy Android SDK from stage 1
ENV ANDROID_HOME=/opt/android-sdk
ENV PATH="${PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools"
COPY --from=sdk-setup ${ANDROID_HOME} ${ANDROID_HOME}

WORKDIR /app

# Copy project files
COPY PipePipeClient/ PipePipeClient/
COPY PipePipeExtractor/ PipePipeExtractor/

# Make gradlew executable
RUN chmod +x PipePipeClient/gradlew PipePipeExtractor/gradlew

# Build the project (matching CI command)
RUN cd PipePipeClient && ./gradlew assembleDebug --stacktrace -DskipFormatKtlint