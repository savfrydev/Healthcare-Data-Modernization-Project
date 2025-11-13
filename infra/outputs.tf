output "function_default_hostname" {
value = azurerm_linux_function_app.func.default_hostname
description = "Default hostname of the Function App"
}


output "key_vault_name" {
value = azurerm_key_vault.kv.name
description = "Deployed Key Vault name"
}


output "storage_account_name" {
value = azurerm_storage_account.sa.name
description = "Storage account for the Function runtime"
}