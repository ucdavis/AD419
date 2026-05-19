#!/usr/bin/env bash
set -euo pipefail

if ! command -v az >/dev/null 2>&1; then
  echo "Azure CLI (az) is required but was not found on PATH." >&2
  exit 1
fi

if ! az account show >/dev/null 2>&1; then
  echo "You must run 'az login' (or use a service principal) before running this script." >&2
  exit 1
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
BICEP_FILE="$SCRIPT_DIR/../main.bicep"

required_vars=(
  DEPLOYMENT_NAME
  RESOURCE_GROUP
  LOCATION
  APP_NAME
  ENVIRONMENT
  SQL_ADMIN_LOGIN
  SQL_ADMIN_PASSWORD
)

missing_vars=()
for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    missing_vars+=("$var")
  fi
done

if (( ${#missing_vars[@]} > 0 )); then
  echo "Missing required environment variables: ${missing_vars[*]}" >&2
  exit 1
fi

if [[ "$ENVIRONMENT" != "test" && "$ENVIRONMENT" != "prod" ]]; then
  echo "ENVIRONMENT must be either 'test' or 'prod' for Azure deployments." >&2
  exit 1
fi

if [[ -n "${EXPECTED_ENVIRONMENT:-}" && "$ENVIRONMENT" != "$EXPECTED_ENVIRONMENT" ]]; then
  echo "ENVIRONMENT '$ENVIRONMENT' does not match EXPECTED_ENVIRONMENT '$EXPECTED_ENVIRONMENT'." >&2
  exit 1
fi

expected_resource_group_suffix="-$ENVIRONMENT"
if [[ "$RESOURCE_GROUP" != *"$expected_resource_group_suffix" ]]; then
  echo "RESOURCE_GROUP '$RESOURCE_GROUP' must end with '$expected_resource_group_suffix' for ENVIRONMENT '$ENVIRONMENT'." >&2
  exit 1
fi

if [[ -z "${EXPECTED_SUBSCRIPTION_ID:-}" ]]; then
  echo "EXPECTED_SUBSCRIPTION_ID is required so $ENVIRONMENT deployments can be pinned to the correct Azure subscription." >&2
  exit 1
fi

subscription_value=""
subscription_label=""

if [[ -n "${SUBSCRIPTION_ID:-}" ]]; then
  subscription_value="$SUBSCRIPTION_ID"
  subscription_label=${SUBSCRIPTION_NAME:-}
elif [[ -n "${SUBSCRIPTION_NAME:-}" ]]; then
  subscription_value="$SUBSCRIPTION_NAME"
fi

if [[ -n "$subscription_value" ]]; then
  if [[ -n "$subscription_label" ]]; then
    echo "Setting Azure subscription to $subscription_label ($subscription_value)..."
  else
    echo "Setting Azure subscription to $subscription_value..."
  fi
  az account set --subscription "$subscription_value"
fi

current_subscription_id=$(az account show --query id --output tsv)
if [[ "$current_subscription_id" != "$EXPECTED_SUBSCRIPTION_ID" ]]; then
  echo "Current Azure subscription '$current_subscription_id' does not match EXPECTED_SUBSCRIPTION_ID '$EXPECTED_SUBSCRIPTION_ID' for ENVIRONMENT '$ENVIRONMENT'." >&2
  exit 1
fi

echo "Ensuring resource group $RESOURCE_GROUP exists in $LOCATION..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none

echo "Deploying AD419 resources in $RESOURCE_GROUP..."
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DEPLOYMENT_NAME" \
  --template-file "$BICEP_FILE" \
  --parameters appName="$APP_NAME" env="$ENVIRONMENT" location="$LOCATION" \
  --parameters expectedSubscriptionId="$EXPECTED_SUBSCRIPTION_ID" \
  --parameters sqlAdminLogin="$SQL_ADMIN_LOGIN" sqlAdminPassword="$SQL_ADMIN_PASSWORD" \
  --parameters notificationBaseUrl="${NOTIFICATION_BASE_URL:-}" \
  --output table

echo "Deployment complete."
