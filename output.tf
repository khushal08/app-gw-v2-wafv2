output "subnets_ids" {
  value = var.subnets != null ? [for subnet in azurerm_subnet.subnet : subnet.id] : []
}