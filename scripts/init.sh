#!/bin/bash

# Usage: source init.sh

function prop {
    grep "${1}" .ignore.tokens | grep -vE "^#" | cut -d'=' -f2 | sed 's/"//g'
}

if [[ -f ".ignore.tokens" ]]; then
    # Load the credentials
    export TF_VAR_bitwarden_admin_token=$(prop 'bitwarden_admin_token')
    export TF_VAR_nextcloud_admin_password=$(prop 'nextcloud_admin_password')
    export TF_VAR_transmission_password=$(prop 'transmission_password')
else
    echo $RANDOM > /dev/null; export TF_VAR_bitwarden_admin_token=$(echo $RANDOM | md5sum | head -c 20; echo)
    echo $RANDOM > /dev/null; export TF_VAR_nextcloud_admin_password=$(echo $RANDOM | md5sum | head -c 20; echo)
    echo $RANDOM > /dev/null; export TF_VAR_transmission_password=$(echo $RANDOM | md5sum | head -c 20; echo)
    touch .ignore.tokens
    echo "bitwarden_admin_token=\"${TF_VAR_bitwarden_admin_token}\"" >> .ignore.tokens
    echo "nextcloud_admin_password=\"${TF_VAR_nextcloud_admin_password}\"" >> .ignore.tokens
    echo "transmission_password=\"${TF_VAR_transmission_password}\"" >> .ignore.tokens
fi
