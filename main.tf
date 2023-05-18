locals {
  openai_instances = [
    {
      name             = "dev-openai-instance-2"
      region           = "South Central US"
      active_models = [
        {
          name    = "gpt-35-turbo"
          version = "0301"
        },
      ]
    },
  ]
}

module "apim_vnet_cognitive_services" {
  source = "./modules/apim_vnet_cognitive_services"

  location                    = "South Central US"
  environment                 = "dev"
  company_name                = "contosolabs"
  project_name                = "openai"
  vnet_address_space          = ["10.0.0.0/16"]
  apim_subnet_prefix          = "10.0.1.0/24"
  cognitive_services_subnet_prefix = "10.0.2.0/24"
  apim_name                   = "dev-apim-contosolabs"
  publisher_name              = "contosolabs Publisher"
  publisher_email             = "publisher@contosolabs.com"
  openai_instances            = local.openai_instances
  resource_group_name         = "rg-dev-contosolabs-openai"
  api_management_sku          = "Developer_1"
  allowed_openai_backends     = ["cogsvc-dev-openai-instance-2"]
  
  eventhub_namespace_name     = "dev-ehns-contosolabs"
  eventhub_name               = "dev-eh-contosolabs"
  eventhub_rg                 = "rg-dev-contosolabs-openai-data"

  depends_on                 = [module.eventhub_dataexplorer]
}

module "eventhub_dataexplorer" {
  source = "./modules/eventhub_dataexplorer"

  location                    = "South Central US"
  environment                 = "dev"
  company_name                = "contosolabs"
  project_name                = "openai"
  eventhub_namespace_name     = "dev-ehns-contosolabs"
  eventhub_name               = "dev-eh-contosolabs"
  data_explorer_cluster_name  = "devdxcontosolabs"
  data_explorer_database_name = "dev-dx-db-contosolabs"
  resource_group_name         = "rg-dev-contosolabs-openai-data"
}