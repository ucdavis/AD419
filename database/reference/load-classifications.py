#!/usr/bin/env python3
"""Load SegmentClassifications.csv into [data].[SegmentClassifications].

Validates the CSV, then prints (or runs with --run) an INSERT of every listed
code. It only loads into an empty table and stops with an error otherwise, so
it can never change a classification made in the app. Run it before the first
import; the seed then adds any code the CSV does not list as unclassified.

Usage:
  ./load-classifications.py > merge.sql
  ./load-classifications.py --run "<connection string>"   # local, ad419-test, ...
  ./load-classifications.py --run local                   # localhost,14333 DataDb

--run uses sqlcmd. For Azure SQL with an Entra login, add -G to SQLCMD_ARGS,
for example SQLCMD_ARGS="-G".
"""

import csv
import os
import shlex
import subprocess
import sys
import tempfile
from pathlib import Path

CSV_PATH = Path(__file__).with_name("SegmentClassifications.csv")

# Excel strips leading zeros, so every code is checked against its type's width.
CODE_WIDTHS = {
    "Account": 6,
    "Activity": 6,
    "FinancialDepartment": 7,
    "Fund": 5,
    "Purpose": 2,
    "Ern": 3,
}
FUND_SFNS = {"201", "202", "203", "204", "205", "209", "219", "220", "221", "222", "223", "Multiple"}
TRUE_VALUES = {"TRUE", "1", "Y", "YES"}
FALSE_VALUES = {"FALSE", "0", "N", "NO"}
LOCAL_CONNECTION = "Server=localhost,14333;Database=DataDb;User ID=sa;Password=LocalDev123!;Encrypt=False;TrustServerCertificate=True;"


def parse_flag(value):
    value = value.strip().upper()
    if value == "":
        return None
    if value in TRUE_VALUES:
        return True
    if value in FALSE_VALUES:
        return False
    raise ValueError(f"IncludeInReport '{value}' is not TRUE/FALSE or blank")


def read_rows():
    rows = []
    errors = []
    seen = set()
    with CSV_PATH.open(encoding="utf-8-sig", newline="") as f:
        for line, row in enumerate(csv.DictReader(f), start=2):
            segment_type = row["SegmentType"].strip()
            code = row["Code"].strip()
            description = row["Description"].strip() or None
            sfn = row["Sfn"].strip() or None

            try:
                include = parse_flag(row["IncludeInReport"])
            except ValueError as error:
                errors.append(f"line {line}: {error}")
                continue

            if segment_type not in CODE_WIDTHS:
                errors.append(f"line {line}: unknown SegmentType '{segment_type}'")
                continue
            if len(code) != CODE_WIDTHS[segment_type]:
                errors.append(f"line {line}: {segment_type} code '{code}' should be {CODE_WIDTHS[segment_type]} characters")
            if (segment_type, code) in seen:
                errors.append(f"line {line}: duplicate {segment_type} {code}")
            seen.add((segment_type, code))
            if description is not None and len(description) > 300:
                errors.append(f"line {line}: description longer than 300 characters")
            if sfn is not None and segment_type != "Fund":
                errors.append(f"line {line}: Sfn is only valid for Fund")
            if segment_type == "Fund" and include is True and sfn not in FUND_SFNS:
                errors.append(f"line {line}: included fund {code} needs a valid Sfn, got '{sfn}'")
            if segment_type == "Fund" and include is not True and sfn is not None:
                errors.append(f"line {line}: fund {code} has an Sfn but is not included")

            rows.append((segment_type, code, description, include, sfn))

    if errors:
        sys.exit("SegmentClassifications.csv failed validation:\n  " + "\n  ".join(errors))
    return rows


def sql_text(value):
    return "NULL" if value is None else "N'" + value.replace("'", "''") + "'"


def sql_flag(value):
    return "NULL" if value is None else ("1" if value else "0")


def build_insert(rows):
    values = ",\n".join(
        f"    ({sql_text(t)}, {sql_text(c)}, {sql_text(d)}, {sql_flag(i)}, {sql_text(s)})"
        for t, c, d, i, s in rows
    )
    return f"""SET NOCOUNT ON;
SET XACT_ABORT ON;

CREATE TABLE #Source
(
    [SegmentType]     NVARCHAR(20)  NOT NULL,
    [Code]            NVARCHAR(50)  NOT NULL,
    [Description]     NVARCHAR(300) NULL,
    [IncludeInReport] BIT           NULL,
    [Sfn]             NVARCHAR(10)  NULL,
    PRIMARY KEY ([SegmentType], [Code])
);

INSERT INTO #Source ([SegmentType], [Code], [Description], [IncludeInReport], [Sfn])
SELECT [SegmentType], [Code], [Description], [IncludeInReport], [Sfn]
FROM (VALUES
{values}
) v ([SegmentType], [Code], [Description], [IncludeInReport], [Sfn]);

BEGIN TRANSACTION;

-- Only load into an empty table, so a classification made in the app is
-- never overwritten.
IF EXISTS (SELECT 1 FROM [data].[SegmentClassifications] WITH (UPDLOCK, HOLDLOCK))
    THROW 50000, 'SegmentClassifications already has rows. The loader only loads into an empty table.', 1;

INSERT INTO [data].[SegmentClassifications] ([SegmentType], [Code], [Description], [IncludeInReport], [Sfn])
SELECT [SegmentType], [Code], [Description], [IncludeInReport], [Sfn]
FROM #Source;

SELECT @@ROWCOUNT AS [Inserted];

COMMIT TRANSACTION;
"""


def main():
    rows = read_rows()
    sql = build_insert(rows)

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

    print(f"Loading {len(rows)} classifications into {parts['server']} / {parts['database']}", file=sys.stderr)
    with tempfile.NamedTemporaryFile("w", suffix=".sql", encoding="utf-8") as script:
        script.write(sql)
        script.flush()
        subprocess.run(command + ["-i", script.name], check=True)


if __name__ == "__main__":
    main()
