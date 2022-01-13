terraform {
    required_providers {
        vault = {
            source = "hashicorp/vault"
            version = "3.0"
        }
        confluentcloud = {
        source = "Mongey/confluentcloud"
        }
        kafka = {
        source  = "Mongey/kafka"
        version = "0.2.11"
        }
    }
}


provider "confluentcloud" {
    username =  var.confluent_username
    password = var.confluent_password
}

provider "kafka" {
  bootstrap_servers = local.bootstrap_servers

  tls_enabled    = true
  sasl_username  = confluentcloud_api_key.api_key.key
  sasl_password  = confluentcloud_api_key.api_key.secret
  sasl_mechanism = "plain"
  timeout        = 10
}

provider "vault" {
  alias = "cloud"
  namespace = "admin"
  token = hcp_vault_cluster_admin_token.root.token
  address = hcp_vault_cluster.hcp_vault.vault_public_endpoint_url
}


provider "vault" {
  alias = "internal"
  token = "root"
  address = "http://localhost:8200"
}
