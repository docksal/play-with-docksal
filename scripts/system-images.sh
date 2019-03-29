#!/usr/bin/env bash

# Pull and generate system images archive
fin image save --system

# Move the image archive to the docker build folder
mv docksal-system-images.tar dind
