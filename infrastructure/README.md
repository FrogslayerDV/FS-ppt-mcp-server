# PowerPoint MCP Server - Infrastructure as Code

This directory contains OpenTofu (Terraform) configuration files for deploying the PowerPoint MCP Server to Azure Container Apps.

## Directory Structure

```
infrastructure/
├── bootstrap/              # State backend setup
│   └── main.tf
├── modules/                # Reusable modules
│   ├── container-apps-env/
│   ├── container-apps-job/
│   └── monitoring/
├── main.tf                 # Main configuration
├── variables.tf            # Input variables
├── outputs.tf              # Output values
├── versions.tf             # Provider versions
├── backend.tf              # Remote state config
├── terraform.tfvars.example # Example variables
└── README.md               # This file
```

## Prerequisites

- [OpenTofu](https://opentofu.org/) v1.6.0 or later
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) v2.0 or later
- Azure subscription with Contributor access

## Quick Start

### 1. Initial Setup (One-time)

#### Create Azure Service Principal

```bash
# Login to Azure
az login

# Get subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Create service principal
az ad sp create-for-rbac \
  --name "opentofu-ppt-mcp" \
  --role contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID \
  --sdk-auth
```

Save the output for GitHub secrets configuration.

#### Bootstrap State Backend

```bash
# Navigate to bootstrap directory
cd bootstrap

# Initialize OpenTofu
tofu init

# Apply bootstrap configuration
tofu apply

# Note the storage account name from output
STORAGE_ACCOUNT_NAME=$(tofu output -raw storage_account_name)
echo "Storage Account: $STORAGE_ACCOUNT_NAME"
```

### 2. Main Infrastructure Deployment

#### Configure Variables

```bash
# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
# Required variables:
# - github_username
# - container_image (or use default)
```

#### Initialize and Deploy

```bash
# Initialize with remote backend
tofu init \
  -backend-config="resource_group_name=rg-ppt-mcp-tfstate" \
  -backend-config="storage_account_name=$STORAGE_ACCOUNT_NAME" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=ppt-mcp.tfstate"

# Plan deployment
tofu plan -var="github_token=$GITHUB_TOKEN"

# Apply deployment
tofu apply -var="github_token=$GITHUB_TOKEN"
```

### 3. GitHub Actions Setup

#### Required Secrets

Configure these secrets in your GitHub repository:

```yaml
# Azure Service Principal
AZURE_CLIENT_ID: "your-client-id"
AZURE_CLIENT_SECRET: "your-client-secret"
AZURE_SUBSCRIPTION_ID: "your-subscription-id"
AZURE_TENANT_ID: "your-tenant-id"

# OpenTofu State Backend
TF_STATE_RESOURCE_GROUP: "rg-ppt-mcp-tfstate"
TF_STATE_STORAGE_ACCOUNT: "stpptmcptfstate12345678"
TF_STATE_CONTAINER: "tfstate"
```

#### Workflow Trigger

The GitHub Actions workflow (`.github/workflows/deploy.yml`) automatically triggers on:
- Push to `main` branch
- Manual workflow dispatch

## Configuration Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `location` | Azure region | `eastus` | No |
| `resource_group_name` | Resource group name | `rg-ppt-mcp` | No |
| `environment_name` | Environment name | `prod` | No |
| `github_username` | GitHub username | - | Yes |
| `github_token` | GitHub token | - | Yes |
| `container_image` | Container image URL | `ghcr.io/yourusername/ppt-mcp-server:latest` | No |
| `transport_mode` | Transport mode (`http` or `stdio`) | `http` | No |
| `log_level` | Log level | `INFO` | No |
| `container_cpu` | CPU allocation | `0.25` | No |
| `container_memory` | Memory allocation | `0.5Gi` | No |
| `replica_timeout` | Replica timeout (seconds) | `300` | No |
| `replica_retry_limit` | Retry limit | `1` | No |
| `tags` | Additional tags | `{}` | No |

## Management Commands

After deployment, use these commands to manage the Container Apps Job:

```bash
# Get deployment info
tofu output deployment_commands

# Start the job
az containerapp job start \
  --name $(tofu output -raw container_apps_job_name) \
  --resource-group $(tofu output -raw resource_group_name)

# View logs
az containerapp logs show \
  --name $(tofu output -raw container_apps_job_name) \
  --resource-group $(tofu output -raw resource_group_name) \
  --follow

# List executions
az containerapp job execution list \
  --name $(tofu output -raw container_apps_job_name) \
  --resource-group $(tofu output -raw resource_group_name) \
  --output table
```

