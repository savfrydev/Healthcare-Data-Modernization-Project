############################################
# providers.tf — Healthcare Data Modernization
############################################

terraform {
  required_version = ">= 1.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0" # Works across all modern Azure environments
    }
  }
}

provider "azurerm" {
  features {}
}
