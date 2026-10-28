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

Repository secret used by datamart imports:

- `DATAMART_CONNECTION` contains the Roberto SQL connection string. Both deployment jobs inherit this repository-level secret through `secrets: inherit`, and the deployment workflow copies it to the App Service setting. An environment-level secret with the same name can override it, but separate test and prod secrets are not required.

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

CAES AI is optional; to enable it, supply all four settings. See [CAES AI configuration](#caes-ai-configuration).

Optional environment variables and secrets:

- `DEPLOY_INFRA`
- `MANAGE_DATAMART_RELAY` (defaults to `false`; set to `true` to manage the Hybrid Connection attachment and retrieve its sender key)
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

## CAES AI configuration

To enable the assistant in a `test` or `prod` GitHub Environment, supply all four settings before deployment. Leave all four absent to deploy with the assistant disabled:

| GitHub Environment setting | Type | Purpose |
| --- | --- | --- |
| `CaesAi__ServerUrl` | Variable | Central CAES AI HTTPS service URL |
| `CaesAi__ApplicationId` | Variable | Dedicated registration ID, such as `ad419-test` or `ad419-prod` |
| `CaesAi__ApplicationApiKey` | Secret | API key issued for that registration |
| `CaesAi__ContextSigningKey` | Secret | Application-owned random secret, at least 32 characters |

Create separate registrations and keys for each deployed environment. For local development, see the [Expense Review assistant guide](../../docs/expense-review-assistant.md). The shared CAES AI service currently documents only test hosting; choose and authorize the appropriate central service before configuring production. Do not copy local developer keys into GitHub.

Reuse the environment's existing registration and matching API key if already provisioned. Create a registration only when one does not exist. An administrator runs the following commands inside the chosen CAES AI service's App Service container:

```bash
cd /home/site/wwwroot/apps/ai-server
node dist/cli.js app create ad419-test \
  --display-name "AD419 test" \
  --callback-url https://<ad419-test-host>/api/ai/tools/execute \
  --origin https://<ad419-test-host> \
  --model gpt-5.6-luna --max-reasoning none
```

For production, use its dedicated application ID and actual callback/browser origins. The CLI prints the API key once. Use `app update` only for the intended environment's registration, with that deployed AD419 application's callback URL and browser origin. If a key is lost, `app rotate-key` issues a replacement while leaving previous keys active. These CLI commands apply CAES AI's checked-in migrations as part of normal administration.

From the local AD419 checkout, set the nonsecret values and pipe secrets through stdin so they do not appear in shell history or command arguments:

```bash
gh variable set CaesAi__ServerUrl --env test --body https://<central-service-host>
gh variable set CaesAi__ApplicationId --env test --body ad419-test
# Paste the issued API key into gh's hidden prompt:
gh secret set CaesAi__ApplicationApiKey --env test
openssl rand -base64 48 | gh secret set CaesAi__ContextSigningKey --env test
```

Repeat for `--env prod` with production's values. Generate the context-signing key once and preserve it; do not regenerate it on every deployment.

Registration is a one-time administrative step per environment. Subsequent deployments reuse the saved credentials without registering applications or rotating keys.

The workflow accepts all four settings absent, or validates that all four are supplied and the signing key contains at least 32 characters before deploying infrastructure. Errors identify setting names without printing values. It restores them with the other runtime settings after Bicep and before deploying the application package, including when `DEPLOY_INFRA=false`. Bicep's App Service settings collection replaces manual settings, so configuring them only in the Azure portal is insufficient. Partial configuration fails deployment. When all four are absent, the workflow explicitly writes empty values for all four runtime settings so stale Azure configuration cannot leave the assistant enabled.

After provisioning both environments, verify the assistant before and after an infrastructure-enabled test deployment.

## OIDC bootstrap

`github-oidc.bicep` bootstraps one environment in the active Azure subscription. Run it once against the test subscription and once against the prod subscription. This prevents a `-prod` resource group from being created in the test subscription, or a `-test` resource group from being created in the prod subscription.

For each environment, the bootstrap creates a user-assigned managed identity in the application resource group:

- `test` -> `id-ad419-test-deploy`
- `prod` -> `id-ad419-prod-deploy`

It also creates a federated credential for the corresponding GitHub Environment subject:

- `test` -> `repo:ucdavis/AD419:environment:test`
- `prod` -> `repo:ucdavis/AD419:environment:prod`

With `assignRbac=true`, the identity receives `Contributor` on its application resource group, `Website Contributor` on the exact shared App Service plan, and the scoped datamart relay permissions described below. The bootstrap creates `rg-ad419-test` or `rg-ad419-prod` by default.

Both bootstrap and app infrastructure use existing plans: test uses `DefaultPlan2` in `Default-Web-WestUS`; prod uses `Nibbler` in `service-plans-linux`. To override, pass `webPlanName` and `webPlanResourceGroup` to the bootstrap and set matching `WEB_PLAN_NAME` and `WEB_PLAN_RESOURCE_GROUP` deployment variables. The web app uses the plan's region; SQL and monitoring use `LOCATION`.

The `deploymentGuardPassed` output must be `true`. Otherwise, check the repository, expected subscription, active subscription, and resource group suffix; no environment resources were created.

Run the test bootstrap from a principal that can create resource groups and managed identities, assign Azure RBAC roles on the application resource group and shared plan, and deploy into the existing relay resource group. It also needs `Microsoft.Authorization/roleAssignments/write` at the Hybrid Connection and sender-rule scopes. The GitHub deployment identity does not grant these permissions to itself.

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

With `assignRbac=false`, the bootstrap skips role assignments; existing assignments are not revoked.

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

## Datamart Hybrid Connection

Test and production attach their App Service to an existing Azure Relay Hybrid Connection. The shared mapping in `hybrid-connections.json` is loaded by both `main.bicep` and `github-oidc.bicep`, so the attachment and bootstrap permissions use the same resources. All relay resources are in the environment's subscription and resource group `Default-Web-WestUS`.

| Environment | Namespace | Hybrid Connection | Sender rule | Endpoint |
| --- | --- | --- | --- | --- |
| `test` | `testserver-tsql` | `caes-roberto-test` | `defaultSender` | `caes-roberto:1433` |
| `prod` | `prodserver-tsql` | `caes-roberto` | `defaultSender` | `caes-roberto:1433` |

The templates reference the namespace, connection, and authorization rule as existing resources. They do not create or change the shared relays, rotate keys, or configure the on-premises Hybrid Connection Manager (HCM). `dev` creates no attachment and does not evaluate `listKeys`; failed deployment guards skip the compute module entirely.

Bicep configures the Hybrid Connection attachment and retrieves its relay Send key only when `manageDatamartRelay=true`. Otherwise, configure the attachment separately; existing attachments are preserved. It does not generate `DATAMART_CONNECTION` or the SQL credentials for Roberto. Keep `Server=caes-roberto,1433` in the repository-level `DATAMART_CONNECTION` secret (or an environment override, if configured). The workflow copies that existing secret into the App Service setting after infrastructure deployment. The hostname and port must match the relay endpoint exactly; switching to the FQDN would bypass these short-name attachments. The separate FQDN relay in test is not used. No VNet integration is required for this connection.

### Relay permissions and key handling

The bootstrap grants the deployment identity:

- Built-in `Reader` on the exact Hybrid Connection.
- Built-in `Azure Relay Owner` on only its `defaultSender` authorization rule. This permits reading the rule's keys, modifying its permissions, deleting the rule, and rotating its keys. The Owner assignment does not extend to the parent Hybrid Connection, namespace, or sibling authorization rules.

Both assignments use deterministic names derived from their scope, principal, and built-in role ID. Bootstrap outputs include `relayReaderRoleAssignmentId` and `relaySenderRuleOwnerRoleAssignmentId` for auditing, with empty values when RBAC is skipped.

When attachment management is enabled, the app deployment calls `listKeys().primaryKey` directly for the existing sender rule and supplies it to the App Service attachment's `sendKeyValue`. It never emits the key as an output or stores it in GitHub secrets. The App Service managed identity does not need these bootstrap permissions.

### Troubleshooting

- `AuthorizationFailed` on `listKeys`: verify the GitHub deployment identity has `Azure Relay Owner` on the environment's exact `defaultSender` rule, and that the bootstrap ran with `assignRbac=true` in the correct subscription.
- Attachment disconnected or no listeners: have the HCM operator check the existing listener service, its outbound Azure Relay connectivity, and its ability to resolve and reach `caes-roberto:1433`. Do not recreate the shared relay.
- DNS failure persists: verify infrastructure deployment was enabled, the attachment exists on this App Service, and `DATAMART_CONNECTION` uses the matching short hostname and port.
- Attachment connected but SQL fails: investigate SQL reachability from HCM, authentication, and then the linked-server query separately.

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
