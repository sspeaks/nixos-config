#!/bin/sh

updateScript=$(find . -type f -name "updateKeys.sh")
find . -type f -name secrets.yaml -exec $updateScript {} \;
