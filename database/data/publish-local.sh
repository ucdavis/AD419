#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
configuration="${BUILD_CONFIGURATION:-Debug}"
project="$script_dir/data.sqlproj"
dacpac="$script_dir/bin/$configuration/data.dacpac"
sqlpackage="${SQLPACKAGE:-/usr/local/sqlpackage/sqlpackage}"
connection_string="${DATA_DB_CONNECTION:-Server=localhost,14333;Database=DataDb;User ID=sa;Password=LocalDev123!;Encrypt=False;TrustServerCertificate=True;}"
create_new_database="${CREATE_NEW_DATABASE:-True}"

if [[ ! -x "$sqlpackage" ]]; then
  echo "SQLPackage was not found or is not executable at '$sqlpackage'." >&2
  echo "Set SQLPACKAGE to the sqlpackage executable path and try again." >&2
  exit 1
fi

dotnet build "$project" -c "$configuration" /p:DSP=Microsoft.Data.Tools.Schema.Sql.Sql160DatabaseSchemaProvider

"$sqlpackage" \
  /Action:Publish \
  /SourceFile:"$dacpac" \
  "/TargetConnectionString:$connection_string" \
  /p:DropObjectsNotInSource=True \
  /p:BlockOnPossibleDataLoss=True \
  /p:CreateNewDatabase="$create_new_database" \
  /p:ScriptDatabaseOptions=False
