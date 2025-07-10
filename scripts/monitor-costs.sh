#!/bin/bash

# Cost Monitoring Script for PowerPoint MCP Server on Azure Container Apps
# This script helps monitor Azure costs and usage to stay within free tier limits

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
RESOURCE_GROUP="rg-ppt-mcp"
CONTAINER_ENV="ppt-mcp-env"
DAYS_BACK=30

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check Azure CLI and login
check_prerequisites() {
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed"
        exit 1
    fi
    
    if ! az account show &> /dev/null; then
        log_error "Not logged in to Azure. Please run 'az login'"
        exit 1
    fi
}

# Get subscription information
get_subscription_info() {
    log_step "Getting subscription information..."
    
    SUBSCRIPTION_ID=$(az account show --query id --output tsv)
    SUBSCRIPTION_NAME=$(az account show --query name --output tsv)
    
    log_info "Subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"
}

# Monitor Container Apps usage
monitor_container_apps_usage() {
    log_step "Monitoring Container Apps usage..."
    
    # Get Container Apps in the resource group
    APPS=$(az containerapp list --resource-group "$RESOURCE_GROUP" --query "[].{Name:name,Status:properties.runningStatus}" --output table 2>/dev/null || echo "No apps found")
    
    if [[ "$APPS" == "No apps found" ]]; then
        log_warn "No Container Apps found in resource group $RESOURCE_GROUP"
    else
        log_info "Container Apps status:"
        echo "$APPS"
    fi
    
    # Get Container Apps Jobs
    JOBS=$(az containerapp job list --resource-group "$RESOURCE_GROUP" --query "[].{Name:name,Status:properties.runningStatus}" --output table 2>/dev/null || echo "No jobs found")
    
    if [[ "$JOBS" == "No jobs found" ]]; then
        log_warn "No Container Apps Jobs found in resource group $RESOURCE_GROUP"
    else
        log_info "Container Apps Jobs status:"
        echo "$JOBS"
    fi
}

# Get cost information
get_cost_information() {
    log_step "Getting cost information for the last $DAYS_BACK days..."
    
    START_DATE=$(date -d "$DAYS_BACK days ago" +%Y-%m-%d)
    END_DATE=$(date +%Y-%m-%d)
    
    log_info "Cost analysis period: $START_DATE to $END_DATE"
    
    # Get costs for the resource group
    COSTS=$(az consumption usage list \
        --start-date "$START_DATE" \
        --end-date "$END_DATE" \
        --query "[?contains(instanceName, 'ppt-mcp') || contains(meterName, 'Container Apps')]" \
        --output table 2>/dev/null || echo "No cost data available")
    
    if [[ "$COSTS" == "No cost data available" ]]; then
        log_warn "No cost data available for the specified period"
        log_info "This is normal for new deployments or free tier usage"
    else
        log_info "Cost breakdown:"
        echo "$COSTS"
    fi
}

# Check free tier limits
check_free_tier_limits() {
    log_step "Checking free tier limits..."
    
    # Container Apps free tier limits
    VCPU_LIMIT=180000  # vCPU seconds per month
    MEMORY_LIMIT=360000  # GiB seconds per month
    REQUEST_LIMIT=2000000  # requests per month
    
    log_info "Container Apps free tier limits:"
    echo "  - vCPU: $VCPU_LIMIT seconds/month"
    echo "  - Memory: $MEMORY_LIMIT GiB-seconds/month"
    echo "  - Requests: $REQUEST_LIMIT requests/month"
    echo
    
    # Calculate usage for a basic deployment
    CPU_CORES=0.25
    MEMORY_GB=0.5
    HOURS_PER_DAY=24
    DAYS_PER_MONTH=30
    
    MONTHLY_VCPU_USAGE=$(echo "$CPU_CORES * $HOURS_PER_DAY * 3600 * $DAYS_PER_MONTH" | bc)
    MONTHLY_MEMORY_USAGE=$(echo "$MEMORY_GB * $HOURS_PER_DAY * 3600 * $DAYS_PER_MONTH" | bc)
    
    log_info "Estimated monthly usage (24/7 deployment):"
    echo "  - vCPU: $MONTHLY_VCPU_USAGE seconds/month"
    echo "  - Memory: $MONTHLY_MEMORY_USAGE GiB-seconds/month"
    echo
    
    # Check if usage exceeds free tier
    if (( $(echo "$MONTHLY_VCPU_USAGE > $VCPU_LIMIT" | bc -l) )); then
        log_warn "vCPU usage exceeds free tier limit!"
        VCPU_OVERAGE=$(echo "$MONTHLY_VCPU_USAGE - $VCPU_LIMIT" | bc)
        log_warn "Overage: $VCPU_OVERAGE vCPU seconds"
    else
        log_info "vCPU usage within free tier limits ✅"
    fi
    
    if (( $(echo "$MONTHLY_MEMORY_USAGE > $MEMORY_LIMIT" | bc -l) )); then
        log_warn "Memory usage exceeds free tier limit!"
        MEMORY_OVERAGE=$(echo "$MONTHLY_MEMORY_USAGE - $MEMORY_LIMIT" | bc)
        log_warn "Overage: $MEMORY_OVERAGE GiB-seconds"
    else
        log_info "Memory usage within free tier limits ✅"
    fi
}

