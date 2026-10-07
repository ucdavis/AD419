#!/usr/bin/env python3
"""Load the OrgR reference CSVs into the OrgR tables.

  OrgRFinancialDepartments.csv -> [data].[OrgRFinancialDepartments]
  OrgRNifaDepartments.csv      -> [data].[OrgRNifaDepartments]
  OrgRProjectAdditions.csv     -> [data].[OrgRProjectAdditions]

Every OrgR code the CSVs use is added to [data].[OrgRs] first. Validates the
CSVs, then prints (or runs with --run) a script that:
  - inserts listed departments that are missing, with the CSV's OrgR;
  - fills the OrgR on existing departments only where it is still blank, so
    reloading never undoes a mapping made in the app;
  - inserts listed project additions that are missing;
  - leaves everything not in the CSVs alone.

Usage:
  ./load-orgr.py > orgr.sql
  ./load-orgr.py --run "<connection string>"   # local, ad419-test, ...
  ./load-orgr.py --run local                   # localhost,14333 DataDb

--run uses sqlcmd. For Azure SQL with an Entra login, add -G to SQLCMD_ARGS,
for example SQLCMD_ARGS="-G".
"""

import csv
import os
import re
import shlex
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).parent
FINANCIAL_DEPARTMENTS = HERE / "OrgRFinancialDepartments.csv"
NIFA_DEPARTMENTS = HERE / "OrgRNifaDepartments.csv"
PROJECT_ADDITIONS = HERE / "OrgRProjectAdditions.csv"

ORGR_PATTERN = re.compile(r"^[A-Z][A-Z0-9]{3}$")
LOCAL_CONNECTION = "Server=localhost,14333;Database=DataDb;User ID=sa;Password=LocalDev123!;Encrypt=False;TrustServerCertificate=True;"


def read_pairs(path, key_column, key_pattern, key_description, unique_key, errors):
    """Rows as (key, OrgR). unique_key: one OrgR per key; otherwise only the
    pair must be unique (a project can be added to several OrgRs)."""
    rows = []
    seen = set()
    with path.open(encoding="utf-8-sig", newline="") as f:
        for line, row in enumerate(csv.DictReader(f), start=2):
            key = row[key_column].strip()
            orgr = row["OrgR"].strip()
            if not re.match(key_pattern, key):
                errors.append(f"{path.name} line {line}: {key_column} '{key}' should be {key_description}")
            if not ORGR_PATTERN.match(orgr):
                errors.append(f"{path.name} line {line}: OrgR '{orgr}' should be 4 uppercase characters")
            identity = key if unique_key else (key, orgr)
            if identity in seen:
                errors.append(f"{path.name} line {line}: duplicate {key_column} {key}")
            seen.add(identity)
            rows.append((key, orgr))
    return rows


def read_all():
    errors = []
    financial = read_pairs(FINANCIAL_DEPARTMENTS, "FinancialDepartment", r"^[A-Z0-9]{7}$", "7 characters", True, errors)
    nifa = read_pairs(NIFA_DEPARTMENTS, "NifaDepartment", r"^[A-Z]{3}$", "3 uppercase letters", True, errors)
    additions = read_pairs(PROJECT_ADDITIONS, "AccessionNumber", r"^\d{7}$", "7 digits", False, errors)
    if errors:
        sys.exit("OrgR CSVs failed validation:\n  " + "\n  ".join(errors))
    return financial, nifa, additions


def sql_text(value):
    return "N'" + value.replace("'", "''") + "'"


def values(rows):
    return ",\n".join(f"    ({sql_text(a)}, {sql_text(b)})" for a, b in rows)


