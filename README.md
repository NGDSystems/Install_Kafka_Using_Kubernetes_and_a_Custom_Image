# Introduction

This repository demonstrates how to deploy a simple Kafka configuration on a cluster of CSDs. It requires a working Kubernetes cluster, to orchestrate the containers, docker buildx, cross-compiling, and a local registry, to hold the custom Kafka image. If you don't have any of these, you can follow the instructions from [Install_Kubernetes_and_deploy_a_custom_app_on_NGD_CSDs](https://github.com/NGDSystems/Install_Kubernetes_and_deploy_a_custom_app_on_NGD_CSDs).

At the end of this tutorial, we will have a working Kafka cluster with a distinct Kafka server running on each selected machine. We will also configure three types of deploy modes: hybrid, the server is deployed in the host and all CSDs; host, the Kafka server is deployed only in the Host; and CSD, Kafka server is deployed in all CSDs but not in the Host.

# What is Kafka?

As defined in Kafka [official website](https://kafka.apache.org/), "Apache Kafka is an open-source distributed event streaming platform used by thousands of companies for high-performance data pipelines, streaming analytics, data integration, and mission-critical applications". What it means is that Kafka is:

- Message broker - Subscribe and publish messages in topics. Only listen to relevant messages;
- Real-time processing - Messages are processed and delivered in high throughput, with latencies as low as 2ms;
- Horizontal scalability - Scale the server-side to thousands of machines and process trillions of messages per day;
- Storage - Safely persist streams in a distributed and fault-tolerant cluster;
- Integration - Kafka's Connect interface natively supports hundreds of event sources and event sinks, allowing fast integration with many popular databases and services;
- High availability - Stretch your cluster across geographic regions and explore the benefits from a resilient and distributed service;
- Popular - Used by more than 80% of all Fortune 100 companies;
- Vast Comunity - Kafka is one of the five most active Apache Software Foundation projects.

Kafka is a great addition to NGD CSDs as it allows fast communication, integration with many existing services and data storage solutions, streaming processing, and many other common edge computing requirements.

# Build the image

This repository contains a copy of Kafka 3.0.0 running with scala 2.13. The deploy this app on a cluster of CSDs we need to build the image for two architectures, x86_64 and aarch64. For such, we will instruct docker buildx to build the image in these architectures and upload them to our local registry. The command below assumes the registry is running at 10.1.1.1, port 27443. The name of the image is ngd-kafka and the tag is 0.0.1.

```shell
docker buildx build \
    -f ./Dockerfile.development \
    --platform linux/amd64,linux/arm64 \
    --push=true \
    -t 10.1.1.1:27443/ngd-kafka:0.0.1 \
    .
```

The image contains an embedded Zookeeper and Kafka itself. We have added a start script ( start_server.development.sh) to select whether the image should start the Zoopeeper or the Kafka server. This is controlled through an environment parameter called SERVICE, configured in the Kubernetes scripts.

# Deploy Zookeeper

To install and start the Zookeeper we will use a Pod configuration. As Kafka requires direct communication between its servers, we will configure all entities with the option "hostNetwork: true". This will allow all containers to share the same node network they are deployed. To create the container for Zookeeper, run the command below.

```shell
sudo kubectl apply -f zookeeper_pod.yaml
```

# Deploy Kafka

As mentioned before, we are providing three deploy options for Kafka, hybrid, host, and CSD. Each option has its own DaemonSet script and this is the time to choose which one you need, or you want to test. Execute one of the options below to deploy Kafka in the CSD cluster.

```shell
# CSD mode
sudo kubectl apply -f kafka_daemonset_csd.yaml

# Hybrid mode
sudo kubectl apply -f kafka_daemonset_hybrid.yaml

# host mode
sudo kubectl apply -f kafka_daemonset_host.yaml
```

It should take a few seconds for the CSDs to download the images and start the system. You can use the following commands to check if they are correctly deployed and running.

```shell
# Show all pods
sudo kubectl get pods -o wide

# Show all DaemonSets
sudo kubectl get daemonset -o wide
```

# Test your installation

To perform a basic sanity check, we will use the scripts that come with the Kafka installation itself. These scripts are used to manually manage Kafka messages in the server. As mentioned before, Kafka is a message broker. The analogy it uses is that users use common communication channels (topics) to send messages to (produce) and to receive messages from (consume). To demonstrate this flow, this section explores four operations: (1) create a topic; (2) register as a consumer user; (3) register as a producer and publish messages in the topic; and (4) terminate the topic.

Before we start we will need two things. The pod names of two Kafka servers and a topic name. Pod names are randomly generated by Kubernetes when we deploy our server, we can retrieve them with the command below. Select two pod names from its output and save them to the environment variables $POD1 and $POD2.

```shell
# This will query all pods in the current namespace and filter the output using grep
sudo kubectl get pods -o wide | grep -E '(^ngd-kafka-kafka|^NAME)'

# The commands below are shortcuts to automatically map the first fours pods into environment variables. Respectively, $POD1, $POD2, $POD3, and $POD4.
POD1=$(sudo kubectl get pods | grep -E '^ngd-kafka-kafka' | awk 'NR==1 { print $1 }')
POD2=$(sudo kubectl get pods | grep -E '^ngd-kafka-kafka' | awk 'NR==2 { print $1 }')
POD3=$(sudo kubectl get pods | grep -E '^ngd-kafka-kafka' | awk 'NR==3 { print $1 }')
POD4=$(sudo kubectl get pods | grep -E '^ngd-kafka-kafka' | awk 'NR==4 { print $1 }')
```

> **Note:** If you deployed in host mode you will only have one pod (POD1). You will also need to adequate replication-factor and partitions to the number of pods you have, in the next commands. For instance, if you are running in host mode, replication-factor and partitions should be 1.

Next, we need to choose a topic name for the experiment. We will use **ngd-kafka-topic** in this example.

Now we will use POD1 to create a topic in the Kafka cluster. As the Kafka installation files are located inside the container, we will use kubectl exec to execute the command inside the containers. The following command uses POD1 to execute kafka-topics.sh --create and create the topic ngd-kafka-topic.

```shell
# Create a topic
sudo kubectl exec -it $POD1 -- /app/bin/kafka-topics.sh --create \
    --partitions 2 \
    --replication-factor 2 \
    --topic ngd-kafka-topic \
    --bootstrap-server localhost:9092
```

Now that the topic is created, others may connect to produce or consume content from it. We will use POD2 to simulate the consumer. Feel free to use any pod you want and exercise their communication capability.

```shell
# Listen to events
sudo kubectl exec -it $POD2 -- /app/bin/kafka-console-consumer.sh \
    --topic ngd-kafka-topic \
    --from-beginning \
    --bootstrap-server localhost:9092
```

The command above will hang until you press Ctrl+C to interrupt its execution. This is the excepted behavior as it is waiting for Kafka messages. When they arrive they will be displayed in the terminal. Now open a new terminal and use the following command to start a producer. Again, you can choose any pod you want, but remember to declare the environment variables (POD1, POD2, POD3, and POD4) as this is a new shell session.

```shell
# Create events in topic
sudo kubectl exec -it $POD1 -- /app/bin/kafka-console-producer.sh \
    --topic ngd-kafka-topic \
    --bootstrap-server localhost:9092
```

When the producer is running, type anything in and press Enter. When you press Enter, the producer will publish the message and any connected consumer will receive it. Press Ctrl+C to terminate the producer application.

Once you are done with this experiment, you can delete the topic with the following command.

```shell
# Delete a topic
sudo kubectl exec -it $POD2 -- /app/bin/kafka-topics.sh --delete \
    --topic ngd-kafka-topic \
    --bootstrap-server localhost:9092
```

As you may have noticed, the Pods are connecting to Kafka through localhost:9092. Remember that we are using kubectl exec to execute commands inside the container. Therefore, in this context, localhost refers to the Kafka server running inside the container, not the host or any other machine you may be connected to. If you need to access Kafka from a different container, you will need to use the correct IP address.

# Undeploy Kafka

Similarly to the installation phase, we need to choose the right command depending on the deploy type we are using (Hybrid, CSD, or Host). This will basically tell Kubernetes to undo our previous "kubectl apply".

```shell
# To remove a deploy in hybrid mode
sudo kubectl delete -f kafka_daemonset_hybrid.yaml

# To remove a deploy in CSD mode
sudo kubectl delete -f kafka_daemonset_csd.yaml

# To remove a deploy in CSD mode
sudo kubectl delete -f kafka_daemonset_host.yaml
```

Next, remove the Zookeeper with the following command.

```shell
# Undeploy zookeeper
sudo kubectl delete -f zookeeper_pod.yaml
```
