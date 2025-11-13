variable "location" {
  type    = string
  default = "eastus"
}

variable "project_rg" {
  type = string
}

variable "app_name" {
  type = string
}

variable "enable_networking" {
  type    = bool
  default = false
}

variable "tag_environment" {
  type    = string
  default = "Dev"
}

variable "tag_owner" {
  type    = string
  default = "Owner"
}

variable "tag_costcenter" {
  type    = string
  default = "POC"
}

variable "governance_mode" {
  type        = string
  description = "'audit' or 'deny'"
  default     = "audit"

  validation {
    condition     = contains(["audit", "deny"], var.governance_mode)
    error_message = "governance_mode must be 'audit' or 'deny'."
  }
}

locals {
  tags = {
    Environment = var.tag_environment
    Owner       = var.tag_owner
    CostCenter  = var.tag_costcenter
    Project     = "healthcare-demo"
  }

  policy_effect_tags_required  = var.governance_mode == "deny" ? "deny" : "auditIfNotExists"
  policy_effect_storage_public = var.governance_mode == "deny" ? "deny" : "audit"
}
