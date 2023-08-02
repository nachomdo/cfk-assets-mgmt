variable "project_id" {
  description = "project id"
}

variable "region" {
  description = "region"
}

variable "gke_username" {
  default     = ""
  description = "gke username"
}

variable "gke_password" {
  default     = ""
  description = "gke password"
}

variable "gke_num_nodes" {
  default     = 2
  description = "number of gke nodes"
}

variable "gke_nodes_instance_type" {
  default     = "e2-standard-8"
  description = "gke nodes instance type"
}

variable "kafka_instance_type" {
  default     = "e2-standard-2"
  description = "gke nodes instance type"
}

variable "bastion_instace_type" {
  default = "e2-medium"
}

variable "os_image" {
  default     = "ubuntu-2004-lts"
  description = "os image for the instances"
}

variable "domain_name" {
  default     = "example.com"
  description = "domain name"
}