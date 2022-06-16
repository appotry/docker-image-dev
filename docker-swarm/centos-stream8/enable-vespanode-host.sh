#!/bin/sh
# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

node=$1
NODELIST=$(docker node ls --format '{{.Hostname}}' | tr '\n' ' ')

for checknode in $NODELIST; do
    if test $checknode = $node
    then
	docker node update --label-add enable-$USER-vespanode=true $node
	exit 0
    fi
done
echo "Bad node $node, not in list of known nodes: $NODELIST" 1>&2
exit 1