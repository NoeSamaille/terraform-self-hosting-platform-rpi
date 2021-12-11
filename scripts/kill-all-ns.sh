#!/bin/bash

# Usage: ./kill-all-ns.sh

for item in "node-red" "nextcloud" "bitwarden" "media"
do
    ./kill-namespace.sh $item
done
