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