def build_script(financial, nifa, additions):
    orgrs = sorted({orgr for _, orgr in financial + nifa + additions})
    orgr_values = ",\n".join(f"    ({sql_text(code)})" for code in orgrs)
    return f"""SET NOCOUNT ON;
SET XACT_ABORT ON;

CREATE TABLE #OrgRs ([Code] NVARCHAR(10) NOT NULL PRIMARY KEY);
INSERT INTO #OrgRs ([Code]) VALUES
{orgr_values};

CREATE TABLE #Financial ([FinancialDepartment] NVARCHAR(50) NOT NULL PRIMARY KEY, [OrgR] NVARCHAR(10) NOT NULL);
INSERT INTO #Financial ([FinancialDepartment], [OrgR]) VALUES
{values(financial)};

CREATE TABLE #Nifa ([NifaDepartment] NVARCHAR(3) NOT NULL PRIMARY KEY, [OrgR] NVARCHAR(10) NOT NULL);
INSERT INTO #Nifa ([NifaDepartment], [OrgR]) VALUES
{values(nifa)};

CREATE TABLE #Additions ([AccessionNumber] NVARCHAR(7) NOT NULL, [OrgR] NVARCHAR(10) NOT NULL, PRIMARY KEY ([AccessionNumber], [OrgR]));
INSERT INTO #Additions ([AccessionNumber], [OrgR]) VALUES
{values(additions)};

DECLARE @changes TABLE ([Target] NVARCHAR(40) NOT NULL, [Action] NVARCHAR(10) NOT NULL);

BEGIN TRANSACTION;

INSERT INTO [data].[OrgRs] ([Code])
OUTPUT N'OrgRs', N'INSERT' INTO @changes
SELECT s.[Code] FROM #OrgRs s
WHERE NOT EXISTS (SELECT 1 FROM [data].[OrgRs] o WHERE o.[Code] = s.[Code]);

-- A blank OrgR is filled; a mapping already set (in the app or an earlier
-- load) is kept.
MERGE [data].[OrgRFinancialDepartments] AS target
USING #Financial AS source
    ON target.[FinancialDepartment] = source.[FinancialDepartment]
WHEN MATCHED AND target.[OrgR] IS NULL THEN
    UPDATE SET [OrgR] = source.[OrgR]
WHEN NOT MATCHED BY TARGET THEN
    INSERT ([FinancialDepartment], [OrgR]) VALUES (source.[FinancialDepartment], source.[OrgR])
OUTPUT N'OrgRFinancialDepartments', $action INTO @changes;

MERGE [data].[OrgRNifaDepartments] AS target
USING #Nifa AS source
    ON target.[NifaDepartment] = source.[NifaDepartment]
WHEN MATCHED AND target.[OrgR] IS NULL THEN
    UPDATE SET [OrgR] = source.[OrgR]
WHEN NOT MATCHED BY TARGET THEN
    INSERT ([NifaDepartment], [OrgR]) VALUES (source.[NifaDepartment], source.[OrgR])
OUTPUT N'OrgRNifaDepartments', $action INTO @changes;

INSERT INTO [data].[OrgRProjectAdditions] ([AccessionNumber], [OrgR])
OUTPUT N'OrgRProjectAdditions', N'INSERT' INTO @changes
SELECT s.[AccessionNumber], s.[OrgR] FROM #Additions s
WHERE NOT EXISTS
(
    SELECT 1 FROM [data].[OrgRProjectAdditions] a
    WHERE a.[AccessionNumber] = s.[AccessionNumber] AND a.[OrgR] = s.[OrgR]
);

COMMIT TRANSACTION;

SELECT [Target], [Action], COUNT(*) AS [Rows] FROM @changes GROUP BY [Target], [Action] ORDER BY [Target], [Action];
"""


def main():
    financial, nifa, additions = read_all()
    sql = build_script(financial, nifa, additions)

    if len(sys.argv) == 1:
        sys.stdout.write(sql)
        return
    if len(sys.argv) != 3 or sys.argv[1] != "--run":
        sys.exit(__doc__)

    connection = LOCAL_CONNECTION if sys.argv[2] == "local" else sys.argv[2]
    parts = dict(
        part.split("=", 1) for part in connection.split(";") if "=" in part
    )
    parts = {key.strip().lower(): value.strip() for key, value in parts.items()}
    command = ["sqlcmd", "-S", parts["server"], "-d", parts["database"], "-b", "-C"]
    if "user id" in parts:
        command += ["-U", parts["user id"], "-P", parts.get("password", "")]
    command += shlex.split(os.environ.get("SQLCMD_ARGS", ""))

    print(
        f"Loading {len(financial)} financial departments, {len(nifa)} NIFA departments and "
        f"{len(additions)} project additions into {parts['server']} / {parts['database']}",
        file=sys.stderr,
    )
    with tempfile.NamedTemporaryFile("w", suffix=".sql", encoding="utf-8") as script:
        script.write(sql)
        script.flush()
        subprocess.run(command + ["-i", script.name], check=True)


if __name__ == "__main__":
    main()
