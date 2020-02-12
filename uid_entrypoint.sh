#!/bin/bash
if ! whoami &> /dev/null; then
  if [ -w /etc/passwd ]; then
    export HOME=/home/app
    echo "${USER_NAME:-default}:x:$(id -u):1000:${USER_NAME:-default} user:$HOME:" >> /etc/passwd
  fi
fi

exec "$@"
