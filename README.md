# Overview

This module will enable Azure Disk Encryption on Aviatrix Gateways. It will perform the disk encryption on the HAGW first then the Primary gateway after the HAGW and waiting 5 minutes. 

Key Vault Key Automatic Rotation Policy is set via Azure CLI.

OS Disk Encryption is set via Azure CLI by performing the following steps:

- Deallocate VM
- Assign Key Vault Encryption Key to OS Disk
- Start VM

## Requirements

In order to use this module you must sign in via AZ CLI before running the terraform code.

Gov Cloud

```cli
export ARM_ENVIRONMENT=usgovernment
export ARM_CLIENT_ID=<spn app id>
export ARM_CLIENT_SECRET=<spn client secret>
export ARM_SUBSCRIPTION_ID=<subscription id>
export ARM_TENANT_ID=<tenant id>
az cloud set --name AzureUSGovernment
az login --service-principal --username <spn app id> --password <spn client secret> --tenant <tenant id>
az account set --subscription <subscription id>
```

Pub Cloud

```cli
export ARM_ENVIRONMENT=public
export ARM_CLIENT_ID=<spn app id>
export ARM_CLIENT_SECRET=<spn client secret>
export ARM_SUBSCRIPTION_ID=<subscription id>
export ARM_TENANT_ID=<tenant id>
az cloud set --name AzureCloud
az login --service-principal --username <spn app id> --password <spn client secret> --tenant <tenant id>
az account set --subscription <subscription id>
```

## Example .tfvars

```terraform
azure_resource_group_name           = "testing-rg"
azure_location                      = "South Central US"
create_key_vault                    = false
create_key_vault_access_policy      = false
azure_key_vault_name                = "testing-kv"
azure_key_vault_resource_group_name = "testing-rg"
azure_disk_encryption_set_name      = "testing-aviatrix-gw-des"
aviatrix_gateway_name               = "testing-gw"
```
