#!/bin/sh

rotateScript=$(find . -type f -name "rotateSecrets.sh")
find ./secrets -type f -name "*.yaml" -exec $rotateScript {} \;
