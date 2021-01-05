output "ssh_command" {
  value = "ssh adminuser@${azurerm_public_ip.bastion.ip_address}"
}