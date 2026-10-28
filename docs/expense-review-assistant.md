# Expense Review assistant: local development

The Expense Review stage embeds a CAES AI chat drawer. Locally, ad419 talks to the shared CAES AI **test** instance in Azure, and that instance calls back into your machine through a Microsoft dev tunnel when the model uses a server tool.

## One-time setup

1. **Remove UCPath rows from your local data database** so only Aggie Enterprise rows can reach the model:

   Use only a disposable local database. Repeat this cleanup after reimporting UCPath, before using the assistant.

   ```sql
   DELETE FROM data.UcPathTransactions;
   ```

2. **Create a dev tunnel** to the ASP.NET Core port (not Vite):

   Replace `ad419-local-jdoe` throughout this guide with your own unique name.

   ```bash
   brew install --cask devtunnel
   devtunnel user login
   devtunnel create ad419-local-jdoe --allow-anonymous
   devtunnel port create ad419-local-jdoe -p 5165 --protocol http
   devtunnel host ad419-local-jdoe
   ```

   Leave the tunnel running in this terminal. Copy the complete HTTPS URL printed for port 5165, without a trailing slash, as `<tunnel-https-url>` below.

   Anonymous access is required because CAES AI calls the endpoint as a server. The endpoint itself rejects anything without a valid signed callback token.

3. **Register ad419 with the CAES AI test instance.** Each developer needs their own registration because it has one callback URL. If you already have a personal registration, reuse it and its matching API key instead of running `app create`.

   The database is only reachable from inside Azure. In another terminal, connect to the App Service container:

   ```bash
   az webapp ssh --subscription "UC Davis CAES Test" \
     --name web-caes-ai-test-xnwral --resource-group rg-caes-ai-test
   ```

   Inside the container:

   ```bash
   cd /home/site/wwwroot/apps/ai-server
   node dist/cli.js app create ad419-local-jdoe \
     --display-name "AD419 (local)" \
     --callback-url <tunnel-https-url>/api/ai/tools/execute \
     --origin http://localhost:5173 \
     --model gpt-5.6-luna \
     --max-reasoning none
   ```

   When creating a registration, copy the printed API key immediately. It is shown once.

4. **Configure the server** in `server/.env`. Generate a signing key locally with `openssl rand -base64 48` and paste its output as `<generated secret>`:

   ```
   CaesAi__ServerUrl=https://web-caes-ai-test-xnwral.azurewebsites.net
   CaesAi__ApplicationId=ad419-local-jdoe
   CaesAi__ApplicationApiKey=<key from step 3>
   CaesAi__ContextSigningKey=<generated secret>
   ```

## Every session

```bash
devtunnel host ad419-local-jdoe
```

Keep the tunnel running while testing the assistant's tools.

## When the tunnel changes

Tunnels expire by default after 30 days of inactivity. If you recreate yours, copy its new HTTPS URL and update only your own registration from the container:

```bash
node dist/cli.js app update ad419-local-jdoe --callback-url <tunnel-https-url>/api/ai/tools/execute
```

## Smoke test

With the server, Vite, and the tunnel running, sign in as an authorized user and confirm a fiscal cycle in Project Identification. Open Expense Review, clear any filters, click **Ask CAES AI**, and ask "which funds have the most excluded spend". The details row should show a `summarize_expense_review_transactions` call. Compare each reported fund's amount against the table filtered to that fund and excluded rows. Then ask "show me those" and the page filters should change.
