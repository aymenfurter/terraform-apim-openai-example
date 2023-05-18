data "azurerm_subscription" "current" {}

data "azurerm_eventhub_namespace" "ns" {
  name                = var.eventhub_namespace_name
  resource_group_name = var.eventhub_rg
}

data "azurerm_eventhub" "hub" {
  name                = var.eventhub_name
  namespace_name      = data.azurerm_eventhub_namespace.ns.name
  resource_group_name = var.eventhub_rg
}

data "azurerm_eventhub_namespace_authorization_rule" "auth" {
  name                = "RootManageSharedAccessKey" 
  namespace_name      = data.azurerm_eventhub_namespace.ns.name
  resource_group_name = var.eventhub_rg
}