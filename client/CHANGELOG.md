This file records how the AD419 frontend is wired into the .NET host.

The client app uses:

- Vite on port `5173` during development.
- `client/vite.config.ts` proxy rules for `/api`, `/login`, `/signin-oidc`, and `/health`.
- ASP.NET Core `SpaProxy` in `server/server.csproj` so Visual Studio can start Vite without a separate `.esproj`.
- `server/server.csproj` publish targets that build `client/dist` and copy the output into `server/wwwroot`.

There is intentionally no standalone JavaScript project file in the solution.
