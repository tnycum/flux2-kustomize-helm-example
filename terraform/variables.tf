variable "subscription_id" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "node_count" {
  type    = number
  default = 2
}

variable "username" {
  type        = string
  description = "The admin username for the new cluster."
  default     = "azureadmin"
}

variable "aks_name_prefix" {
  type        = string
  description = "Prefix to attach to AKS cluster names and DNS"
}
