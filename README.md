# Introduction



# What is Kafka?



# Build the image

```shell
docker buildx build \
    -f ./Dockerfile.development \
    --platform linux/amd64,linux/arm64 \
    --push=true \
    -t 10.1.1.1:27443/ngd-kafka:0.0.1 \
    .
```

# Deploy Zookeeper

```shell
sudo kubectl apply -f zookeeper_pod.yaml
```

# Deploy kafka

```shell
# CSD mode
sudo kubectl apply -f kafka_daemonset_csd.yaml

# Hybrid mode
sudo kubectl apply -f kafka_daemonset_hybrid.yaml

# host mode
sudo kubectl apply -f kafka_daemonset_host.yaml
```

```shell
sudo kubectl get pods --show-labels -o wide
```

# Test your installation

```shell
# Create a topic
./bin/kafka-topics.sh --create \
    --partitions 2 \
    --replication-factor 2 \
    --topic mytopic \
    --bootstrap-server 10.1.1.1:9092
```

```shell
# Listen to events
./bin/kafka-console-consumer.sh \
    --topic mytopic \
    --from-beginning \
    --bootstrap-server 10.1.1.1:9092
```

```shell
# Create events in topic
./bin/kafka-console-producer.sh \
    --topic mytopic \
    --bootstrap-server 10.1.1.1:9092
```

```shell
# Delete a topic
./bin/kafka-topics.sh --delete \
    --topic mytopic \
    --bootstrap-server 10.1.1.1:9092
```

# Undeploy kafka

```shell
# To remove a deploy in hybrid mode
sudo kubectl delete -f kafka_daemonset_csd.yaml

# To remove a deploy in CSD mode
sudo kubectl delete -f kafka_daemonset_csd.yaml

# To remove a deploy in CSD mode
sudo kubectl delete -f kafka_daemonset_host.yaml

# Undeploy zookeeper
sudo kubectl delete -f zookeeper_pod.yaml
```

