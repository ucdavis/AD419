# Development Architecture

## Overview

AD419 uses:

- ASP.NET Core on port `5165` for API, auth, health checks, and Swagger
- Vite on port `5173` for the React frontend during development
- ASP.NET Core `SpaProxy` so Visual Studio can launch the frontend without a separate `.esproj`
- Vite proxy rules so frontend requests to `/api`, `/login`, `/signin-oidc`, and `/health` are forwarded to ASP.NET Core
- SQL Server schema management split between EF Core migrations for application-owned tables and a SQL project/DACPAC for data-import/reference tables

In production, ASP.NET Core serves the built frontend from `server/wwwroot`.

## Development Request Flow

### Visual Studio startup flow

```text
Visual Studio F5
    ↓
ASP.NET Core profile (:5165)
    ↓
SpaProxy ensures Vite is running
    ↓
Browser is redirected to :5173
```

### Runtime request flow

```text
Browser → :5173 (Vite)
            ↓
    ┌───────┴──────────────┐
    │                      │
frontend assets/routes   /api, /login, /signin-oidc, /health
    │                      │
    ↓                      ↓
 React + HMR         Proxy to :5165 (ASP.NET Core)
```

This keeps frontend hot reload fast while leaving backend auth and API behavior inside ASP.NET Core.

## Production Request Flow

```text
Browser → :5165 (ASP.NET Core)
            ↓
    ┌───────┴────────┐
    │                │
 /api, auth, health  static files + SPA fallback
    │                │
    ↓                ↓
 Controllers      wwwroot/index.html + assets
```

## Database Schema Ownership

AD419 keeps the application schema and import/reference data schema separate.

### EF Core application schema

EF Core owns the `[app]` schema. `server.core/Data/AppDbContext.cs` sets the default schema to `[app]`, and migrations live in `server.core/Migrations/`.

At startup, `server/Program.cs` resolves `IDbInitializer`, which runs `AppDbContext.Database.MigrateAsync()`. This means application deployments apply pending EF migrations when the web app starts. EF's migrations history table is configured as `[app].[__EFMigrationsHistory]`; the initializer also transfers an older `[dbo].[__EFMigrationsHistory]` table into `[app]` if it exists.

Local helpers:

```bash
./server.core/createMigration.sh MigrationName
./server.core/updateDatabase.sh
./server.core/updateDatabase.sh MigrationName
```

Only create EF migrations for model changes that affect the application-owned schema. Shared migrations should not be edited in place.

### Data DACPAC schema

The SQL project at `database/data/data.sqlproj` owns the `[data]` schema and data-import/reference tables. It currently includes:

- `database/data/Schemas/data.sql`
- `database/data/Tables/AllProjects.sql`
- `database/data/Tables/ActiveProjects.sql`
- `database/data/Tables/AssistanceListingNumbers.sql`
- `database/data/Scripts/Script.PostDeployment.sql`

The SQL project builds `database/data/bin/<Configuration>/data.dacpac`. For local publish, run:

```bash
./database/data/publish-local.sh
```

The script uses `SQLPACKAGE` when set, otherwise `/usr/local/sqlpackage/sqlpackage`. It uses `DB_CONNECTION` when set, otherwise the local development SQL Server connection string for `localhost:14333`.

CI builds the SQL project through `app.sln`, uploads `data.dacpac` as a `data-dacpac` artifact, and the reusable Azure deployment workflow publishes it before deploying the web app. DACPAC publish settings are intentionally conservative:

- `DropObjectsNotInSource=False`
- `BlockOnPossibleDataLoss=True`
- `CreateNewDatabase=False`
- `ScriptDatabaseOptions=False`

This lets the data DACPAC add and update the `[data]` schema without deleting unrelated database objects or replacing EF's `[app]` schema responsibilities.

The CI workflow also enforces the schema boundary by failing if EF migrations reference the `data` schema or the data SQL project references the `app` schema. Production deploys add one review step before publishing: a separate job generates a `prod-data-dacpac-script` artifact with SQLPackage `/Action:Script`, then the production publish runs behind the `deploy_prod` workflow input and `prod` GitHub Environment gate.

## Key Files

### `server/server.csproj`

Responsibilities:

