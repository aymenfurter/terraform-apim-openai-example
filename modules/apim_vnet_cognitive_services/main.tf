locals {
  common_tags = {
    Environment = var.environment
    Company     = var.company_name
    Project     = var.project_name
  }
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.environment}-${var.company_name}-${var.project_name}-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space
  tags                = local.common_tags
  depends_on          = [azurerm_resource_group.rg]
}

resource "azurerm_subnet" "apim_subnet" {
  name                 = "apim-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.apim_subnet_prefix]

  service_endpoints = [
    "Microsoft.EventHub",
    "Microsoft.KeyVault",
    "Microsoft.ServiceBus",
    "Microsoft.Sql",
    "Microsoft.Storage"
  ]
}

resource "azurerm_subnet" "cognitive_services_subnet" {
  name                 = "cogsvc-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.cognitive_services_subnet_prefix]
}

resource "azurerm_public_ip" "apim_public_ip" {
  name                = "${var.apim_name}-public-ip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "apim-oaigw-${var.environment}-${var.company_name}-${var.project_name}"
}

# API Management
resource "azurerm_api_management" "apim" {
  name                = var.apim_name
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
  sku_name            = var.api_management_sku
  public_ip_address_id = azurerm_public_ip.apim_public_ip.id

  identity {
    type = "SystemAssigned"
  }

  virtual_network_configuration {
    subnet_id = azurerm_subnet.apim_subnet.id
  }

  virtual_network_type = "External"

  tags = local.common_tags

  lifecycle {
    ignore_changes = [ 
        hostname_configuration
     ]
  } 

  depends_on = [azurerm_subnet.apim_subnet]
}

resource "azurerm_api_management_api" "api" {
  name                  = "openai-api"
  resource_group_name   = var.resource_group_name
  api_management_name   = azurerm_api_management.apim.name
  revision              = "1"
  display_name          = "OpenAI API"
  path                  = ""
  protocols             = ["https"]
  subscription_required = false


  depends_on = [azurerm_api_management.apim]

  import {
    content_format = "openapi-link"
    content_value  = "https://gist.githubusercontent.com/aymenfurter/f165303a653d68b5031c10e84ab5f887/raw/0058d5bf60326071672c963fbba6eff5744057c8/openai"
  }
}

resource "azurerm_api_management_named_value" "tenant_id" {
  name                = "tenant"
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azurerm_api_management.apim.name
  display_name        = "tenant"
  value               = data.azurerm_subscription.current.tenant_id
}

