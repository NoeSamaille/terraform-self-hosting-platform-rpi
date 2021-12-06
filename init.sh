#!/bin/bash

echo $RANDOM > /dev/null; export TF_VAR_bitwarden_admin_token=$(echo $RANDOM | md5sum | head -c 20; echo)
echo $RANDOM > /dev/null; export TF_VAR_nextcloud_admin_password=$(echo $RANDOM | md5sum | head -c 20; echo)