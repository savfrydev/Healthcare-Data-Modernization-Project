locals {
  tags = {
    Environment = var.tag_environment
    Owner       = var.tag_owner
    CostCenter  = var.tag_costcenter
  }
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.project_rg
  location = var.location
  tags     = local.tags
}

output "rg_name"     { 
  value = azurerm_resource_group.rg.name 
  }
output "rg_location" { 
  value = azurerm_resource_group.rg.location 
  }
