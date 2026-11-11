# Lab 21 — Jenkins CI/CD image: build, scan, push, deploy.
#
# Same host-daemon pattern as Lab 8 (no Docker-in-Docker): the CLI inside
# this container talks to /var/run/docker.sock. On top of that it carries
# kubectl and a kubeconfig mount, because the last stage has to talk to the
# kind cluster. Wrap with --network host so 127.0.0.1:6443 (kind) and
# 172.18.0.1:5000 (the Lab 8 registry) are reachable without extra plumbing.

FROM jenkins/jenkins:lts

USER root

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

# JDK 17 — DemoApp targets java.version 17 and Debian 13 ships 21 only.
ADD https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.21%2B9/OpenJDK17U-jdk_x64_linux_hotspot_17.0.21_9.tar.gz /tmp/jdk17.tar.gz
RUN mkdir -p /opt/jdk17 \
    && tar -xzf /tmp/jdk17.tar.gz -C /opt/jdk17 --strip-components=1 \
    && rm -f /tmp/jdk17.tar.gz

# Trivy — the scanner stage.
ADD https://github.com/aquasecurity/trivy/releases/download/v0.76.1/trivy_0.76.1_Linux-64bit.deb /tmp/trivy.deb
RUN apt-get update && apt-get install -y /tmp/trivy.deb && rm -f /tmp/trivy.deb

# kubectl — the deploy stage (same version as the host, 1.37.1).
ADD https://dl.k8s.io/release/v1.37.1/bin/linux/amd64/kubectl /usr/local/bin/kubectl
RUN chmod +x /usr/local/bin/kubectl

ENV DOCKER_BUILDKIT=1

USER jenkins

COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"
