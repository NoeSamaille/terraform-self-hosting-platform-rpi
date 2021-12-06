#!/bin/bash

# Usage: kill-namespace.sh <NAMESPACE>

curl -k -H "Content-Type: application/json" -X PUT -d '{"kind":"Namespace","apiVersion":"v1","metadata":{"name":"'"$1"'"},"spec":{"finalizers":[]}}' "http://127.0.0.1:8001/api/v1/namespaces/${1}/finalize"