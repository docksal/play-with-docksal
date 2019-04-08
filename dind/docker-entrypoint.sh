#!/bin/bash

set -e

# Remove IPv6 alias for localhost and start docker in the background ...
cat /etc/hosts >/etc/hosts.bak
sed 's/^::1.*//' /etc/hosts.bak > /etc/hosts

# Figure out host's IP and add a record in /etc/hosts
# registry-cache is a caching registry running on the playground host
gateway=$(route | awk '/^default/ { print $2 }')
echo "${gateway} registry-cache" >> /etc/hosts

sed -i "s/\PWD_IP_ADDRESS/$PWD_IP_ADDRESS/" /etc/docker/daemon.json
sed -i "s/\DOCKER_TLSENABLE/$DOCKER_TLSENABLE/" /etc/docker/daemon.json
sed -i "s/\DOCKER_TLSCACERT/$DOCKER_TLSCACERT/" /etc/docker/daemon.json
sed -i "s/\DOCKER_TLSCERT/$DOCKER_TLSCERT/" /etc/docker/daemon.json
sed -i "s/\DOCKER_TLSKEY/$DOCKER_TLSKEY/" /etc/docker/daemon.json

mount -t securityfs none /sys/kernel/security

echo "root:root" | chpasswd &> /dev/null
/usr/sbin/sshd -o PermitRootLogin=yes -o PrintMotd=no 2>/dev/null

dockerd &>/docker.log &

# Install Docksal
curl -fsSL https://get.docksal.io | bash

exec "$@"
