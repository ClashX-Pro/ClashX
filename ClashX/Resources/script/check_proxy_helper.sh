#!/bin/sh

cd "$1";
CURRENT=$(./ProxyConfig version);
TARGET=$2;
if [[ `ls -l ProxyConfig` = *"root"* ]]; then

if [ "$CURRENT" == "$TARGET" ];then
echo "success"
exit
fi
fi
echo "false"
