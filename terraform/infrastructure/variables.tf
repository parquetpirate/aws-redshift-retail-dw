variable "db_master_password" {
  description = "Master password for the Redshift cluster."
  type        = string
  sensitive   = true
}

variable "allowed_cidr" {
  description = "CIDR block allowed to reach the cluster on port 5439 (e.g. \"YOUR_PUBLIC_IP/32\")."
  type        = string
}
