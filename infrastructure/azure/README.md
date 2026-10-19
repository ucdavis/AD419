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

With `assignRbac=true`, the identity receives `Contributor` on its application resource group, `Website Contributor` on the exact shared App Service plan, and the scoped datamart relay permissions described below. The bootstrap creates `rg-ad419-test` or `rg-ad419-prod` by default.

Both bootstrap and app infrastructure use existing plans: test uses `DefaultPlan2` in `Default-Web-WestUS`; prod uses `Nibbler` in `service-plans-linux`. To override, pass `webPlanName` and `webPlanResourceGroup` to the bootstrap and set matching `WEB_PLAN_NAME` and `WEB_PLAN_RESOURCE_GROUP` deployment variables. The web app uses the plan's region; SQL and monitoring use `LOCATION`.

The `deploymentGuardPassed` output must be `true`. Otherwise, check the repository, expected subscription, active subscription, and resource group suffix; no environment resources were created.

Run the test bootstrap from a principal that can create resource groups and managed identities, assign Azure RBAC roles on the application resource group and shared plan, and deploy into the existing relay resource group. It also needs `Microsoft.Authorization/roleDefinitions/write` in the relay resource group and `Microsoft.Authorization/roleAssignments/write` at the Hybrid Connection and sender-rule scopes. The GitHub deployment identity does not grant these permissions to itself.

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

If you cannot provision RBAC, use `assignRbac=false`, then have an authorized administrator rerun with `assignRbac=true` before application deployment. With `assignRbac=false`, the bootstrap creates neither role assignments nor the custom relay key-reader role; existing assignments are not revoked.

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

Bicep configures the Hybrid Connection attachment and retrieves its relay Send key. It does not generate `DATAMART_CONNECTION` or the SQL credentials for Roberto. Keep `Server=caes-roberto,1433` in the repository-level `DATAMART_CONNECTION` secret (or an environment override, if configured). The workflow copies that existing secret into the App Service setting after infrastructure deployment. The hostname and port must match the relay endpoint exactly; switching to the FQDN would bypass these short-name attachments. The separate FQDN relay in test is not used. No VNet integration is required for this connection.

### Relay permissions and key handling

The bootstrap grants the deployment identity:

- Built-in `Reader` on the exact Hybrid Connection.
- A custom Send Key Reader role on only its `defaultSender` authorization rule. Its sole action is `Microsoft.Relay/namespaces/HybridConnections/authorizationRules/listkeys/action`; the role's assignable scope is limited to the relay resource group. It does not grant access to listener keys or permission to change the relay, authorization rules, or keys.

The custom role and both assignments use deterministic names. Bootstrap outputs include `relayReaderRoleAssignmentId` and `relaySenderKeyReaderRoleAssignmentId` for auditing, with empty values when RBAC is skipped.

The app deployment calls `listKeys().primaryKey` directly for the existing sender rule and supplies it to the App Service attachment's `sendKeyValue`. It never emits the key as an output or stores it in GitHub secrets. The App Service managed identity does not need these bootstrap permissions. After an externally managed sender-key rotation, rerun the infrastructure deployment to refresh the attachment; `DEPLOY_INFRA=false` will not refresh it. Coordinate any shared key rotation with the other applications using that rule.

### Rollout and verification

These are operator-run steps requiring separate authorization; compiling templates does not deploy them.

1. Start with test. Review the bootstrap with `az deployment sub what-if` using the same location and parameters as the bootstrap command above. Review the application with `az deployment group what-if` using the parameters from `scripts/deploy.sh`, including the existing SQL configuration. Use an operator with relay-key read permission for that initial preview. Keep secrets out of captured output and use `--result-format ResourceIdOnly` when sharing the preview.
2. Apply the test bootstrap with `assignRbac=true`. This must precede the first application deployment using the attachment. If Azure reports an authorization propagation error, verify the assignment and retry after it becomes effective; do not broaden the role to work around it.
3. Deploy through the normal test workflow with infrastructure enabled. The new resources should be the app attachment and bootstrap RBAC resources; the shared relays, authorization rules, and HCM remain unchanged. Review any unrelated what-if differences before applying.
4. Confirm the App Service attachment shows **Connected**. From the application environment, verify SQL authentication to `master` and run a small read-only query through `AE_Redshift_PROD` before retrying the PGM import. A connected listener alone does not prove SQL reachability, credentials, or linked-server permissions.
5. Run an authorized PGM import in test and verify completion and imported data. Repeat the reviewed bootstrap and deployment process for production, with read-only connectivity checks before an explicitly authorized production import retry.
6. Redeploy to verify the same attachment and assignments are reused without creating duplicates.

### Troubleshooting and rollback

- `AuthorizationFailed` on `listKeys`: verify the GitHub deployment identity has the custom role on the environment's exact `defaultSender` rule, and that the bootstrap ran with `assignRbac=true` in the correct subscription.
- Attachment disconnected or no listeners: have the HCM operator check the existing listener service, its outbound Azure Relay connectivity, and its ability to resolve and reach `caes-roberto:1433`. Do not recreate the shared relay.
- DNS failure persists: verify infrastructure deployment was enabled, the attachment exists on this App Service, and `DATAMART_CONNECTION` uses the matching short hostname and port.
- Attachment connected but SQL fails: investigate SQL reachability from HCM, authentication, and then the linked-server query separately.

Rollback requires explicitly detaching only AD419's App Service attachment and reverting the attachment template change before the next deployment. Removing a Bicep declaration does not delete the resource during incremental deployment. Preserve the shared relay, sender/listener rules, and on-premises listener. If access is no longer needed, separately review removal of AD419's scoped relay role assignments; do not delete a custom role while other assignments use it.

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
