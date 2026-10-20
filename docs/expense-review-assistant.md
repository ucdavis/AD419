# Expense Review assistant: local development

The Expense Review stage embeds a CAES AI chat drawer. Locally, ad419 talks to the shared CAES AI **test** instance in Azure, and that instance calls back into your machine through a Microsoft dev tunnel when the model uses a server tool.

## One-time setup

1. **Remove UCPath rows from your local data database** so only Aggie Enterprise rows can reach the model:

   ```sql
   DELETE FROM data.UcPathTransactions;
   ```

2. **Create a dev tunnel** to the ASP.NET Core port (not Vite):

   ```bash
   brew install --cask devtunnel
   devtunnel user login
   devtunnel create ad419-dev --allow-anonymous
   devtunnel port create ad419-dev -p 5165 --protocol http
   ```

   Anonymous access is required because CAES AI calls the endpoint as a server. The endpoint itself rejects anything without a valid signed callback token.

3. **Register ad419 with the CAES AI test instance.** The database is only reachable from inside Azure, so run the admin CLI from the App Service container:

   ```bash
   az webapp ssh --subscription "UC Davis CAES Test" \
     --name web-caes-ai-test-xnwral --resource-group rg-caes-ai-test
   # inside the container
   cd /home/site/wwwroot/apps/ai-server
   node dist/cli.js app create ad419-dev \
     --display-name "AD419 (local)" \
     --callback-url https://<your-tunnel-host>.devtunnels.ms/api/ai/tools/execute \
     --origin http://localhost:5173 \
     --model gpt-5.6-luna \
     --max-reasoning none
   ```

   Copy the printed API key immediately. It is shown once. The tunnel host is printed by `devtunnel host` as "Connect via browser". Each developer needs their own registration because the callback URL is fixed per registration.

4. **Configure the server** in `.env`:

   ```
   CaesAi__ServerUrl=https://web-caes-ai-test-xnwral.azurewebsites.net
   CaesAi__ApplicationId=ad419-dev
   CaesAi__ApplicationApiKey=<key from step 3>
   CaesAi__ContextSigningKey=<openssl rand -base64 48>
   ```

## Every session

```bash
devtunnel host ad419-dev
```

Keep it running while testing server tools. Chat and page-filter tools work without it; data questions fail with a tool error when it is down.

## When the tunnel changes

Tunnels expire 30 days after creation. Extend with `devtunnel update ad419-dev --expiration 30d`. If you recreate it, the hostname changes and the registration must be updated from the container:

```bash
node dist/cli.js app update ad419-dev --callback-url https://<new-host>.devtunnels.ms/api/ai/tools/execute
```

## Smoke test

With the server, Vite, and the tunnel running, open Expense Review, click **Ask CAES AI**, and ask "which funds have the most excluded spend". The details row should show a `summarize_expense_review_transactions` call and the answer should match the table when you filter to excluded rows. Then ask "show me those" and the page filters should change.