resource "azurerm_api_management_api_policy" "policy" {
  api_name            = azurerm_api_management_api.api.name
  api_management_name = azurerm_api_management.apim.name

  depends_on = [azurerm_api_management_api.api, azurerm_api_management_named_value.tenant_id, azurerm_api_management_logger.logger]

  resource_group_name = var.resource_group_name

  xml_content = <<XML
<policies>
    <inbound>
        <base />
        <choose>
            <when condition="@(!string.IsNullOrEmpty(context.Request.Url.Path.Trim('/').Split('/')[1]))">
                <set-header name="Authorization" exists-action="skip">
                    <value>@("Bearer " + context.Request.Headers.GetValueOrDefault("api-key", ""))</value>
                </set-header>
                <validate-jwt header-name="Authorization" failed-validation-httpcode="403" failed-validation-error-message="Forbidden">
                    <openid-config url="https://login.microsoftonline.com/{{tenant}}/v2.0/.well-known/openid-configuration" />
                    <issuers>
                        <issuer>https://sts.windows.net/{{tenant}}/</issuer>
                    </issuers>
                    <required-claims>
                        <claim name="aud">
                            <value>https://cognitiveservices.azure.com</value>
                        </claim>
                    </required-claims>
                </validate-jwt>
                <set-variable name="workloadIdentifier" value="@{ return context.Request.Url.Path.Trim('/').Split('/')[1]; }" />
                <set-variable name="targetBackend" value="@{ return context.Request.Url.Path.Trim('/').Split('/')[0]; }" />
                <choose>
                    <when condition="@(context.Request.Url.Path.Contains("/chat/completions"))">
                        <rewrite-uri template="/openai/deployments/{deployment-id}/chat/completions?api-version={api-version}" />
                    </when>
                    <when condition="@(context.Request.Url.Path.Contains("/completions"))">
                        <rewrite-uri template="/openai/deployments/{deployment-id}/completions?api-version={api-version}" />
                    </when>
                    <when condition="@(context.Request.Url.Path.Contains("/embeddings"))">
                        <rewrite-uri template="/openai/deployments/{deployment-id}/embeddings?api-version={api-version}" />
                    </when>
                </choose>
                <!-- Extract user information from JWT -->
                <set-variable name="user" value="@{
                    string jwt = context.Request.Headers.GetValueOrDefault("Authorization", "").Substring("Bearer ".Length);
                    string[] jwtParts = jwt.Split('.');
                    string payloadBase64 = jwtParts[1];

                    // Add padding if necessary
                    int paddingLength = payloadBase64.Length % 4;
                    if (paddingLength > 0)
                    {
                        payloadBase64 += new string('=', 4 - paddingLength);
                    }

                    string payloadJson = Encoding.UTF8.GetString(Convert.FromBase64String(payloadBase64));
                    JObject payload = JObject.Parse(payloadJson);

                    // Use "name" if available, otherwise use "appid"
                    string identifier = payload.GetValue("name", StringComparison.OrdinalIgnoreCase)?.ToString();
                    if (string.IsNullOrEmpty(identifier))
                    {
                        identifier = payload.GetValue("appid", StringComparison.OrdinalIgnoreCase)?.ToString() ?? "";
                    }

                    return identifier;
                }" />
                <set-variable name="requestBody" value="@(context.Request.Body.As<JObject>(preserveContent: true))" />
            </when>
            <otherwise>
                <!-- If the header is missing, return an error -->
                <return-response>
                    <set-status code="400" reason="Bad Request" />
                    <set-header name="Content-Type" exists-action="override">
                        <value>application/json</value>
                    </set-header>
                    <set-body>{
                "error": "missing_header",
                "error_description": "The 'WorkloadIdentifier' path variable is required."
                }</set-body>
                </return-response>
            </otherwise>
        </choose>
        <choose>
            <when condition="@{
                string[] allowedBackends = ${local.formatted_backends};
                string targetBackend = (string)context.Variables["targetBackend"];
                return allowedBackends.Contains(targetBackend);
            }">
                <set-backend-service base-url="@($"https://{context.Variables["targetBackend"]}.openai.azure.com/")" />
            </when>
            <otherwise>
                <return-response>
                    <set-status code="403" reason="Forbidden" />
                    <set-header name="Content-Type" exists-action="override">
                        <value>application/json</value>
                    </set-header>
                    <set-body>{
                "error": "invalid_backend",
                "error_description": "The target backend is not allowed."
                }</set-body>
                </return-response>
            </otherwise>
        </choose>
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
        <set-variable name="responseBody" value="@(context.Response.Body.As<JObject>(preserveContent: true))" />
        <log-to-eventhub logger-id="OpenAIFeed">@{
        JObject responseBody = (JObject)context.Variables["responseBody"];
        JObject requestBody = (JObject)context.Variables["requestBody"];

        return new JObject(
          new JProperty("completion_tokens", (int)responseBody["usage"]["completion_tokens"]),
          new JProperty("prompt_tokens", (int)responseBody["usage"]["prompt_tokens"]),
          new JProperty("total_tokens", (int)responseBody["usage"]["total_tokens"]),
          new JProperty("WorkloadIdentifier", (string)context.Variables["workloadIdentifier"]),
          new JProperty("Backend", (string)context.Variables["targetBackend"]),
          new JProperty("User", (string)context.Variables["user"]),
          new JProperty("FullRequestBody", requestBody.ToString()),
          new JProperty("FullResponseBody", responseBody.ToString())
        ).ToString();
      }</log-to-eventhub>
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
XML
}

resource "azurerm_api_management_logger" "logger" {
  name                = "OpenAIFeed" 
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name

  eventhub {
  name                = data.azurerm_eventhub.hub.name
    connection_string = "${data.azurerm_eventhub_namespace_authorization_rule.auth.primary_connection_string}"
  }
}


# Cognitive Services
resource "azurerm_cognitive_account" "cognitive_services" {
  for_each = { for instance in var.openai_instances : instance.name => instance }

  name                  = each.value.name
  location              = each.value.region
  resource_group_name   = var.resource_group_name
  kind                  = "OpenAI" 
  sku_name              = "S0" 
  custom_subdomain_name = "cogsvc-${each.value.name}"
  public_network_access_enabled = false


  tags = local.common_tags
}

resource "azurerm_private_endpoint" "cognitive_services_private_endpoint" {
  for_each = { for instance in var.openai_instances : instance.name => instance }

  name                = "cogsvc-private-endpoint-${each.key}"
  location            = each.value.region
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.cognitive_services_subnet.id

  private_service_connection {
    name                           = "cogsvc-connection-${each.key}"
    private_connection_resource_id = azurerm_cognitive_account.cognitive_services[each.key].id
    subresource_names              = ["account"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.cognitive_services_private_dns_zone.id]
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "cognitive_services_private_dns_zone_link" {
  name                  = "cogsvc-private-dns-zone-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.cognitive_services_private_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone" "cognitive_services_private_dns_zone" {
  name                = "privatelink.openai.azure.com"
  resource_group_name = var.resource_group_name
  depends_on          = [azurerm_resource_group.rg]
}

locals {
  instance_models = flatten([
    for instance in var.openai_instances : [
      for model in instance.active_models : {
        instance_name = instance.name
        model_name    = model.name
        model_version = model.version
      }
    ]
  ])
}

resource "azurerm_cognitive_deployment" "model" {
  for_each = { for im in local.instance_models : "${im.instance_name}-${im.model_name}-${im.model_version}" => im }

  name                 = "deployment-${each.key}"
  cognitive_account_id = azurerm_cognitive_account.cognitive_services[each.value.instance_name].id

  model {
    format  = "OpenAI"
    name    = each.value.model_name
    version = each.value.model_version
  }

  scale {
    type = "Standard"
  }
}
