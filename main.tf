locals {
  os_type = lower(var.settings.os_type)
}

resource "azurerm_public_ip" "bastion" {
  name                = "${module.metadata.names.product_name}-bastion-public"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location

  allocation_method = "Static"
  sku               = "Basic"

  tags = module.metadata.tags
}

resource "azurerm_network_interface" "bastion" {
  name                = "${module.metadata.names.product_name}-bastion"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location

  ip_configuration {
    name                          = "bastion"
    subnet_id                     = module.virtual_network.subnet["iaas-outbound-subnet"].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.bastion.id
  }

  tags = module.metadata.tags
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
  resource_group_name         = module.resource_group.name
  network_security_group_name = module.virtual_network.subnet_nsg_names["iaas-outbound-subnet"]
}

resource "azurerm_linux_virtual_machine" "bastion" {
  for_each = local.os_type == "linux" ? var.settings.virtual_machine_settings : {}

  resource_group_name   = module.resource_group.name
  location              = module.resource_group.location
  size                  = each.value.size
  admin_username        = each.value.admin_username
  network_interface_ids = [ azurerm_network_interface.bastion.id, ]

  allow_extension_operations      = try(each.value.allow_extension_operations, null)
  computer_name                   = azurecaf_name.linux_computer_name[each.key].result
  eviction_policy                 = try(each.value.eviction_policy, null)
  max_bid_price                   = try(each.value.max_bid_price, null)
  priority                        = try(each.value.priority, null)
  provision_vm_agent              = try(each.value.provision_vm_agent, true)
  zone                            = try(each.value.zone, null)
  disable_password_authentication = try(each.value.disable_password_authentication, true)
  custom_data                     = try(each.value.custom_data, null) == null ? null : filebase64(format("%s/%s", path.cwd, each.value.custom_data))
  availability_set_id             = try(var.availability_sets[var.client_config.landingzone_key][each.value.availability_set_key].id, var.availability_sets[each.value.availability_sets].id, null)
  proximity_placement_group_id    = try(var.proximity_placement_groups[var.client_config.landingzone_key][each.value.proximity_placement_group_key].id, var.proximity_placement_groups[each.value.proximity_placement_groups].id, null)

  dynamic "admin_ssh_key" {
    for_each = lookup(each.value, "disable_password_authentication", true) == true ? [1] : []

    content {
      username   = each.value.admin_username
      public_key = tls_private_key.ssh[each.key].public_key_openssh
    }
  }

  os_disk {
    caching                   = try(each.value.os_disk.caching, null)
    disk_size_gb              = try(each.value.os_disk.disk_size_gb, null)
    name                      = try(azurecaf_name.os_disk_linux[each.key].result, null)
    storage_account_type      = try(each.value.os_disk.storage_account_type, null)
    write_accelerator_enabled = try(each.value.os_disk.write_accelerator_enabled, false)
  }

  source_image_reference {
    publisher = try(each.value.source_image_reference.publisher, null)
    offer     = try(each.value.source_image_reference.offer, null)
    sku       = try(each.value.source_image_reference.sku, null)
    version   = try(each.value.source_image_reference.version, null)
  }
}