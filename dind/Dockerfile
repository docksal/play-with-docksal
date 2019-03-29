ARG FROM
FROM ${FROM}

RUN set -xe; \
	apk add --update --no-cache \
		apache2-utils \
		bash \
		bash-completion \
		build-base \
		curl \
		gettext-dev \
		git \
		jq \
		openssh \
		openssl \
		py2-pip \
		sudo \
		tmux \
		tree \
		util-linux \
		vim \
	;\
	rm -rf /var/cache/apk/*;

ENV GOPATH /root/go
ENV PATH $PATH:$GOPATH

# Compile and install httping
# (used in orchestration workshop, and very useful anyway)
RUN set -xe; \
	mkdir -p /opt && cd /opt; \
	curl https://vanheusden.com/httping/httping-2.5.tgz | tar -zxf-; \
	cd httping-2.5; \
	./configure; \
	make install LDFLAGS=-lintl; \
	rm -rf httping-2.5;

# Install Compose and Machine
ENV DOCKER_COMPOSE_VERSION=1.23.2
ENV DOCKER_MACHINE_VERSION=0.16.1
RUN set -xe; \
	pip install docker-compose==${DOCKER_COMPOSE_VERSION}; \
	curl -L https://github.com/docker/machine/releases/download/${DOCKER_MACHINE_VERSION}/docker-machine-Linux-x86_64 \
		-o /usr/bin/docker-machine; \
	chmod +x /usr/bin/docker-machine;

# Add bash completion and set bash as default shell
RUN set -xe; \
	mkdir /etc/bash_completion.d; \
	curl https://raw.githubusercontent.com/docker/cli/master/contrib/completion/bash/docker -o /etc/bash_completion.d/docker; \
	sed -i "s/ash/bash/" /etc/passwd;

# Replace modprobe with a no-op to get rid of spurious warnings
# (note: we can't just symlink to /bin/true because it might be busybox)
RUN rm /sbin/modprobe && echo '#!/bin/true' >/sbin/modprobe && chmod +x /sbin/modprobe

# Install Docksal fin
ENV DOCKSAL_VERSION=1.12.0-rc2
RUN set -xe; \
	curl -fsSL "https://raw.githubusercontent.com/docksal/docksal/v${DOCKSAL_VERSION}/bin/fin" -o /usr/local/bin/fin; \
	chmod +x /usr/local/bin/fin;

# Install a nice vimrc file and prompt (by soulshake)
COPY ["docker-prompt", "sudo", "/usr/local/bin/"]
COPY [".vimrc", ".profile", ".inputrc", ".gitconfig", "./root/"]
COPY ["motd", "/etc/motd"]
COPY ["daemon.json", "/etc/docker/"]

# Preload docksal images
COPY ["docksal-system-images.tar", "docksal-default-images.tar", "/opt/docksal/"]

# Move to our home
WORKDIR /root

# Setup certs and ssh keys
RUN set -xe; \
	mkdir -p /var/run/pwd/certs; \
	mkdir -p /var/run/pwd/uploads; \
	ssh-keygen -N "" -t rsa -f  /etc/ssh/ssh_host_rsa_key >/dev/null; \
	mkdir ~/.ssh && ssh-keygen -N "" -t rsa -f ~/.ssh/id_rsa; \
	cat ~/.ssh/id_rsa.pub > ~/.ssh/authorized_keys

# Remove IPv6 alias for localhost and start docker in the background ...
CMD cat /etc/hosts >/etc/hosts.bak && \
	sed 's/^::1.*//' /etc/hosts.bak > /etc/hosts && \
	sed -i "s/\PWD_IP_ADDRESS/$PWD_IP_ADDRESS/" /etc/docker/daemon.json && \
	sed -i "s/\DOCKER_TLSENABLE/$DOCKER_TLSENABLE/" /etc/docker/daemon.json && \
	sed -i "s/\DOCKER_TLSCACERT/$DOCKER_TLSCACERT/" /etc/docker/daemon.json && \
	sed -i "s/\DOCKER_TLSCERT/$DOCKER_TLSCERT/" /etc/docker/daemon.json && \
	sed -i "s/\DOCKER_TLSKEY/$DOCKER_TLSKEY/" /etc/docker/daemon.json && \
	mount -t securityfs none /sys/kernel/security && \
	echo "root:root" | chpasswd &> /dev/null && \
	/usr/sbin/sshd -o PermitRootLogin=yes -o PrintMotd=no 2>/dev/null && \
	dockerd &>/docker.log & \
	fin image load /opt/docksal/docksal-system-images.tar && \
	fin image load /opt/docksal/docksal-default-images.tar && \
	fin system reset && \
	while true ; do script -q -c "/bin/bash -l" /dev/null ; done
# ... and then put a shell in the foreground, restarting it if it exits
