resource "azurerm_public_ip" "bastion" {
  name                = "${var.names.product_name}-bastion-public"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags = var.tags

  allocation_method = "Static"
  sku               = "Basic"
}

resource "azurerm_network_interface" "bastion" {
  name                = "${var.names.product_name}-bastion"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags = var.tags

  ip_configuration {
    name                          = "bastion"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.bastion.id
  }
}

resource "azurerm_network_security_rule" "bastion_in" {
  name                        = "bastion-in"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = azurerm_network_interface.bastion.private_ip_address
  resource_group_name         = var.resource_group_name
  network_security_group_name = var.security_group_name
}

resource "azurerm_linux_virtual_machine" "bastion" {
  resource_group_name   = var.resource_group_name
  location              = var.location
  tags                  = var.tags
  name                  = try(var.settings.virtual_machine_settings.name, "")
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