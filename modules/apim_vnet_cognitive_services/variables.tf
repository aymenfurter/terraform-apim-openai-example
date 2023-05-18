variable "location" {
  type        = string
  description = "Azure location"
}

variable "environment" {
  type        = string
  description = "Environment, e.g., dev, prod"
}

variable "company_name" {
  type        = string
  description = "Company name"
}

variable "project_name" {
  type        = string
  description = "Project name"
}

variable "vnet_address_space" {
  type        = list(string)
  description = "VNet address space"
}

variable "apim_subnet_prefix" {
  type        = string
  description = "API Management subnet prefix"
}

variable "cognitive_services_subnet_prefix" {
  type        = string
  description = "Cognitive Services subnet prefix"
}

variable "apim_name" {
  type        = string
  description = "API Management name"
}

variable "publisher_name" {
  type        = string
  description = "API Management publisher name"
}

variable "publisher_email" {
  type        = string
  description = "API Management publisher email"
}

variable "openai_instances" {
  type = list(object({
    name          = string
    region        = string
    active_models = list(object({
      name    = string
      version = string
    }))
  }))
  description = "List of OpenAI instances with name, region, active models (with name and version), and AD group"
}


variable "resource_group_name" {
  type        = string
  description = "Resource group name"
}

variable "api_management_sku" {
  type        = string
  description = "API Management SKU"
}

variable "eventhub_namespace_name" {
  description = "The name of the Event Hub Namespace."
}

variable "eventhub_name" {
  description = "The name of the Event Hub."
}

variable "eventhub_rg" {
  description = "The name of the Event Hub."
}

variable "allowed_openai_backends" {
  type        = list(string)
  description = "A list of allowed backends"
}

locals {
  formatted_backends = "new string[] { \"${join("\", \"", var.allowed_openai_backends)}\" }"
}

