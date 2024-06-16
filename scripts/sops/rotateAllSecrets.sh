#!/bin/sh

rotateScript=$(find . -type f -name "rotateSecrets.sh")
find . -type f -name secrets.yaml -exec $rotateScript {} \;
