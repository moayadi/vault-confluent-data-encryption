resource "vault_policy" "app_policy" {
   provider = vault.internal
   name = "app-a-policy"
   policy = <<EOT

               path "kv/data/confluent-cloud" {
                 capabilities = ["read"]
               }

               path "pki/issue/app" {
                  capabilities = ["update"]
               }

         EOT

}

resource "vault_policy" "transformer_policy" {
   name = "transformer-policy"
   policy = <<EOT
         path "/transit/encrypt/transit-converge" {
           capabilities = ["update"]
         }

         path "transit/encrypt/transit" {
           capabilities = ["update"]
         }

         path "kv/data/confluent-cloud" {
           capabilities = ["read"]
         }

         path "kv/data/app-a/config" {
           capabilities = ["read"]
         }

         path "transform/encode/sg-transform" {
           capabilities = ["update"]
         }
         EOT
}
