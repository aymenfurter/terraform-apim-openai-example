Azure OpenAI with APIM 🕵️
==================================

This Terraform repository provisions an environment to run and manage an OpenAI instance on Azure. The environment includes an Azure API Management (APIM) service, Cognitive Services, an Event Hub, and a Data Explorer. The APIM service is used to expose a unified API for OpenAI instances, while the Event Hub and Data Explorer are used for logging and analyzing usage data.

Repository Structure
--------------------

The repository is structured as follows:

-   `main.tf`: The main configuration file that includes the `locals`, `module "apim_vnet_cognitive_services"`, and `module "eventhub_dataexplorer"` blocks.
-   `modules/`: Contains the Terraform modules used in the project.
    -   `apim_vnet_cognitive_services/`: Module for creating API Management, Virtual Network, and Cognitive Services resources.
    -   `eventhub_dataexplorer/`: Module for creating Event Hub and Data Explorer resources.


Deployment Procedure
--------------------

1.  Install [Terraform](https://www.terraform.io/downloads.html).
2.  Clone this repository and navigate to the repository folder.
3.  Initialize Terraform: `terraform init`.
4.  Apply the Terraform configuration: `terraform apply`.
5.  Setup [Event Hub Data Connection](https://learn.microsoft.com/en-us/azure/data-explorer/create-event-hubs-connection?tabs=portal%2Cportal-2)


Usage
--------------------
The following is an example how the OpenAI Service can be consumed through the APIM. The api_base parameter is used to specify additional parameters (e.g. workload identifier and target Azure OpenAI instance). 

```python

```python
from azure.identity import InteractiveBrowserCredential

interactive_credential = InteractiveBrowserCredential(tenant_id="<your_tenant>") 
token = interactive_credential.get_token("https://cognitiveservices.azure.com/.default email openid profile")

import openai
openai.api_type = "azure"
openai.api_base = "https://<api>.azure-api.net/<azure-openai-instance>/<workload-identifier>"
openai.api_version = "2023-05-15" 
openai.api_key = ""

response = openai.ChatCompletion.create(
    engine="<deployment-id>",
    headers={"Authorization": f"Bearer {token.token}"},
    messages=[
        {"role": "system", "content": "Assistant is a large language model trained by OpenAI."},
        {"role": "user", "content": "Who were the founders of Microsoft?"}
    ]
)

print(response)
print(response['choices'][0]['message']['content'])
```