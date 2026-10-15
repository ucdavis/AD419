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
- `WEB_PLAN_NAME` and `WEB_PLAN_RESOURCE_GROUP` (set both or neither)
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

For each environment, the bootstrap creates a user-assigned managed identity in the application resource group:

- `test` -> `id-ad419-test-deploy`
- `prod` -> `id-ad419-prod-deploy`

It also creates a federated credential for the corresponding GitHub Environment subject:

- `test` -> `repo:ucdavis/AD419:environment:test`
- `prod` -> `repo:ucdavis/AD419:environment:prod`

With `assignRbac=true`, the identity receives `Contributor` on its application resource group and `Website Contributor` on the exact shared App Service plan. The bootstrap creates `rg-ad419-test` or `rg-ad419-prod` by default.

Both bootstrap and app infrastructure use existing plans: test uses `DefaultPlan2` in `Default-Web-WestUS`; prod uses `Nibbler` in `service-plans-linux`. To override, pass `webPlanName` and `webPlanResourceGroup` to the bootstrap and set matching `WEB_PLAN_NAME` and `WEB_PLAN_RESOURCE_GROUP` deployment variables. The web app uses the plan's region; SQL and monitoring use `LOCATION`.

The `deploymentGuardPassed` output must be `true`. Otherwise, check the repository, expected subscription, active subscription, and resource group suffix; no environment resources were created.

Run the test bootstrap from a principal that can create resource groups and managed identities and assign Azure RBAC roles on the application resource group and shared plan:

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

If you cannot assign RBAC roles, use `assignRbac=false`, then have an authorized administrator grant the emitted `principalId` both roles at the scopes above or rerun with `assignRbac=true`.

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

Use the `tenantId` and `subscriptionId` outputs for `AZURE_TENANT_ID` and `AZURE_SUBSCRIPTION_ID`. Keep repository variables `TEST_AZURE_SUBSCRIPTION_ID` and `PROD_AZURE_SUBSCRIPTION_ID` for independent subscription checks. Identity name, principal ID, federation subject, and role-assignment IDs are also output for auditing.

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

You can override defaults by exporting `SUBSCRIPTION_ID`, `SUBSCRIPTION_NAME`, `RESOURCE_GROUP`, `LOCATION`, `SQL_ADMIN_LOGIN`, `NOTIFICATION_BASE_URL`, or both shared-plan variables before running either wrapper. The scripts still require the matching `TEST_AZURE_SUBSCRIPTION_ID` or `PROD_AZURE_SUBSCRIPTION_ID` value and reject mismatched `RESOURCE_GROUP`, `ENVIRONMENT`, and active subscription combinations before creating a resource group.

## Validation

Build the app infrastructure:

```bash
az bicep build --file infrastructure/azure/main.bicep
```

Build the OIDC bootstrap:

```bash
az bicep build --file infrastructure/azure/github-oidc.bicep
```
