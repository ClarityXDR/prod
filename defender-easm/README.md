# Microsoft Defender External Attack Surface Management (EASM)

This template deploys Microsoft Defender External Attack Surface Management to an existing resource group.

## Overview

Microsoft Defender External Attack Surface Management (EASM) helps organizations discover internet-facing resources and identify potential vulnerabilities in their external attack surface. It provides:

- Discovery of unknown and unmanaged internet-facing assets
- Identification of security risks in your external attack surface
- Continuous monitoring of your attack surface
- Integration with Microsoft Defender for Cloud

## Deployment

### Prerequisites

- An active Azure subscription
- Appropriate permissions to deploy resources to the target resource group
- Microsoft Defender for Cloud enabled on the subscription

### Deployment Steps

1. Deploy using Azure Portal:
   - Click on "Deploy to Azure" button
   - Fill in the required parameters
   - Review and create the deployment

2. Deploy using Azure CLI:
   ```bash
   az deployment group create --resource-group <YourResourceGroupName> --template-file azuredeploy.json --parameters @azuredeploy.parameters.json