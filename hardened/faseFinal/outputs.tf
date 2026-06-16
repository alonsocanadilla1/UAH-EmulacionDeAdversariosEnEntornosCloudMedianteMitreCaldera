# ==============================================================================
# SALIDAS DE TERRAFORM (DATOS PARA MITRE CALDERA)
# ==============================================================================

output "ip_caldera_c2" {
  value       = azurerm_public_ip.c2_public_ip.ip_address
  description = "IP publica del servidor atacante. Entra en http://<IP>:8888"
}

output "ip_web_victima" {
  value       = azurerm_public_ip.pip_web_victim.ip_address
  description = "IP publica de la maquina victima para el ataque React2Shell"
}

output "nombre_datalake" {
  value       = azurerm_storage_account.datalake.name
  description = "Nombre del Data Lake para la exfiltracion de UNC5537"
}

output "nombre_aml_storage" {
  value       = azurerm_storage_account.aml_storage_predictable.name
  description = "Nombre del almacenamiento predecible para Bucket Squatting"
}