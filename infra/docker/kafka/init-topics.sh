#!/usr/bin/env sh
set -e

BOOTSTRAP="${KAFKA_BOOTSTRAP:-kafka-1:9092,kafka-2:9092,kafka-3:9092}"

echo "Creating Kafka topics on ${BOOTSTRAP}..."

/opt/kafka/bin/kafka-topics.sh --bootstrap-server "$BOOTSTRAP" --create --if-not-exists \
  --topic order.events.v1 --partitions 3 --replication-factor 1

/opt/kafka/bin/kafka-topics.sh --bootstrap-server "$BOOTSTRAP" --create --if-not-exists \
  --topic payment.events.v1 --partitions 3 --replication-factor 1

/opt/kafka/bin/kafka-topics.sh --bootstrap-server "$BOOTSTRAP" --create --if-not-exists \
  --topic inventory.events.v1 --partitions 3 --replication-factor 1

/opt/kafka/bin/kafka-topics.sh --bootstrap-server "$BOOTSTRAP" --create --if-not-exists \
  --topic notification.events.v1 --partitions 3 --replication-factor 1

echo "Kafka topics ready."
