#!/bin/bash

ADMIN_TOKEN=$(kubectl -n kubernetes-dashboard get secret $(kubectl -n kubernetes-dashboard get secret | grep admin-user | awk '{print $1}') -o jsonpath="{.data.token}"); echo "{ \"token\": \"$(echo $ADMIN_TOKEN | base64 -d)\" }"
