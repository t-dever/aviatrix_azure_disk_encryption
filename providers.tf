terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "3.1.1"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.7.2"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.27.0"
    }
  }
}


provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    virtual_machine {
      delete_os_disk_on_deletion = true
    }
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
  skip_provider_registration = true
}
