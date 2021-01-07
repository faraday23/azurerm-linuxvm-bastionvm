output "ssh_key" {
  value = tls_private_key.ssh_keys.private_key_pem
}

output "ssh_command" {
  value = "ssh adminuser@${azurerm_public_ip.bastion.ip_address}"
}

output "bastion_ssh" {
  value = "ssh -i bastion.pem adminuser@${azurerm_public_ip.bastion.ip_address}"
}