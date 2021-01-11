resource "tls_private_key" "ssh_keys" {
  algorithm = "RSA"
  rsa_bits  = "2048"
}

resource "local_file" "pem_files" {
  content         = tls_private_key.ssh_keys.private_key_pem
  filename        = "${path.module}/${"bastion"}.pem"
  file_permission = "0600"
}

resource "azurerm_public_ip" "bastion" {
  name                = "${var.names.product_name}-bastion-public"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  allocation_method = "Static"
  sku               = "Basic"
}

resource "azurerm_network_interface" "bastion" {
  name                = "${var.names.product_name}-bastion-nic"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  ip_configuration {
    name                          = "AzureBastionSubnet"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.bastion.id
  }
}

resource "azurerm_network_security_rule" "bastion_in_allow" {
  name                        = "bastion-in-allow"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = var.security_group_name
}

resource "azurerm_network_security_rule" "bastion_control_in_allow" {
  name                        = "bastion-control-in-allow"
  priority                    = 130
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "GatewayManager"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = var.security_group_name
}

resource "azurerm_network_security_rule" "bastion_lb" {
  name                        = "bastion-lb"
  priority                    = 140
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = var.security_group_name
}

resource "azurerm_network_security_rule" "bastion_host_communication" {
  name                        = "bastion-host-communication"
  priority                    = 150
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8080, 5701"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.resource_group_name
  network_security_group_name = var.security_group_name
}

resource "azurerm_network_security_rule" "bastion_ssh_rdp_outbound" {
  name                        = "bastion-ssh-rdp-outbound"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22, 3389"
  source_address_prefix       = "*"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.resource_group_name
  network_security_group_name = var.security_group_name
}

resource "azurerm_network_security_rule" "bastion_azure_cloud_outbound" {
  name                        = "bastion-azure-cloud-outbound"
  priority                    = 110
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "AzureCloud"
  resource_group_name         = var.resource_group_name
  network_security_group_name = var.security_group_name
}

resource "azurerm_network_security_rule" "bastion_communication_outbound" {
  name                        = "bastion-communication-outbound"
  priority                    = 120
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8080, 5701"
  source_address_prefix       = "*"
  destination_address_prefix  = "AzureCloud"
  resource_group_name         = var.resource_group_name
  network_security_group_name = var.security_group_name
}

resource "azurerm_network_security_rule" "bastion_session_information" {
  name                        = "bastion-session-information"
  priority                    = 130
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "80"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = var.resource_group_name
  network_security_group_name = var.security_group_name
}

resource "azurerm_bastion_host" "azurebastion" {
  name                = "${var.names.product_name}-bastion-host"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                 = "AzureBastionSubnet"
    subnet_id            = var.subnet_id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}

resource "azurerm_linux_virtual_machine" "bastion" {
  resource_group_name   = var.resource_group_name
  location              = var.location
  tags                  = var.tags
  name                  = "${var.names.product_name}-bastion-vm"
  size                  = try(var.settings.virtual_machine_settings.size, "")
  admin_username        = try(var.settings.virtual_machine_settings.admin_username, "")
  network_interface_ids = [azurerm_network_interface.bastion.id, ]

  allow_extension_operations      = try(var.settings.virtual_machine_settings.allow_extension_operations, null)
  computer_name                   = try(var.settings.virtual_machine_settings.name, null)
  priority                        = try(var.settings.virtual_machine_settings.priority, null)
  eviction_policy                 = try(var.settings.virtual_machine_settings.eviction_policy, null)
  provision_vm_agent              = try(var.settings.virtual_machine_settings.provision_vm_agent, true)
  zone                            = try(var.settings.virtual_machine_settings.zone, null)
  disable_password_authentication = try(var.settings.virtual_machine_settings.disable_password_authentication, true)

  admin_ssh_key {
    username   = try(var.settings.virtual_machine_settings.admin_ssh_key.username, null)
    public_key = try(tls_private_key.ssh_keys.public_key_openssh, var.settings.virtual_machine_settings.admin_ssh_key.public_key)
  }

  os_disk {
    caching                   = try(var.settings.virtual_machine_settings.os_disk.caching, null)
    disk_size_gb              = try(var.settings.virtual_machine_settings.os_disk.disk_size_gb, null)
    name                      = try(var.settings.virtual_machine_settings.os_disk_linux, null)
    storage_account_type      = try(var.settings.virtual_machine_settings.os_disk.storage_account_type, null)
    write_accelerator_enabled = try(var.settings.virtual_machine_settings.os_disk.write_accelerator_enabled, false)
  }

  source_image_reference {
    publisher = try(var.settings.virtual_machine_settings.source_image_reference.publisher, null)
    offer     = try(var.settings.virtual_machine_settings.source_image_reference.offer, null)
    sku       = try(var.settings.virtual_machine_settings.source_image_reference.sku, null)
    version   = try(var.settings.virtual_machine_settings.source_image_reference.version, null)
  }
}


