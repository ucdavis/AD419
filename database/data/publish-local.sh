#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
configuration="${BUILD_CONFIGURATION:-Debug}"
project="$script_dir/data.sqlproj"
dacpac="$script_dir/bin/$configuration/data.dacpac"
sqlpackage="${SQLPACKAGE:-/usr/local/sqlpackage/sqlpackage}"
connection_string="${DB_CONNECTION:-Server=localhost,14333;Database=AppDb;User ID=sa;Password=LocalDev123!;Encrypt=False;TrustServerCertificate=True;}"

if [[ ! -x "$sqlpackage" ]]; then
  echo "SQLPackage was not found or is not executable at '$sqlpackage'." >&2
  echo "Set SQLPACKAGE to the sqlpackage executable path and try again." >&2
  exit 1
fi

dotnet build "$project" -c "$configuration"

"$sqlpackage" \
  /Action:Publish \
  /SourceFile:"$dacpac" \
  "/TargetConnectionString:$connection_string" \
  /p:DropObjectsNotInSource=False \
  /p:BlockOnPossibleDataLoss=True \
  /p:CreateNewDatabase=False \
  /p:ScriptDatabaseOptions=False
