# JDK 17 required by AGP 8.1.2 (CI config has wrong JDK version)
FROM eclipse-temurin:17-jdk AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    unzip \
    git \
    sed \
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

# Fix 1: Replace org.gradle.jvmargs with --add-opens for icepick (Clojure) annotation processor
RUN sed -i 's|^org.gradle.jvmargs=.*|org.gradle.jvmargs=-Xmx2048M -XX:+HeapDumpOnOutOfMemoryError -Dfile.encoding=UTF-8 --add-opens=jdk.compiler/com.sun.tools.javac.model=ALL-UNNAMED --add-opens=jdk.compiler/com.sun.tools.javac.processing=ALL-UNNAMED --add-opens=jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED --add-opens=jdk.compiler/com.sun.tools.javac.util=ALL-UNNAMED --add-opens=jdk.compiler/com.sun.tools.javac.tree=ALL-UNNAMED --add-opens=jdk.compiler/com.sun.tools.javac.code=ALL-UNNAMED --add-opens=jdk.compiler/com.sun.tools.javac.comp=ALL-UNNAMED --add-opens=jdk.compiler/com.sun.tools.javac.file=ALL-UNNAMED --add-opens=jdk.compiler/com.sun.tools.javac.jvm=ALL-UNNAMED --add-opens=jdk.compiler/com.sun.tools.javac.main=ALL-UNNAMED --add-opens=jdk.compiler/com.sun.tools.javac.parser=ALL-UNNAMED|' PipePipeClient/gradle.properties

# Fix 2: Add buildConfig true (AGP 8.x disables it by default)
RUN sed -i 's|viewBinding true|viewBinding true\n        buildConfig true|' PipePipeClient/app/build.gradle

# Fix 3: Update Compose Compiler version to match Kotlin 1.9.10 (project pre-existing issue)
RUN sed -i "s|kotlinCompilerExtensionVersion '1.3.2'|kotlinCompilerExtensionVersion '1.5.3'|" PipePipeClient/app/build.gradle

# Fix 4: Fix pre-existing compilation errors (R.id.content -> android.R.id.content)
RUN sed -i 's|R\.id\.content|android.R.id.content|g' PipePipeClient/app/src/main/java/org/schabi/newpipe/error/ErrorUtil.kt

# Build
RUN cd PipePipeClient && ./gradlew assembleDebug --stacktrace -DskipFormatKtlint