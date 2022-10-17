# Retrieve Resource Group Information
data "azurerm_resource_group" "existing_resource_group" {
  name = var.azure_resource_group_name
}

# Retrieve current Service Principal Information
data "azurerm_client_config" "current" {}

# Create Key Vault
resource "azurerm_key_vault" "key_vault" {
  count                       = var.create_key_vault ? 1 : 0
  name                        = var.azure_key_vault_name
  location                    = var.azure_location
  resource_group_name         = var.azure_resource_group_name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "premium"
  enabled_for_disk_encryption = true
  purge_protection_enabled    = true
}

data "azurerm_key_vault" "key_vault" {
  count               = var.create_key_vault ? 0 : 1
  name                = var.azure_key_vault_name
  resource_group_name = var.azure_key_vault_resource_group_name
}

# Create Access Policy to Allow Service Principal to get/create/delete Keys
resource "azurerm_key_vault_access_policy" "key_vault_access_policy" {
  count        = var.create_key_vault_access_policy ? 1 : 0
  key_vault_id = local.key_vault_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id
  key_permissions = [
    "Get",
    "Create",
    "Delete",
    "SetRotationPolicy",
    "Update"
  ]
  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete"
  ]
}

# Set rotation period for 1 year.
resource "time_rotating" "rotate_period" {
  rotation_years = 1
}

# Create Disk Encryption Key
resource "azurerm_key_vault_key" "gw_disk_encryption_key" {
  depends_on = [
    azurerm_key_vault_access_policy.key_vault_access_policy
  ]
  name            = "${var.aviatrix_gateway_name}-os-disk-key"
  key_vault_id    = local.key_vault_id
  key_type        = "RSA"
  key_size        = 2048
  expiration_date = time_rotating.rotate_period.rotation_rfc3339
  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]
}

# Create Disk Encryption Set
resource "azurerm_disk_encryption_set" "disk_encryption_set" {
  name                      = var.azure_disk_encryption_set_name
  resource_group_name       = var.azure_resource_group_name
  location                  = var.azure_location
  key_vault_key_id          = azurerm_key_vault_key.gw_disk_encryption_key.id
  auto_key_rotation_enabled = true
  identity {
    type = "SystemAssigned"
  }
}

# Create Key Vault policy to allow Disk Encryption Set 'disk_encryption_set' to access key vault and rotate keys
resource "azurerm_key_vault_access_policy" "disk_encryption_access_policy" {
  key_vault_id = local.key_vault_id
  tenant_id    = azurerm_disk_encryption_set.disk_encryption_set.identity.0.tenant_id
  object_id    = azurerm_disk_encryption_set.disk_encryption_set.identity.0.principal_id
  key_permissions = [
    "Get",
    "WrapKey",
    "UnwrapKey",
    "SetRotationPolicy",
    "GetRotationPolicy",
    "Rotate"
  ]
}

# Set Transit Disk Encryption Key Rotation Policy
# https://github.com/hashicorp/terraform-provider-azurerm/issues/14471
# null_resource is required until the above github issue is resolved, currently there is no terraform resource for key rotation policy
resource "null_resource" "transit_disk_encryption_key_policy" {
  depends_on = [
    azurerm_key_vault_key.gw_disk_encryption_key,
    azurerm_key_vault_access_policy.disk_encryption_access_policy,
    azurerm_key_vault_access_policy.key_vault_access_policy
  ]
  triggers = {
    key_id = azurerm_key_vault_key.gw_disk_encryption_key.id
  }
  provisioner "local-exec" {
    command = "az keyvault key rotation-policy update --vault-name ${var.azure_key_vault_name} --name ${azurerm_key_vault_key.gw_disk_encryption_key.name} --value key_vault_policies/policy.json"
  }
}

# Get the HAGW Aviatrix Gateway OS Disk Data
data "azurerm_resources" "aviatrix_transit_hagw_disk" {
  type = "Microsoft.Compute/disks"
  required_tags = {
    Name = "Aviatrix-av-gw-${var.aviatrix_gateway_name}-hagw"
  }
}

# Run Disk Encryption Update on Aviatrix HAGW gateway first, before the primary gateway.
resource "null_resource" "disk_encryption_aviatrix_hagw" {
  depends_on = [
    azurerm_disk_encryption_set.disk_encryption_set,
    azurerm_key_vault_access_policy.disk_encryption_access_policy,
    data.azurerm_resources.aviatrix_transit_hagw_disk
  ]
  triggers = {
    os_disk_id = lower(data.azurerm_resources.aviatrix_transit_hagw_disk.resources[0].id)
  }
  provisioner "local-exec" {
    command = "${local.az_vm_deallocate} -n ${local.aviatrix_hagw_name} && ${local.az_disk_update} -n ${data.azurerm_resources.aviatrix_transit_hagw_disk.resources[0].name} && ${local.az_vm_start} -n ${local.aviatrix_hagw_name}"
  }
}

# Wait 5 minutes before performing the Primary Gateway Disk Encryption
resource "time_sleep" "wait_5_minutes" {
  depends_on = [
    null_resource.disk_encryption_aviatrix_hagw
  ]
  triggers = {
    disk_encryption = null_resource.disk_encryption_aviatrix_hagw.id
  }
  create_duration = "5m"
}

# Get the Primary Aviatrix Gateway OS Disk Data
data "azurerm_resources" "aviatrix_primary_gw_disk" {
  type = "Microsoft.Compute/disks"
  required_tags = {
    Name = "Aviatrix-av-gw-${var.aviatrix_gateway_name}"
  }
}

# Run Disk Encryption Update on Aviatrix Primary GW, after the HAGW gateway and after 5 minutes have passed.
resource "null_resource" "disk_encryption_aviatrix_primary_gw" {
  depends_on = [
    time_sleep.wait_5_minutes
  ]
  triggers = {
    os_disk_id = lower(data.azurerm_resources.aviatrix_primary_gw_disk.resources[0].id)
  }
  provisioner "local-exec" {
    command = "${local.az_vm_deallocate} -n ${local.aviatrix_gw_name} && ${local.az_disk_update} -n ${data.azurerm_resources.aviatrix_primary_gw_disk.resources[0].name} && ${local.az_vm_start} -n ${local.aviatrix_gw_name}"
  }
}
