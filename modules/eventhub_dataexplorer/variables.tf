variable "location" {
  description = "The Azure location where resources will be created."
}

variable "environment" {
  description = "The environment name, e.g. dev, test, prod."
}

variable "company_name" {
  description = "The company name."
}

variable "project_name" {
  description = "The project name."
}

variable "eventhub_namespace_name" {
  description = "The name of the Event Hub Namespace."
}

variable "eventhub_name" {
  description = "The name of the Event Hub."
}

variable "data_explorer_cluster_name" {
  description = "The name of the Data Explorer Cluster."
}

variable "data_explorer_database_name" {
  description = "The name of the Data Explorer Database."
}

variable "resource_group_name" {
  description = "The name of the Azure Resource Group to create resources in."
}