## Modules

### monitoring

Creates a Log Analytics workspace for Container Apps logging.

**Inputs:**
- `workspace_name` - Name of the workspace
- `location` - Azure region
- `resource_group_name` - Resource group name
- `environment` - Environment name
- `tags` - Tags to apply

**Outputs:**
- `workspace_id` - Workspace ID
- `workspace_name` - Workspace name
- `primary_shared_key` - Primary shared key (sensitive)

### container-apps-env

Creates a Container Apps environment with logging integration.

**Inputs:**
- `environment_name` - Environment name
- `location` - Azure region
- `resource_group_name` - Resource group name
- `log_analytics_workspace_id` - Log Analytics workspace ID
- `log_analytics_primary_key` - Log Analytics primary key
- `environment` - Environment name
- `tags` - Tags to apply

**Outputs:**
- `id` - Environment ID
- `name` - Environment name
- `default_domain` - Default domain
- `static_ip_address` - Static IP address

### container-apps-job

Creates a Container Apps Job for running the PowerPoint MCP Server.

**Inputs:**
- `job_name` - Job name
- `location` - Azure region
- `resource_group_name` - Resource group name
- `container_app_environment_id` - Container Apps environment ID
- `container_image` - Container image
- `github_username` - GitHub username
- `github_token` - GitHub token (sensitive)
- `transport_mode` - Transport mode
- `log_level` - Log level
- `container_cpu` - CPU allocation
- `container_memory` - Memory allocation
- `replica_timeout` - Replica timeout
- `replica_retry_limit` - Retry limit
- `environment` - Environment name
- `tags` - Tags to apply

**Outputs:**
- `id` - Job ID
- `name` - Job name
- `event_stream_endpoint` - Event stream endpoint

## Troubleshooting

### Common Issues

#### State Lock Errors

```bash
# List locks
az storage blob list \
  --account-name $STORAGE_ACCOUNT_NAME \
  --container-name tfstate \
  --prefix terraform.tfstate

# Force unlock (use with caution)
tofu force-unlock <lock-id>
```

#### Authentication Errors

```bash
# Verify Azure login
az account show

# Re-authenticate
az login --service-principal \
  --username $AZURE_CLIENT_ID \
  --password $AZURE_CLIENT_SECRET \
  --tenant $AZURE_TENANT_ID
```

#### Module Errors

```bash
# Re-download modules
tofu get -update

# Validate configuration
tofu validate
```

#### Container Registry Issues

```bash
# Test GitHub token
echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_USERNAME --password-stdin

# Verify image exists
docker pull $CONTAINER_IMAGE
```

### Debug Mode

Enable detailed logging:

```bash
export TF_LOG=DEBUG
export TF_LOG_PATH=./terraform.log
tofu plan
```

### State Management

```bash
# View current state
tofu show

# List resources
tofu state list

# Refresh state
tofu refresh

# Import existing resource
tofu import module.monitoring.azurerm_log_analytics_workspace.main \
  /subscriptions/.../resourceGroups/.../providers/Microsoft.OperationalInsights/workspaces/ppt-mcp-logs
```

## Cost Optimization

### Free Tier Limits

- **Container Apps**: 180K vCPU-seconds, 360K GiB-seconds per month
- **Log Analytics**: 5GB ingestion, 7-day retention per month
- **Storage**: LRS with minimal usage for state files

### Monitor Usage

```bash
# Check current usage
az consumption usage list \
  --start-date $(date -d '1 month ago' '+%Y-%m-%d') \
  --end-date $(date '+%Y-%m-%d') \
  --query "[?contains(instanceName, 'ppt-mcp')]"

# Set up budget alerts (optional)
az consumption budget create \
  --budget-name ppt-mcp-budget \
  --amount 10 \
  --time-grain Monthly \
  --time-period startDate=$(date '+%Y-%m-01') \
  --notifications enabled=true thresholdType=Actual threshold=80
```

## Cleanup

To remove all resources:

```bash
# Destroy main infrastructure
tofu destroy

# Destroy state backend (optional)
cd bootstrap
tofu destroy
```

## Support

For issues:
1. Check the troubleshooting section above
2. Review OpenTofu/Terraform documentation
3. Check Azure Container Apps documentation
4. Review GitHub Actions workflow logs

## Security

- State files are encrypted at rest in Azure Storage
- GitHub tokens are marked as sensitive variables
- Service principal uses least-privilege access
- No secrets are stored in code repository