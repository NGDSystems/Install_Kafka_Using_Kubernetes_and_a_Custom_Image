#!/usr/bin/env bash

set -e

if [ "$SERVICE" = "ZOOKEEPER" ]; then
  echo "Starting Zookeeper"
  /app/bin/zookeeper-server-start.sh config/zookeeper.properties

else
  echo "Starting Kafka server"
  /app/bin/kafka-server-start.sh config/server.properties
fi

echo "Server stopped"
