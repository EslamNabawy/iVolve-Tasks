# Lab 8 — Jenkins CI image for this repository's labs.
#
# The official LTS image plus every tool Labs 1-6 use. Docker commands do
# NOT run a daemon here: the container talks to the HOST daemon through
# the mounted /var/run/docker.sock (see commands.sh). Plugins are declared
# in plugins.txt and baked in at build time; configuration (admin user,
# the pipeline job) arrives as YAML via Configuration as Code — the setup
# wizard never runs.

FROM jenkins/jenkins:lts

USER root

# System tools: git for the clones, docker CLI for the daemon socket,
# unzip for the Gradle distribution, maven from Debian (3.9.9 here; the
# host used 3.8.7 — both produce the same jar).
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      docker-buildx \
      docker-cli \
      docker.io \
      git \
      maven \
      unzip \
    && rm -rf /var/lib/apt/lists/*

# JDK 17 — Debian 13 no longer ships openjdk-17 (21 only), and Labs 1/2
# must BUILD with 17: a jar compiled for a newer class version refuses to
# run in Lab 3's JRE-17 image. Temurin 17.0.21 tarball, no apt.
ADD https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.21%2B9/OpenJDK17U-jdk_x64_linux_hotspot_17.0.21_9.tar.gz /tmp/jdk17.tar.gz
RUN mkdir -p /opt/jdk17 \
    && tar -xzf /tmp/jdk17.tar.gz -C /opt/jdk17 --strip-components=1 \
    && rm -f /tmp/jdk17.tar.gz

# Gradle 9.8.2 — the exact version Lab 2 used (binary zip, no sudo).
ADD https://services.gradle.org/distributions/gradle-9.8.2-bin.zip /tmp/gradle.zip
RUN unzip -q /tmp/gradle.zip -d /opt && rm -f /tmp/gradle.zip

# Trivy 0.76.1 — the exact version Lab 5 used.
ADD https://github.com/aquasecurity/trivy/releases/download/v0.76.1/trivy_0.76.1_Linux-64bit.deb /tmp/trivy.deb
RUN apt-get update && apt-get install -y /tmp/trivy.deb && rm -f /tmp/trivy.deb

ENV DOCKER_BUILDKIT=1
ENV GRADLE_HOME=/opt/gradle-9.8.2
ENV PATH="/opt/gradle-9.8.2/bin:${PATH}"

USER jenkins

# Plugins resolved at image build time (jenkins-plugin-cli pulls each
# plugin's transitive dependencies too) — no network, no wizard, at boot.
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# No setup wizard: this container is a local lab bound to 127.0.0.1.
# JAVA_OPTS stays the image's bundled JDK for Jenkins itself; the pipeline
# exports JAVA_HOME=/opt/jdk17 only around the Lab 1/2 builds.
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"