# Get Log Analytics usage
monitor_log_analytics() {
    log_step "Monitoring Log Analytics usage..."
    
    LOG_WORKSPACE="ppt-mcp-logs"
    
    # Get workspace information
    if az monitor log-analytics workspace show --resource-group "$RESOURCE_GROUP" --workspace-name "$LOG_WORKSPACE" &> /dev/null; then
        log_info "Log Analytics workspace: $LOG_WORKSPACE"
        
        # Get usage statistics (if available)
        USAGE=$(az monitor log-analytics workspace get-usage \
            --resource-group "$RESOURCE_GROUP" \
            --workspace-name "$LOG_WORKSPACE" \
            --output table 2>/dev/null || echo "Usage data not available")
        
        if [[ "$USAGE" == "Usage data not available" ]]; then
            log_warn "Log Analytics usage data not available"
        else
            log_info "Log Analytics usage:"
            echo "$USAGE"
        fi
        
        # Free tier limit is 5GB per month
        log_info "Log Analytics free tier limit: 5 GB per month"
    else
        log_warn "Log Analytics workspace not found"
    fi
}

# Provide cost optimization recommendations
provide_recommendations() {
    log_step "Cost optimization recommendations..."
    
    log_info "To minimize costs and stay within free tier:"
    echo "  1. Use Container Apps Jobs instead of always-on Container Apps"
    echo "  2. Set minimum replicas to 0 for HTTP mode apps"
    echo "  3. Use the smallest CPU (0.25 cores) and memory (0.5 GB) allocation"
    echo "  4. Monitor Log Analytics usage to stay under 5GB/month"
    echo "  5. Consider using GitHub Container Registry for image storage"
    echo "  6. Set up cost alerts for early warning"
    echo
    
    log_info "Cost monitoring commands:"
    echo "  # Check daily costs"
    echo "  az consumption usage list --start-date \$(date -d '1 day ago' +%Y-%m-%d) --end-date \$(date +%Y-%m-%d)"
    echo
    echo "  # Check monthly budget"
    echo "  az consumption budget list --resource-group $RESOURCE_GROUP"
    echo
    echo "  # Stop all Container Apps to save costs"
    echo "  az containerapp list --resource-group $RESOURCE_GROUP --query '[].name' -o tsv | xargs -I {} az containerapp update --name {} --resource-group $RESOURCE_GROUP --min-replicas 0 --max-replicas 0"
}

# Generate cost report
generate_cost_report() {
    log_step "Generating cost report..."
    
    REPORT_FILE="cost-report-$(date +%Y%m%d).txt"
    
    {
        echo "PowerPoint MCP Server - Cost Report"
        echo "Generated: $(date)"
        echo "Resource Group: $RESOURCE_GROUP"
        echo "Subscription: $SUBSCRIPTION_NAME"
        echo "================================="
        echo
        
        echo "Container Apps Status:"
        az containerapp list --resource-group "$RESOURCE_GROUP" --query "[].{Name:name,Status:properties.runningStatus,CPU:properties.template.containers[0].resources.cpu,Memory:properties.template.containers[0].resources.memory}" --output table 2>/dev/null || echo "No apps found"
        echo
        
        echo "Container Apps Jobs Status:"
        az containerapp job list --resource-group "$RESOURCE_GROUP" --query "[].{Name:name,Status:properties.runningStatus}" --output table 2>/dev/null || echo "No jobs found"
        echo
        
        echo "Free Tier Limits Check:"
        echo "- vCPU: $VCPU_LIMIT seconds/month"
        echo "- Memory: $MEMORY_LIMIT GiB-seconds/month"
        echo "- Requests: $REQUEST_LIMIT requests/month"
        echo "- Log Analytics: 5 GB/month"
        echo
        
        echo "Estimated Monthly Usage (24/7):"
        echo "- vCPU: $MONTHLY_VCPU_USAGE seconds/month"
        echo "- Memory: $MONTHLY_MEMORY_USAGE GiB-seconds/month"
        echo
        
        echo "Cost Optimization Status:"
        if (( $(echo "$MONTHLY_VCPU_USAGE > $VCPU_LIMIT" | bc -l) )); then
            echo "⚠️  vCPU usage exceeds free tier"
        else
            echo "✅ vCPU usage within free tier"
        fi
        
        if (( $(echo "$MONTHLY_MEMORY_USAGE > $MEMORY_LIMIT" | bc -l) )); then
            echo "⚠️  Memory usage exceeds free tier"
        else
            echo "✅ Memory usage within free tier"
        fi
        
    } > "$REPORT_FILE"
    
    log_info "Cost report saved to: $REPORT_FILE"
}

# Main execution
main() {
    log_info "PowerPoint MCP Server - Cost Monitoring"
    log_info "======================================="
    
    check_prerequisites
    get_subscription_info
    monitor_container_apps_usage
    get_cost_information
    check_free_tier_limits
    monitor_log_analytics
    provide_recommendations
    generate_cost_report
    
    log_info "Cost monitoring completed!"
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Cost Monitoring Script for PowerPoint MCP Server"
        echo
        echo "Usage: $0 [OPTIONS]"
        echo
        echo "Options:"
        echo "  -h, --help     Show this help message"
        echo "  --report       Generate detailed cost report"
        echo "  --limits       Show only free tier limits check"
        echo "  --usage        Show only current usage"
        echo "  --stop-all     Stop all Container Apps to save costs"
        echo
        exit 0
        ;;
    --report)
        check_prerequisites
        get_subscription_info
        generate_cost_report
        exit 0
        ;;
    --limits)
        check_free_tier_limits
        exit 0
        ;;
    --usage)
        check_prerequisites
        monitor_container_apps_usage
        exit 0
        ;;
    --stop-all)
        log_warn "This will stop all Container Apps in $RESOURCE_GROUP"
        echo -e "${RED}Are you sure? (y/n)${NC}"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            az containerapp list --resource-group "$RESOURCE_GROUP" --query '[].name' -o tsv | \
            xargs -I {} az containerapp update --name {} --resource-group "$RESOURCE_GROUP" --min-replicas 0 --max-replicas 0
            log_info "All Container Apps stopped"
        fi
        exit 0
        ;;
    "")
        main
        ;;
    *)
        log_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac