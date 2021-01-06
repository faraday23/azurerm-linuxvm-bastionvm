# Configure terraform and azure provider
terraform {
  required_version = ">= 0.13.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 2.25.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 2.2.0"
    }
  }
}

provider "azurerm" {
  features {}
}

data "http" "my_ip" {
  url = "http://ipv4.icanhazip.com"
}

data "azurerm_subscription" "current" {}

resource "random_string" "random" {
  length  = 12
  upper   = false
  special = false
}

module "subscription" {
  source          = "github.com/Azure-Terraform/terraform-azurerm-subscription-data.git?ref=v1.0.0"
  subscription_id = data.azurerm_subscription.current.subscription_id
}

module "rules" {
  source = "github.com/openrba/python-azure-naming.git?ref=tf"
}

module "metadata" {
  source = "github.com/Azure-Terraform/terraform-azurerm-metadata?ref=v1.1.0"

  naming_rules = module.rules.yaml

  market              = "us"
  project             = "https://gitlab.ins.risk.regn.net/example/"
  location            = "useast2"
  sre_team            = "iog-core-services"
  environment         = "sandbox"
  product_name        = "mssql8"
  business_unit       = "iog"
  product_group       = "core"
  subscription_id     = module.subscription.output.subscription_id
  subscription_type   = "nonprod"
  resource_group_type = "app"
}

module "resource_group" {
  source = "github.com/Azure-Terraform/terraform-azurerm-resource-group.git?ref=v1.0.0"

  location = module.metadata.location
  names    = module.metadata.names
  tags     = module.metadata.tags
}

module "virtual_network" {
  source = "github.com/Azure-Terraform/terraform-azurerm-virtual-network.git?ref=v2.2.0"

  naming_rules = module.rules.yaml

  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  names               = module.metadata.names
  tags                = module.metadata.tags

  address_space = ["10.1.1.0/24"]

  subnets = {
    "iaas-outbound" = { cidrs = ["10.1.1.0/27"] }
  }
}

# Virtual machines
module "bastion" {
  source = "../BASTION_HOST/bastion_host"

  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  names               = module.metadata.names
  tags                = module.metadata.tags

  subnet_id = module.virtual_network.subnet["iaas-outbound"].id
  security_group_name = module.virtual_network.subnet_nsg_names["iaas-outbound"]

  # Configuration to deploy a bastion host linux virtual machine
  settings = {
    virtual_machine_settings = {
      name                            = "bastion-host"
      size                            = "Standard_D2s_v3"
      admin_username                  = "adminuser"
      disable_password_authentication = true

      # Spot VM to save money
      priority        = "Spot"
      eviction_policy = "Deallocate"

      # Availability zone
      zone = 1

      # Internal OS disk
      os_disk = {
        name                 = "bastion_host_os"
        caching              = "ReadWrite"
        storage_account_type = "Standard_LRS"
      }
      
      # Image used to create the virtual machines.
      source_image_reference = {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
      }
    }
  }
}

