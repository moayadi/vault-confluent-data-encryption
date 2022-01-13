resource "confluentcloud_environment" "confluent" {
    provider = confluentcloud
    name = "confluent-sin"
}

resource "confluentcloud_kafka_cluster" "confluent" {


    name = "hashiCluster"
    availability = "LOW"
    service_provider  = "aws"
    region       = "ap-southeast-1"
    deployment = {
        sku = "BASIC"
    }
    environment_id = confluentcloud_environment.confluent.id
    network_egress  = 100
    network_ingress = 100
    storage         = 5000

}

resource "confluentcloud_api_key" "api_key" {
  cluster_id     = confluentcloud_kafka_cluster.confluent.id
  environment_id = confluentcloud_environment.confluent.id
}


locals {
  bootstrap_servers = [replace(confluentcloud_kafka_cluster.confluent.bootstrap_servers, "SASL_SSL://", "")]
}

resource "kafka_topic" "app_ingress" {
  name               = "app-a-ingress"
  replication_factor = 3
  partitions         = 1
  config = {
    "cleanup.policy" = "delete"
  }
}

resource "kafka_topic" "app_egress" {
  name               = "app-a-egress-dev"
  replication_factor = 3
  partitions         = 1
  config = {
    "cleanup.policy" = "delete"
  }
}



