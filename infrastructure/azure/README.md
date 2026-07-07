# Azure infrastructure

AD419 deploys to Linux Azure App Service with Azure SQL databases and workspace-based Application Insights. GitHub Actions now owns CI/CD.

## GitHub Actions

`.github/workflows/ci-cd.yml` runs on pull requests to `main` and pushes to `main`.

Pull requests run build, server tests, client tests, package creation, and artifact upload. Pushes to `main` run the same validation and deploy to the `test` GitHub Environment. Production deploys are gated behind a manual `workflow_dispatch` run with `deploy_prod` enabled.

The reusable deploy workflow `.github/workflows/deploy-azure-appservice.yml` authenticates to Azure with GitHub OIDC, optionally deploys Bicep infrastructure, resolves `webAppName` from the deployment outputs, applies runtime app settings, and deploys the published zip with `azure/webapps-deploy`.

Set `DEPLOY_INFRA` to `false` in a GitHub Environment variable to skip the Bicep deployment before the app package deploy. Any value other than `false` deploys infrastructure.

## GitHub Environment configuration

Create GitHub Environments named `test` and `prod`.

Required repository variables:

- `TEST_AZURE_SUBSCRIPTION_ID`
- `PROD_AZURE_SUBSCRIPTION_ID`

Required environment variables:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `RESOURCE_GROUP`
- `LOCATION`
- `APP_NAME`
- `ENVIRONMENT`
- `DEPLOYMENT_NAME`
- `SQL_ADMIN_LOGIN`

Required environment secrets:

- `SQL_ADMIN_PASSWORD`

Optional environment variables and secrets:

- `DEPLOY_INFRA`
- `Notification__BaseUrl`
- `Smtp__Host`
- `Smtp__Port`
- `Smtp__Timeout`
- `Smtp__UseSsl`
- `Smtp__Username` (secret preferred when populated)
- `Smtp__Password` (secret)
- `Smtp__FromEmail`
- `Smtp__FromName`
- `Smtp__ReplyToEmail`
- `Smtp__BccEmail`
- `OTEL_EXPORTER_OTLP_ENDPOINT`
- `OTEL_EXPORTER_OTLP_HEADERS` (secret preferred when populated)
- `OTEL_EXPORTER_OTLP_PROTOCOL`

Suggested values:

| Environment | `AZURE_SUBSCRIPTION_ID` | `RESOURCE_GROUP` | `ENVIRONMENT` | `DEPLOYMENT_NAME` |
| --- | --- | --- | --- | --- |
| `test` | same as `TEST_AZURE_SUBSCRIPTION_ID` | `rg-ad419-test` | `test` | `ad419-test` |
| `prod` | same as `PROD_AZURE_SUBSCRIPTION_ID` | `rg-ad419-prod` | `prod` | `ad419-prod` |

The Bicep deployment creates an application database and a separate data database on the same SQL server. It sets `DB_CONNECTION`, `DATA_DB_CONNECTION`, `WEBSITE_RUN_FROM_PACKAGE`, Application Insights settings, and a default `Notification__BaseUrl`. The workflow can override notification, SMTP, and OTLP settings from GitHub Environment configuration.

## OIDC bootstrap

`github-oidc.bicep` bootstraps one environment in the active Azure subscription. Run it once against the test subscription and once against the prod subscription. This prevents a `-prod` resource group from being created in the test subscription, or a `-test` resource group from being created in the prod subscription.

For each environment, the bootstrap creates a Microsoft Entra app registration and service principal:

- `test` -> `ad419-github-test-deploy`
- `prod` -> `ad419-github-prod-deploy`

It also creates a federated credential for the corresponding GitHub Environment subject:

- `test` -> `repo:ucdavis/AD419:environment:test`
- `prod` -> `repo:ucdavis/AD419:environment:prod`

The service principal receives `Contributor` scoped only to its own resource group when `assignRbac` is `true`. The bootstrap ensures that environment's resource group exists. Resource group names default to `rg-ad419-test` and `rg-ad419-prod`.

