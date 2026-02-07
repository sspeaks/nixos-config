#!/bin/sh

updateScript=$(find . -type f -name "updateKeys.sh")
find ./secrets -type f -name "*.yaml" -exec $updateScript {} \;
