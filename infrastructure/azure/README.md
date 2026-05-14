# Azure infrastructure

AD419 deploys to Azure App Service with Azure SQL Database and workspace-based Application Insights.

## Pipeline

The root `azure-pipelines.yml` builds and tests pull requests. Pushes to `main` deploy to test, then prod.

Infrastructure deployment is enabled by default and follows the `../readable` pattern:

- `deployInfra` defaults to `"true"`.
- Set `deployInfra` to `"false"` in the pipeline or an environment variable group to skip the Bicep deployment before the app package deploy.

## Azure DevOps variable groups

Create these variable groups:

- `ad419-test`
- `ad419-prod`

Required variables:

- `RESOURCE_GROUP`
- `LOCATION`
- `APP_NAME`
- `ENVIRONMENT`
- `DEPLOYMENT_NAME`
- `SQL_ADMIN_LOGIN`
- `SQL_ADMIN_PASSWORD` (secret)

Optional variables:

- `Notification__BaseUrl`
- `Smtp__Host`
- `Smtp__Port`
- `Smtp__Timeout`
- `Smtp__UseSsl`
- `Smtp__Username` (secret when populated)
- `Smtp__Password` (secret when populated)
- `Smtp__FromEmail`
- `Smtp__FromName`
- `Smtp__ReplyToEmail`
- `Smtp__BccEmail`
- `OTEL_EXPORTER_OTLP_ENDPOINT`
- `OTEL_EXPORTER_OTLP_HEADERS` (secret when populated)
- `OTEL_EXPORTER_OTLP_PROTOCOL`

The Bicep deployment sets `DB_CONNECTION`, `WEBSITE_RUN_FROM_PACKAGE`, Application Insights settings, and a default `Notification__BaseUrl`. The pipeline can override notification, SMTP, and OTLP settings from variable groups.

## Local infra deployment

Log in and deploy test:

```bash
az login
export SQL_ADMIN_PASSWORD='your-strong-password'
./infrastructure/azure/scripts/deploy_test.sh
```

Deploy prod:

```bash
az login
export SQL_ADMIN_PASSWORD='your-strong-password'
./infrastructure/azure/scripts/deploy_prod.sh
```

You can override defaults by exporting `SUBSCRIPTION_ID`, `SUBSCRIPTION_NAME`, `RESOURCE_GROUP`, `LOCATION`, `SQL_ADMIN_LOGIN`, or `NOTIFICATION_BASE_URL` before running either wrapper.

## Validate Bicep

```bash
az bicep build --file infrastructure/azure/main.bicep
```
