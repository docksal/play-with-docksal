#!/bin/bash

# This is a startup script for a Docksal Sandbox server in GCP.
# It installs and configures Docksal on a bare Ubuntu machine (tested with Ubuntu 18.04 Minimal).
#
# The startup script log can be views via "gcloud compute ssh vm-sandbox-test -- tail -f /var/log/syslog"

set -x  # Print commands
set -e  # Fail on errors

DISK_LABEL="data-volume"
MOUNT_POINT="/data"

mount_part()
{
    DATA_DISK=$1
    # mark disk with label
    tune2fs -L ${DISK_LABEL} ${DATA_DISK} >/dev/null 2>&1
    # Mount the data disk
    mkdir -p ${MOUNT_POINT}
    cp /etc/fstab /etc/fstab.backup
    # Write disk mount to /etc/fstab (so that it persists on reboots)
    # Equivalent of `mount /dev/sdb /mnt/data`
    echo "LABEL=${DISK_LABEL} ${MOUNT_POINT}  ext4  defaults,nofail  0 2" | tee -a /etc/fstab
    mount -a
}

create_fs()
{
    # creating ext4 fs and add label
    DATA_DISK=$1
    mkfs.ext4 -m 0 -F -E lazy_itable_init=0,lazy_journal_init=0,discard ${DATA_DISK} -L ${DISK_LABEL} >/dev/null 2>&1
}

get_part_list()
{
    # get disk partitions info.
    # the result will contain strings: NAME="/dev/nvme1n1";TYPE="disk";FSTYPE="";LABEL="";MOUNTPOINT="" NAME="/dev/nvme0n1";TYPE="disk";FSTYPE="";LABEL="";MOUNTPOINT=""
    # in our case will be only one string
    DATA_DISK=$1
    blockdev --rereadpt ${DATA_DISK}
    lsblk -p -n -P -o NAME,TYPE,FSTYPE,LABEL,MOUNTPOINT ${DATA_DISK} | grep part | sed 's/ /;/g'
}

create_part()
{
    # create msdos partition table and create primary partition used 100% disk size
    DATA_DISK=$1
    /sbin/parted ${DATA_DISK} -s mklabel msdos
    /sbin/parted ${DATA_DISK} -s -a optimal mkpart primary 0% 100%
}

###############################################################################################
###    Main code begin
###############################################################################################
# Wait for data volume attachment (necessary with AWS EBS)
wait_count=0
wait_max_attempts=12
while true
do
    let "wait_count+=1"
    # additional data disk is considered attached when number of disk attached to instance more than 1
    [[ "$(lsblk -p -n -o NAME,TYPE | grep disk | wc -l)" > 1 ]] && break
    (( ${wait_count} > ${wait_max_attempts} )) && break
    echo "Waiting for EBS volume to attach (${wait_count})..."
    sleep 5
done

# find additional data disk, format it and mount
for disk in $(lsblk -d -p -n -o NAME,TYPE | grep disk | cut -d' ' -f1)
do
    # partitioning disk if disk is clean
    [[ $(get_part_list "${disk}") == "" ]] && { echo "Disk ${disk} is clean! Creating partition..."; create_part "${disk}"; }
    eval $(echo $(get_part_list "${disk}"))
    # skip disk if his partition is mounted
    [[ "$MOUNTPOINT" != "" ]] && { echo "Disk $disk have partition $NAME, and it already mounted! Skipping..."; continue; }
    # mount disk partition if ext4 fs found, but not mounted (volume was added from another instance)
    [[ "$FSTYPE" == "ext4" ]] && { echo "Disk $disk have partition $NAME with FS, but not mounted! Mounting..."; mount_part "$NAME"; continue; }
    # create fs and mount when we already have partition, but fs not created yet
    echo "Disk $disk have partition $NAME, but does not have FS! Creating FS and mounting..."
    create_fs "${NAME}"
    mount_part "${NAME}"
done

if [ -d $MOUNT_POINT ]
then
    # Symlink /var/lib/docker (should not yet exist when this script runs) to the data volume
    mkdir -p ${MOUNT_POINT}/var/lib/docker
    ln -s ${MOUNT_POINT}/var/lib/docker /var/lib/docker
else
    echo "WARNING: data volume not found. Using instance-only storage"
fi

curl -fsSL https://get.docker.com | sudo bash

HOST="$(curl http://169.254.169.254/latest/meta-data/public-ipv4).nip.io"
echo 'export HOST='${HOST} >>/root/.bashrc
echo 'export GOROOT=/usr/local/go' >>/root/.bashrc
echo 'export GOPATH=/root/go'  >>/root/.bashrc
echo 'export PATH=$PATH:$GOROOT/bin:$GOPATH/bin' >>/root/.bashrc

docker swarm init
modprobe xt_ipvs
echo "xt_ipvs" >>  /etc/modules

docker pull franela/dind
curl -L https://github.com/docker/compose/releases/download/1.21.2/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose &&chmod +x /usr/local/bin/docker-compose
curl -L https://storage.googleapis.com/golang/go1.7.1.linux-amd64.tar.gz -o go1.7.1.linux-amd64.tar.gz
tar -C /usr/local -xzf go1.7.1.linux-amd64.tar.gz

export HOST=${HOST}
export GOROOT=/usr/local/go
export GOPATH=/root/go
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin

mkdir -p /root/go
mkdir -p $GOPATH/bin

curl https://raw.githubusercontent.com/golang/dep/master/install.sh | sh
mkdir -p $GOPATH/src/github.com/play-with-docker
cd $GOPATH/src/github.com/play-with-docker
git clone https://github.com/play-with-docker/play-with-docker.git
cd play-with-docker && dep ensure -v

sed -i 's#"playground-domain", "localhost"#"playground-domain", "'${HOST}'"#' config/config.go

mkdir -p /var/lib/registry/
docker run --rm --entrypoint /bin/sh registry:2 -c "cat /etc/docker/registry/config.yml" > /var/lib/registry/config.yml
echo -e "proxy:\n  remoteurl: https://registry-1.docker.io" >>/var/lib/registry/config.yml
docker run -d --restart=always -p 5000:5000 --name registry-mirror -v /var/lib/registry:/var/lib/registry registry:2 /var/lib/registry/config.yml

docker-compose up -d
