FROM ubuntu:26.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		ca-certificates \
		curl \
		git \
		gzip \
		jq \
		libicu78 \
		libkrb5-3 \
		libssl3t64 \
		postgresql-client \
		procps \
		sudo \
		tar \
		zlib1g \
	&& rm -rf /var/lib/apt/lists/*

# Docker CLI only (jobs drive the host's dockerd through the mounted socket)
# and Azure CLI for AzureCLI@2 tasks.
RUN codename=$(. /etc/os-release && echo "$VERSION_CODENAME") \
	&& install -m 0755 -d /etc/apt/keyrings \
	&& curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
	&& echo "deb [signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $codename stable" \
		> /etc/apt/sources.list.d/docker.list \
	&& curl -fsSL https://packages.microsoft.com/keys/microsoft.asc -o /etc/apt/keyrings/microsoft.asc \
	&& echo "deb [signed-by=/etc/apt/keyrings/microsoft.asc] https://packages.microsoft.com/repos/azure-cli/ $codename main" \
		> /etc/apt/sources.list.d/azure-cli.list \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends docker-ce-cli docker-buildx-plugin azure-cli \
	&& rm -rf /var/lib/apt/lists/*

# Google Chrome for Lighthouse CI (chrome-launcher finds google-chrome-stable
# on PATH). Ubuntu's chromium is a snap, which doesn't run in a container.
RUN curl -fsSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o /tmp/chrome.deb \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends /tmp/chrome.deb \
	&& rm -rf /tmp/chrome.deb /var/lib/apt/lists/*

# PowerShell for microsoft365-config (pwsh steps, and OpenTofu's Exchange
# scripts). Microsoft's apt repo has only previews for 26.04, so this is the
# release tarball, pinned by hash.
ARG PWSH_VERSION=7.6.7
ARG PWSH_SHA256=6896f9e3a6b0a354bf470835a96da76d2f801cd50dcf047ad7c4563bf93bf431
RUN curl -fsSL "https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}/powershell-${PWSH_VERSION}-linux-x64.tar.gz" -o /tmp/pwsh.tar.gz \
	&& echo "${PWSH_SHA256}  /tmp/pwsh.tar.gz" | sha256sum --check --quiet \
	&& mkdir -p /opt/microsoft/powershell/7 \
	&& tar -xzf /tmp/pwsh.tar.gz -C /opt/microsoft/powershell/7 \
	&& chmod +x /opt/microsoft/powershell/7/pwsh \
	&& ln -s /opt/microsoft/powershell/7/pwsh /usr/local/bin/pwsh \
	&& rm /tmp/pwsh.tar.gz \
	&& pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'

# The base image's `ubuntu` user holds uid 1000; the host keys the docker
# socket group and work dir to 1000, so `agent` takes it over. Passwordless
# sudo matches Microsoft-hosted agents (e.g. playwright install --with-deps).
RUN userdel -r ubuntu \
	&& useradd -m -u 1000 agent \
	&& echo 'agent ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/agent \
	&& mkdir /azp && chown agent /azp
WORKDIR /azp
COPY --chmod=755 start.sh /usr/local/bin/start.sh

USER agent
ENTRYPOINT ["/usr/local/bin/start.sh"]
