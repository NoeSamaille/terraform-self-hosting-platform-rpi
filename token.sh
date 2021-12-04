#!/bin/bash

echo $RANDOM > /dev/null; TOKEN=$(echo $RANDOM | md5sum | head -c 20; echo) && echo "{ \"token\": \"${TOKEN}\" }"