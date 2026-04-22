#!/bin/bash
echo "Checking Lotus Node status..."
if [ "$(docker inspect -f '{{.State.Running}}' lotus_node)" == "true" ]; then
    echo " Container is RUNNING"
    echo " Traffic usage:"
    docker stats lotus_node --no-stream --format "Table {{.MemUsage}}\t{{.NetIO}}"
else
    echo "Container is DOWN"
fi
