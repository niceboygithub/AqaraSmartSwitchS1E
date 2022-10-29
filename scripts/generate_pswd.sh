#!/bin/sh
#base64(hmac_sha256(key, sha256(did+mac+key)))

if [ $# != 3 ];then
        echo "Usage: ./generate_pswd.sh did mac key"
        exit 0
fi

did=$1
mac=$2
key=$3
echo -e "\n============================================"
echo "did=$did mac=$mac key=$key"
echo "base64(hmac_sha256(key, sha256(did+mac+key)))"
Message=$key
Secret=`echo -n $did$mac$key | sha256sum | awk '{print$1}'`
ret=`echo -n $Message | openssl dgst -sha256 -hmac $Secret -binary | base64`

echo "base64(hmac_sha256($key, sha256($did$mac$key)))=$ret"
start=`expr ${#ret} - 16`
echo start=$start
pswd=`echo ${ret:$start:16}`
echo -e "============================================\n"
echo "did=$did mac=$mac key=$key pswd=$pswd"
