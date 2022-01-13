variable "kubernetes_ca" {}
variable "kubernetes_jwt" {}

variable "confluent_username" {}
variable "confluent_password" {
  sensitive = true
}