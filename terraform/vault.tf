
resource "vault_mount" "transit" {
  provider = vault.internal
  path                      = "transit"
  type                      = "transit"
  description               = "Example description"
  default_lease_ttl_seconds = 3600
  max_lease_ttl_seconds     = 86400
}

resource "vault_transit_secret_backend_key" "key" {
  provider = vault.internal
  backend = vault_mount.transit.path
  name    = "transit"  
}

resource "vault_transit_secret_backend_key" "converge_key" {
  provider = vault.internal
  backend = vault_mount.transit.path
  name    = "transit-converge"
  deletion_allowed = true
  convergent_encryption = true
  derived = true    
}

resource "vault_mount" "transform" {
  provider = vault.internal
  type = "transform"
  path = "transform"  
}

resource "vault_transform_template" "sg-nric" {
  provider = vault.internal
  alphabet = "builtin/numeric"
  pattern = "[A-Z]{1}(\d{7})[A-Z]{1}"
  type = "regex"
  name = "sg-nric"
  path = vault_mount.transform.path
}

resource "vault_transform_template" "sg-phone" {
  provider = vault.internal
  alphabet = "builtin/numeric"
  pattern = "[+](\d{2})-(\d{4})-(\d{4})"
  type = "regex"
  name = "sg-phone"
  path = vault_mount.transform.path
}

resource "vault_transform_transformation" "nric-mask" {
  provider = vault.internal
  path = vault_mount.transform.path
  name = "sg-nric-mask"
  template = vault_transform_template.sg-nric.name
  type = "masking"
  masking_character = "*"
  tweak_source = "internal"
  allowed_roles = [vault_transform_role.sg.name]
}

resource "vault_transform_transformation" "nric-fpe" {
  provider = vault.internal
  path = vault_mount.transform.path
  name = "sg-nric-fpe"
  template = vault_transform_template.sg-nric.name
  type = "fpe"
  tweak_source = "internal"
  allowed_roles = [vault_transform_role.sg.name]
}

resource "vault_transform_transformation" "phone-fpe" {
  provider = vault.internal
  path = vault_mount.transform.path
  name = "sg-phone-fpe"
  template = vault_transform_template.sg-phone.name
  type = "fpe"
  tweak_source = "internal"
  allowed_roles = [vault_transform_role.sg.name]
}

resource "vault_transform_role" "sg" {
  provider = vault.internal
  path = vault_mount.transform.path
  name = "sg-transform"
  transformations = [ "sg-phone-fpe","sg-nric-mask" ]
}

resource "vault_generic_secret" "confluent_token" {
  depends_on = [vault_mount.kv]
  provider = vault.internal
  path = "kv/confluent-cloud"
  data_json = <<EOT
  {
    "client_id": "${confluentcloud_api_key.api_key.key}",
    "client_secret": "${confluentcloud_api_key.api_key.secret}",
    "connection_string": "${local.bootstrap_servers[0]}",
    "convergent_context_id":"YWJjMTIz"
  }
EOT

}

resource "vault_generic_secret" "app-a-config" {
  depends_on = [vault_mount.kv]
  provider = vault.internal
  path = "kv/app-a/config"
  data_json = <<EOT
  {
    "keys_of_interest":[{"key": "owner.email", "method": "aes"},
        {"key": "owner.NRIC", "method": "transform", "transformation":"sg-nric-mask"},
        {"key": "owner.telephone", "method": "transform", "transformation":"sg-phone-fpe"},
        {"key": "choices.places_of_interest", "method": "aes-converge"}
      ],
    "transform_mount":"transform",
    "transform_role_name":"sg-transform",
    "transit_mount":"transit",
    "transit_key_name":"transit",
    "convergent_key_name":"transit-converge"
  }
EOT

}

resource "vault_mount" "pki" {
  provider = vault.internal
  path = "pki"
  type = "pki"
  max_lease_ttl_seconds = 315360000 # 10y
}

resource "vault_pki_secret_backend_root_cert" "pki" {
  provider = vault.internal

  backend = vault_mount.pki.path
  depends_on = [vault_mount.pki]

  type                  = "internal"
  common_name           = "example.com"
  ttl                   = "315360000"
  format                = "pem"
  private_key_format    = "der"
  key_type              = "rsa"
  key_bits              = 4096
  organization          = "My organization"
}


resource "vault_pki_secret_backend_role" "pki" {
  provider = vault.internal
  allowed_domains = ["service.internal"]
  allow_subdomains = true
  max_ttl = "1h"
  name = "app"
  backend = vault_mount.pki.path
}

resource "vault_auth_backend" "kubernetes" {
  provider = vault.internal
  type = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "kubernetes" {
  provider = vault.internal
  kubernetes_host = "https://10.100.0.1"
  kubernetes_ca_cert = var.kubernetes_ca
  token_reviewer_jwt = var.kubernetes_jwt
  disable_iss_validation=true
  backend = vault_auth_backend.kubernetes.path


}

resource "vault_kubernetes_auth_backend_role" "transform" {
  provider = vault.internal
  backend = vault_auth_backend.kubernetes.path
  bound_service_account_names = ["transform"]
  bound_service_account_namespaces = ["default"]
  role_name = "transform"
  token_policies = ["${vault_policy.transformer_policy.name}"]
}

resource "vault_kubernetes_auth_backend_role" "app" {
  provider = vault.internal
  backend = vault_auth_backend.kubernetes.path
  bound_service_account_names = ["app"]
  bound_service_account_namespaces = ["default"]
  role_name = "app"
  token_policies = ["${vault_policy.app_policy.name}"]
}




resource "vault_mount" "kv" {
  path = "kv"
  type = "kv-v2"
}

