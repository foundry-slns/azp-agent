FROM fedora:44

RUN dnf install -y --setopt=install_weak_deps=False \
		ca-certificates \
		curl \
		git \
		gzip \
		jq \
		krb5-libs \
		libicu \
		libstdc++ \
		openssl-libs \
		postgresql \
		procps-ng \
		shadow-utils \
		tar \
		zlib \
	&& dnf clean all \
	&& rm -rf /var/cache/dnf

RUN useradd -m agent && mkdir /azp && chown agent /azp
WORKDIR /azp
COPY --chmod=755 start.sh /usr/local/bin/start.sh

USER agent
ENTRYPOINT ["/usr/local/bin/start.sh"]

