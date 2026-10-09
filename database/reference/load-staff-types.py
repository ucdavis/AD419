#!/usr/bin/env python3
"""Load the staff type and title CSVs into the FTE SFN lookups.

  StaffTypes.csv -> [data].[StaffTypes]  (staff type to FTE report line)
  Titles.csv     -> [data].[Titles]      (UCPath title code to staff type)

UCPath rows get their FTE SFN through Titles then StaffTypes. Validates the
CSVs, then prints (or runs with --run) a script that:
  - inserts listed codes that are missing;
  - fills a blank column on an existing code, so reloading never undoes a
    value set another way;
  - leaves everything not in the CSVs alone.

Usage:
  ./load-staff-types.py > staff-types.sql
  ./load-staff-types.py --run "<connection string>"   # local, ad419-test, ...
  ./load-staff-types.py --run local                   # localhost,14333 DataDb

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
STAFF_TYPES = HERE / "StaffTypes.csv"
TITLES = HERE / "Titles.csv"
LOCAL_CONNECTION = "Server=localhost,14333;Database=DataDb;User ID=sa;Password=LocalDev123!;Encrypt=False;TrustServerCertificate=True;"


def read_staff_types(errors):
    rows = []
    seen = set()
    with STAFF_TYPES.open(encoding="utf-8-sig", newline="") as f:
        for line, row in enumerate(csv.DictReader(f), start=2):
            code = row["StaffTypeCode"].strip()
            fte_sfn = row["FteSfn"].strip() or None
            description = row["Description"].strip() or None
            if not re.match(r"^[0-9A-Z]{1,10}$", code):
                errors.append(f"{STAFF_TYPES.name} line {line}: StaffTypeCode '{code}' is not a code")
            if fte_sfn is not None and not re.match(r"^\d{3}$", fte_sfn):
                errors.append(f"{STAFF_TYPES.name} line {line}: FteSfn '{fte_sfn}' should be 3 digits")
            if code in seen:
                errors.append(f"{STAFF_TYPES.name} line {line}: duplicate StaffTypeCode {code}")
            seen.add(code)
            rows.append((code, fte_sfn, description))
    return rows


def read_titles(staff_type_codes, errors):
    rows = []
    seen = set()
    with TITLES.open(encoding="utf-8-sig", newline="") as f:
        for line, row in enumerate(csv.DictReader(f), start=2):
            code = row["TitleCode"].strip()
            staff_type = row["StaffTypeCode"].strip() or None
            name = row["Name"].strip() or None
            # Excel strips leading zeros; UCPath stores the last 4 characters of JOBCODE.
            if len(code) != 4:
                errors.append(f"{TITLES.name} line {line}: TitleCode '{code}' should be 4 characters")
            if staff_type is not None and staff_type not in staff_type_codes:
                errors.append(f"{TITLES.name} line {line}: unknown StaffTypeCode '{staff_type}'")
            if name is not None and len(name) > 200:
                errors.append(f"{TITLES.name} line {line}: name longer than 200 characters")
            if code in seen:
                errors.append(f"{TITLES.name} line {line}: duplicate TitleCode {code}")
            seen.add(code)
            rows.append((code, staff_type, name))
    return rows


def read_all():
    errors = []
    staff_types = read_staff_types(errors)
    titles = read_titles({code for code, _, _ in staff_types}, errors)
    if errors:
        sys.exit("Staff type CSVs failed validation:\n  " + "\n  ".join(errors))
    return staff_types, titles


def sql_text(value):
    return "NULL" if value is None else "N'" + value.replace("'", "''") + "'"


def values(rows):
    return ",\n".join("    (" + ", ".join(sql_text(v) for v in row) + ")" for row in rows)


def build_script(staff_types, titles):
    return f"""SET NOCOUNT ON;
SET XACT_ABORT ON;

CREATE TABLE #StaffTypes ([StaffTypeCode] NVARCHAR(10) NOT NULL PRIMARY KEY, [FteSfn] NVARCHAR(10) NULL, [Description] NVARCHAR(200) NULL);
INSERT INTO #StaffTypes ([StaffTypeCode], [FteSfn], [Description])
SELECT [StaffTypeCode], [FteSfn], [Description]
FROM (VALUES
{values(staff_types)}
) v ([StaffTypeCode], [FteSfn], [Description]);

CREATE TABLE #Titles ([TitleCode] NVARCHAR(4) NOT NULL PRIMARY KEY, [StaffTypeCode] NVARCHAR(10) NULL, [Name] NVARCHAR(200) NULL);
INSERT INTO #Titles ([TitleCode], [StaffTypeCode], [Name])
SELECT [TitleCode], [StaffTypeCode], [Name]
FROM (VALUES
{values(titles)}
) v ([TitleCode], [StaffTypeCode], [Name]);

DECLARE @changes TABLE ([Target] NVARCHAR(20) NOT NULL, [Action] NVARCHAR(10) NOT NULL);

BEGIN TRANSACTION;

MERGE [data].[StaffTypes] AS target
USING #StaffTypes AS source
    ON target.[StaffTypeCode] = source.[StaffTypeCode]
WHEN MATCHED AND ((target.[FteSfn] IS NULL AND source.[FteSfn] IS NOT NULL)
               OR (target.[Description] IS NULL AND source.[Description] IS NOT NULL)) THEN
    UPDATE SET
        [FteSfn] = COALESCE(target.[FteSfn], source.[FteSfn]),
        [Description] = COALESCE(target.[Description], source.[Description])
WHEN NOT MATCHED BY TARGET THEN
    INSERT ([StaffTypeCode], [FteSfn], [Description])
    VALUES (source.[StaffTypeCode], source.[FteSfn], source.[Description])
OUTPUT N'StaffTypes', $action INTO @changes;

MERGE [data].[Titles] AS target
USING #Titles AS source
    ON target.[TitleCode] = source.[TitleCode]
WHEN MATCHED AND ((target.[StaffTypeCode] IS NULL AND source.[StaffTypeCode] IS NOT NULL)
               OR (target.[Name] IS NULL AND source.[Name] IS NOT NULL)) THEN
    UPDATE SET
        [StaffTypeCode] = COALESCE(target.[StaffTypeCode], source.[StaffTypeCode]),
        [Name] = COALESCE(target.[Name], source.[Name])
WHEN NOT MATCHED BY TARGET THEN
    INSERT ([TitleCode], [StaffTypeCode], [Name])
    VALUES (source.[TitleCode], source.[StaffTypeCode], source.[Name])
OUTPUT N'Titles', $action INTO @changes;

COMMIT TRANSACTION;

SELECT [Target], [Action], COUNT(*) AS [Rows] FROM @changes GROUP BY [Target], [Action] ORDER BY [Target], [Action];
"""


def main():
    staff_types, titles = read_all()
    sql = build_script(staff_types, titles)

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
        f"Loading {len(staff_types)} staff types and {len(titles)} titles into {parts['server']} / {parts['database']}",
        file=sys.stderr,
    )
    with tempfile.NamedTemporaryFile("w", suffix=".sql", encoding="utf-8") as script:
        script.write(sql)
        script.flush()
        subprocess.run(command + ["-i", script.name], check=True)


if __name__ == "__main__":
    main()
