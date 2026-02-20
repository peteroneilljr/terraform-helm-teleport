variable "name" {
  type        = string
  description = "Secret name (e.g. postgresql-tls, mysql-tls)"
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace"
}

variable "ca_common_name" {
  type        = string
  description = "CA subject CN (e.g. Custom PostgreSQL CA)"
}

variable "dns_names" {
  type        = list(string)
  description = "Service DNS names for CSR"
}

variable "teleport_db_ca_pem" {
  type        = string
  description = "Teleport DB CA cert to bundle into ca.crt"
}
