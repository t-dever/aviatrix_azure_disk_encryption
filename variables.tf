# START - Azure Resource Variables (variable starts with 'azure_<resource type>')
variable "azure_resource_group_name" {
  description = "The resource group name to be created."
  type        = string
}

variable "azure_location" {
  description = "The location of the Azure Resources."
  type        = string
}

variable "create_key_vault" {
  description = "Set to true to create the key vault."
  type        = bool
  default     = true
}

variable "azure_key_vault_name" {
  description = "The name of the key vault to be created for disk encryption."
  type        = string
}

variable "azure_key_vault_resource_group_name" {
  description = "The name of the resource group where the key vault exists. Required if 'create_key_vault' is false."
  type        = string
}

variable "create_key_vault_access_policy" {
  description = "Set to true to create an access policy for the service principal running the terraform code."
  type = bool
  default = true
}

variable "azure_disk_encryption_set_name" {
  description = "The name of the disk encryption set used for disk encryption."
  type        = string
}

variable "aviatrix_gateway_name" {
  description = "The Aviatrix Gateway name to perform disk encryption on."
  type        = string
}

locals {
  key_vault_id       = var.create_key_vault ? var.azure_key_vault_name : data.azurerm_key_vault.key_vault[0].id
  aviatrix_gw_name   = "av-gw-${var.aviatrix_gateway_name}"
  aviatrix_hagw_name = "av-gw-${var.aviatrix_gateway_name}-hagw"
  az_common_params   = "-g ${var.azure_resource_group_name} --subscription ${data.azurerm_client_config.current.subscription_id}"
  az_vm_deallocate   = "az vm deallocate ${local.az_common_params}"
  az_disk_update     = "az disk update ${local.az_common_params} --disk-encryption-set ${azurerm_disk_encryption_set.disk_encryption_set.id} --encryption-type EncryptionAtRestWithCustomerKey"
  az_vm_start        = "az vm start ${local.az_common_params}"
}
