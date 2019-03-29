#!/usr/bin/env bash

set -e

CDW=$(pwd)

# Pull and generate default stack images archive.
# We just need a dummy project folder to have fin generate project images for the default stack.
rm -rf default && mkdir -p default/.docksal && cd default
fin image save --project

# Move the image archive to the docker build folder
mv docksal-default-images.tar ${CDW}/dind

# Cleanup
cd ${CDW}
rm -rf default
