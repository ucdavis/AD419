# AD419

AD419 is a full-stack web application built with a .NET 10 backend and a React/Vite frontend. The product description is still being defined.

## Architecture

- **Backend**: .NET 10 Web API with ASP.NET Core
- **Frontend**: React 19 with Vite, TypeScript, and TanStack Router/Query/Table
- **Authentication**: OIDC with Microsoft Entra ID (Azure AD)
- **Styling**: Tailwind CSS
- **Database**: SQL Server, with EF Core migrations for application tables and a separate SQL database deployed from a SQL project/DACPAC for reference/import data tables
- **Development**: Hot reload for both frontend and backend
- **Development Integration**: ASP.NET Core `SpaProxy` launches Vite for Visual Studio users, while Vite proxies API and auth routes back to ASP.NET Core during development

## Quick Start

1. **Clone or open the repository**

   ```bash
   cd AD419
   ```

2. **Open In DevContainer**

   - Open the project folder in Visual Studio Code.
   - Click the prompt to open in container (or manually select from the command palette).

_Using the DevContainer is optional, but it will get you the right version of dotnet + node, plus install all dependencies and setup a local SQL instance for you_

3. **Start the application**

   **Inside DevContainer**: The application starts automatically via `postStartCommand` — no manual steps required.

   **Outside DevContainer (command line)**:

   Prerequisites:
   - [.NET 10 SDK](https://dotnet.microsoft.com/download)
   - [Node.js 22+](https://nodejs.org/) (includes npm)
   - Docker (for the local SQL Server container)

   Install dependencies and start the app:
   ```bash
   npm install
   cd client && npm install && cd ..
   npm run db:up
   npm start
   ```
   
   `npm run db:up` starts the SQL Server container from the same Compose file used by the DevContainer. `npm start` starts the .NET backend on port `5165` with a CLI-specific launch profile, waits for health check, and then starts the Vite dev server on port `5173` which opens the browser.

   **Visual Studio (Windows)**:

   Prerequisites:
   - Visual Studio 2026 version 18.0 or later (for `net10.0` support)
   - [Node.js 22+](https://nodejs.org/) (includes npm)
   - Docker (for the local SQL Server container)

   Install dependencies and start the database:
   ```bash
   npm install
   cd client && npm install && cd ..
   npm run db:up
   ```

   Then open `app.sln`, set the `server` project as the startup project, and press `F5`. `SpaProxy` starts Vite if needed and redirects the browser to the frontend dev server.

   **Visual Studio Code**:

   Prerequisites:
   - [.NET 10 SDK](https://dotnet.microsoft.com/download)
   - [Node.js 22+](https://nodejs.org/) (includes npm)
   - Docker (for the local SQL Server container)

   Install dependencies and start the database:
   ```bash
   npm install
   cd client && npm install && cd ..
   npm run db:up
   ```

   Then open the repo root in VS Code, install the recommended extensions when prompted (at minimum the Microsoft C# extension), choose `Full Stack: VS Code` in **Run and Debug**, and press `F5`. VS Code builds and launches the backend with the `http-cli` launch profile, starts Vite after the backend health check passes, and opens the app in your default external browser at `http://localhost:5173`. For backend-only debugging, choose `Backend: ASP.NET Core + Swagger`.
   
4. **Access the application**

In development, the frontend runs from **http://localhost:5173** and proxies backend requests to ASP.NET Core on **http://localhost:5165**.

- **Main App**: http://localhost:5173
- **Backend API**: http://localhost:5165/api/*
- **API Documentation (Swagger)**: http://localhost:5165/swagger
- **Health Check**: http://localhost:5165/health
- **Visual Studio F5**: launches through the backend profile, then redirects to the Vite dev server on `:5173`

### Database configuration

The backend requires SQL Server connection strings for the app database and the data database.

- Outside DevContainer, the default development connections point to the SQL Server container published on `localhost:14333`. EF uses `AppDb`; the data DACPAC and imports use `DataDb`.
- Inside DevContainer, `devcontainer.json` overrides `DB_CONNECTION` and `DATA_DB_CONNECTION` to use the internal Docker hostname `sql:1433`.

When you want to specify your own DB connections, provide them by setting the `DB_CONNECTION` and `DATA_DB_CONNECTION` environment variables (for example in a `.env` file) or by updating `ConnectionStrings:DefaultConnection` and `ConnectionStrings:DataConnection` in `appsettings.*.json` (`.env` is recommended).

To run only the database outside DevContainer:

```bash
npm run db:up
```

This runs the `sql` service from `.devcontainer/docker-compose.yml` and exposes SQL Server on `localhost:14333`.

Useful companion commands:

- `npm run db:logs` to watch SQL Server startup logs
- `npm run db:down` to stop the container when you're done

### Database schema and deployment

AD419 has two database-management paths with different ownership boundaries:

- EF Core migrations in `server.core/Migrations/` manage the application database, currently the `[app]` schema and application tables such as `[app].[Users]`.
- The SQL project in `database/data/data.sqlproj` builds a DACPAC for a separate data database containing the `[data]` schema and data-import/reference tables such as `[data].[AllProjects]`, `[data].[ActiveProjects]`, and `[data].[AssistanceListingNumbers]`.

The backend runs EF Core migrations at startup through `DbInitializer` and `AppDbContext.Database.MigrateAsync()`. The EF migrations assembly is `server.core`, and the EF migrations history table is stored as `[app].[__EFMigrationsHistory]`.

For local EF migration work:

```bash
./server.core/createMigration.sh MigrationName
./server.core/updateDatabase.sh
./server.core/updateDatabase.sh MigrationName
```

Create a migration only when the `AppDbContext` model changes and the application schema needs to change. Do not edit existing migrations after they have been shared.

The data DACPAC is built as part of the solution because `database/data/data.sqlproj` is included in `app.sln`:

```bash
dotnet build database/data/data.sqlproj -c Release
```

To publish the data DACPAC to the local SQL Server container:

```bash
./database/data/publish-local.sh
```

`publish-local.sh` uses `BUILD_CONFIGURATION` to choose `Debug` or `Release`, `SQLPACKAGE` to locate the `sqlpackage` executable, and `DATA_DB_CONNECTION` for the target connection string. If `DATA_DB_CONNECTION` is not set, it targets the local container `DataDb` database at `localhost:14333`. Local publish creates `DataDb` by default; set `CREATE_NEW_DATABASE=False` to require the database to already exist.

In GitHub Actions, `ci-cd.yml` builds the solution, verifies schema ownership boundaries, uploads the web app package and `data.dacpac`, and `deploy-azure-appservice.yml` publishes the data DACPAC to the separate data database before deploying the web app. The DACPAC publish uses `DropObjectsNotInSource=True`, so objects removed from the data project are dropped during publish. Azure infrastructure creates both databases on the same SQL server, so workflow publish blocks possible data loss, does not create the database, and does not script database options.

For production deployments, the workflow first generates and uploads a `prod-data-dacpac-script` artifact with SQLPackage `/Action:Script`. Review that script before approving the gated production publish job.

### Auth Configuration

We use OIDC with Microsoft Entra ID (Azure AD) for authentication. The auth flow doesn't use any secrets and the settings in `appsettings.*.json` are sufficient for local development.

When you are ready to get your own, go to [Microsoft Entra ID](https://entra.microsoft.com/) and create a new application registration. Add a **Web** platform under **Authentication**, then configure redirect URIs for every origin that will complete the server-side OIDC callback.

For local development, set the redirect URL to the origin you actually launch from:

- `http://localhost:5173/signin-oidc` for the default Vite dev flow
- `http://localhost:5165/signin-oidc` if you are testing directly against the backend origin
- `https://localhost:44322/signin-oidc` if you use the default IIS Express profile

For deployed Azure App Service environments, also add the deployed callback URL:

- `https://<app-service-hostname>/signin-oidc`

Under **Implicit grant and hybrid flows**, check **ID tokens**. The application uses a secretless OIDC login flow and sends `response_type=id_token`; if ID tokens are not enabled on the app registration, deployed login fails with `AADSTS700054: response_type 'id_token' is not enabled for the application`.

You do not need to enable **Access tokens** for this app's current cookie-based login flow.

You might also want to set the publisher domain to ucdavis.edu and fill in the other general branding info.

### Google Analytics (GA4)

AD419 includes GA4 wiring:

- GA bootstrap script is in `client/index.html`
- Route-change page view tracking is in `client/src/shared/analytics/AnalyticsListener.tsx`

A placeholder measurement ID is included by default:

- `G-XXXXXXXXXX`

Before production use, replace `G-XXXXXXXXXX` in `client/index.html` with the real GA4 measurement ID in **both** places:

1. `https://www.googletagmanager.com/gtag/js?id=...`
2. `gtag('config', '...')`

### Health check

The health check endpoint (`/health`) is configured to return the status of the application and its dependencies. It includes a database health check to ensure the SQL Server connection is healthy. See [Health Checks](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/health-checks?view=aspnetcore-10.0#entity-framework-core-dbcontext-probe).

## Development

### Development Architecture

In development mode:

- ASP.NET Core runs on port `5165`
- Vite serves the frontend on port `5173`
- Visual Studio uses `SpaProxy` to start Vite and redirect the browser to it
- Vite proxies `/api`, `/login`, `/signin-oidc`, and `/health` back to ASP.NET Core

This keeps frontend HMR fast while preserving the backend's auth and API pipeline. In production, the backend serves pre-built static files from `wwwroot/`.

### Backend Development

The backend is configured with hot reload via `dotnet watch`. Any changes to C# files automatically restart the server. Visual Studio users can also run the `server` project directly with `SpaProxy`.

### Frontend Development

The frontend uses Vite's hot module replacement (HMR). Changes to React components, TypeScript files, and CSS are reflected immediately by the Vite dev server.

### VS Code Debugging

The repository includes `.vscode/launch.json` and `.vscode/tasks.json` so the standard VS Code workflow works out of the box:

- `Full Stack: VS Code` launches the backend debugger, starts the Vite dev server, and opens the frontend in your default external browser.
- `Backend: ASP.NET Core + Swagger` launches only the backend and opens Swagger when Kestrel is ready.

The VS Code flow intentionally uses the `http-cli` launch profile instead of the `SpaProxy` profile so terminal and editor-driven debugging both avoid the duplicate browser-launch behavior from the ASP.NET Core side.

### Authentication Flow

1. Frontend routes requiring authentication redirect to the backend's login endpoint
2. Backend handles OIDC flow with Microsoft Entra ID
3. Upon successful authentication, a same-site cookie is set
4. Frontend API calls automatically include the authentication cookie
5. Backend validates the cookie for protected endpoints

## Testing

### Client tests

- Run `cd client && npm test` to execute the Vitest suite once.
- Use `npm run test:watch` inside `client/` for red/green feedback while you work.
- Tests run against a jsdom environment with Testing Library so you do not need the backend running.

### Server tests

- Run `dotnet test` from the repository root to execute the .NET test project included in `app.sln`.
- Alternatively, target the project directly with `dotnet test tests/server.tests/server.tests.csproj`.
- The tests use EF Core's in-memory provider (see `tests/server.tests/TestDbContextFactory.cs`) so no SQL Server instance is required.

## Updating Dependencies

### Client

- JavaScript/TypeScript packages: run `npm outdated` at the repository root and inside `client/` to see what can be updated. Use `npm update` in each location for compatible updates, or `npm install <package>@latest` when you need to jump to a new major version.
- After updating Node packages, reinstall if needed (`npm install`, `cd client && npm install`) and rerun key checks like `npm run lint`, `cd client && npm test`, and `dotnet test`.

### Server

.Net is a bit more complicated, but we're going to use the dotnet-outdated tool to help.

Run the following command from the repository root:

```
dotnet-outdated
```

and it'll show you a nice table of what can be updated. Be careful when updating major versions, especially with packages that are pinned to the .net version.

You can update individual packages or you can use the `--upgrade` flag to update all at once. Here's a nice way to do it and only update minor/patch versions:

```
dotnet-outdated --upgrade --version-lock Major
```

If you update `Microsoft.EntityFrameworkCore.Design` or another package that a tool depends on, you'll want to update that tool as well to match, ex: `dotnet tool update dotnet-ef --local --version 8.0.21`. That will update it for you but also set the value in our `dotnet-tools.json` so it's consistent for everyone.

And as always, after updating dependencies, make sure to run `dotnet build` and `dotnet test` to verify everything is working.

## Project Structure

```text
.
├── client/                  # React frontend
│   ├── src/
│   │   ├── routes/          # TanStack Router routes
│   │   ├── queries/         # TanStack Query hooks
│   │   ├── lib/             # API client and utilities
│   │   └── shared/          # Shared components
│   ├── package.json
│   └── vite.config.ts
├── server/                  # .NET backend
│   ├── Controllers/         # API controllers
│   ├── Helpers/             # Utility classes
│   ├── Properties/          # Launch settings
│   ├── Program.cs           # Application entry point
│   └── server.csproj        # SpaProxy + publish integration
├── server.core/             # Shared domain/data code and EF Core migrations
│   ├── Data/                # AppDbContext and database initialization
│   └── Migrations/          # EF Core migrations for the app schema
├── database/
│   └── data/                # SQL project that builds the data DACPAC
├── package.json             # Root dev orchestration scripts
└── app.sln                  # Visual Studio solution file
```

## Available Scripts

### Root Level

- `npm start` - Starts both backend and frontend with hot reload
- `npm run start:server` - Starts only the ASP.NET Core backend
- `npm run start:client` - Starts only the Vite dev server
- `npm run db:up` - Starts the local SQL Server container
- `npm run db:logs` - Tails local SQL Server container logs
- `npm run db:down` - Stops the local SQL Server container

### Client Directory

- `npm run dev` - Start Vite development server
- `npm run dev:open` - Start Vite development server and open the browser
- `npm run build` - Build for production
- `npm run lint` - Run ESLint
- `npm run preview` - Preview production build
- `npm test` - Run tests

### Server Directory

- `dotnet run` - Start the .NET application
- `dotnet watch` - Start with hot reload
- `dotnet build` - Build the application
- `dotnet test` - Run tests