- Declares backend dependencies
- Configures `SpaProxy`
- Includes the `client/` tree as project items so frontend files appear in Visual Studio without a separate JavaScript project
- Runs the client build during `dotnet publish` and copies `client/dist` into `wwwroot`

Important settings:

```xml
<SpaRoot>..\client\</SpaRoot>
<SpaProxyLaunchCommand>npm run dev</SpaProxyLaunchCommand>
<SpaProxyServerUrl>http://localhost:5173</SpaProxyServerUrl>
```

### `server/Properties/launchSettings.json`

Responsibilities:

- Enables `Microsoft.AspNetCore.SpaProxy` for the development profiles
- Defines the backend application URLs used by `dotnet run`, `dotnet watch`, and Visual Studio

### `client/vite.config.ts`

Responsibilities:

- Runs the frontend dev server on port `5173`
- Proxies backend routes to ASP.NET Core
- Detects either `ASPNETCORE_URLS` or `ASPNETCORE_HTTPS_PORT` so the same config works for normal `dotnet watch` and IIS Express

### `server/Program.cs`

Responsibilities:

- Configures the ASP.NET Core middleware pipeline
- Configures `AppDbContext` with migrations from `server.core` and history in the `[app]` schema
- Runs database initialization at startup, including EF migrations
- Serves static files in all environments
- Reserves SPA fallback behavior for production, where the built frontend lives in `wwwroot`

### `server.core/Data/AppDbContext.cs`

Responsibilities:

- Defines EF Core entities and their application schema mapping
- Sets the default EF schema to `[app]`

### `server.core/Data/DbInitializer.cs`

Responsibilities:

- Ensures the `[app]` schema exists before EF migration history is accessed
- Moves legacy EF migration history from `[dbo]` to `[app]` when necessary
- Applies pending EF Core migrations during application startup

### `database/data/data.sqlproj`

Responsibilities:

- Builds the `data.dacpac`
- Defines the `[data]` schema and data/import tables
- Includes the post-deployment script hook

### `.github/workflows/ci-cd.yml`

Responsibilities:

- Builds and tests the solution and client
- Publishes the web app package
- Uploads the web app and data DACPAC artifacts
- Generates a production data DACPAC script artifact before the gated production publish job
- Fails if EF migrations or the data SQL project cross their schema ownership boundary

### `.github/workflows/deploy-azure-appservice.yml`

Responsibilities:

- Deploys or updates Azure infrastructure
- Resolves the target App Service and SQL Database from deployment outputs
- Publishes the data DACPAC with SQLPackage
- Deploys the web app package

## Development Workflows

### Visual Studio on Windows

1. Open the solution.
2. Set `server` as the startup project.
3. Press `F5`.

`SpaProxy` starts Vite if needed and redirects the browser to `http://localhost:5173`.

### Command line

Run both processes:

```bash
npm start
```

Run only the backend:

```bash
dotnet watch --project server/server.csproj
```

Run only the frontend:

```bash
cd client
npm run dev
```

## Why This Replaced `.esproj`

The previous `.esproj` setup published correctly, but it caused `dotnet watch` failures because the .NET CLI still tried to traverse the JavaScript project type during watch runs.

The current approach keeps the useful parts:

- Visual Studio can still launch Vite automatically
- Publish still builds and includes the frontend assets
- Frontend files still appear in Visual Studio

And removes the CLI pain point:

- `dotnet watch --project server/server.csproj` no longer fails on a referenced `.esproj`

## Troubleshooting

### Visual Studio starts the backend but not the frontend

Check:

- Node.js is installed and available on `PATH`
- `server` is the startup project
- the launch profile includes `ASPNETCORE_HOSTINGSTARTUPASSEMBLIES=Microsoft.AspNetCore.SpaProxy`

### Frontend loads but API calls fail

Check:

- ASP.NET Core is running on `:5165`
- the proxy targets in `client/vite.config.ts` still match the backend URL
- `/health` responds on the backend

### Backend exits immediately during startup

AD419 runs database initialization at startup. If SQL Server is not available, the app exits before the browser handoff completes.

Common local fix:

```bash
npm run db:up
```

### Changing ports

If you change the development ports, update all of these together:

1. `server/Properties/launchSettings.json`
2. `server/server.csproj` (`<SpaProxyServerUrl>`)
3. `client/vite.config.ts`
4. `.devcontainer/devcontainer.json`