The `deploymentGuardPassed` output must be `true`. If it is `false`, the active subscription, expected subscription, or resource group suffix did not match, and no environment resources were created.

Run the test bootstrap from a principal that can create Microsoft Entra applications and service principals and can assign Azure RBAC roles at the test resource group:

```bash
az account set --subscription "$TEST_AZURE_SUBSCRIPTION_ID"
az deployment sub create \
  --location westus2 \
  --template-file infrastructure/azure/github-oidc.bicep \
  --parameters location=westus2 env=test expectedSubscriptionId="$TEST_AZURE_SUBSCRIPTION_ID"
```

Run the prod bootstrap separately against the prod subscription:

```bash
az account set --subscription "$PROD_AZURE_SUBSCRIPTION_ID"
az deployment sub create \
  --location westus2 \
  --template-file infrastructure/azure/github-oidc.bicep \
  --parameters location=westus2 env=prod expectedSubscriptionId="$PROD_AZURE_SUBSCRIPTION_ID"
```

If you can create Entra applications but cannot assign Azure RBAC roles, run the identity/OIDC bootstrap first with `assignRbac=false`. Then have an Azure subscription Owner or User Access Administrator assign `Contributor` to the emitted `principalId` on that environment's resource group, or rerun the bootstrap with `assignRbac=true` from an account with those permissions.

If the resource groups use non-default names:

```bash
az deployment sub create \
  --location westus2 \
  --template-file infrastructure/azure/github-oidc.bicep \
  --parameters location=westus2 env=test expectedSubscriptionId="$TEST_AZURE_SUBSCRIPTION_ID" resourceGroupName='rg-ad419-test'
```

Use the deployment outputs to populate `AZURE_CLIENT_ID` in the corresponding GitHub Environment:

- test bootstrap `clientId` -> `test` environment `AZURE_CLIENT_ID`
- prod bootstrap `clientId` -> `prod` environment `AZURE_CLIENT_ID`

Set `AZURE_TENANT_ID` and `AZURE_SUBSCRIPTION_ID` in both environments. Set repository variables `TEST_AZURE_SUBSCRIPTION_ID` and `PROD_AZURE_SUBSCRIPTION_ID` so the deploy workflow can reject a mismatched environment/subscription pairing. `principalId` is output for auditing and troubleshooting RBAC.

The bootstrap uses the Microsoft Graph Bicep extension configured in `bicepconfig.json`. The first build or deployment may restore the extension from Microsoft Container Registry.

## Local infra deployment

Log in and deploy test:

```bash
az login
export SQL_ADMIN_PASSWORD='your-strong-password'
export TEST_AZURE_SUBSCRIPTION_ID='00000000-0000-0000-0000-000000000000'
./infrastructure/azure/scripts/deploy_test.sh
```

Deploy prod:

```bash
az login
export SQL_ADMIN_PASSWORD='your-strong-password'
export PROD_AZURE_SUBSCRIPTION_ID='00000000-0000-0000-0000-000000000000'
./infrastructure/azure/scripts/deploy_prod.sh
```

You can override defaults by exporting `SUBSCRIPTION_ID`, `SUBSCRIPTION_NAME`, `RESOURCE_GROUP`, `LOCATION`, `SQL_ADMIN_LOGIN`, or `NOTIFICATION_BASE_URL` before running either wrapper. The scripts still require the matching `TEST_AZURE_SUBSCRIPTION_ID` or `PROD_AZURE_SUBSCRIPTION_ID` value and reject mismatched `RESOURCE_GROUP`, `ENVIRONMENT`, and active subscription combinations before creating a resource group.

## Validation

Build the app infrastructure:

```bash
az bicep build --file infrastructure/azure/main.bicep
```

Build the OIDC bootstrap:

```bash
az bicep build --file infrastructure/azure/github-oidc.bicep
```
