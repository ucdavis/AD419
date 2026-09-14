using System.Data;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Server.Core.Data;

namespace Server.Core.Import;

public sealed class UcPathTransactionsImportService
{
    public const string HcmLinkedServer = "AIT_BISTG_PRD-CAES_HCMODS_APPUSER";

    private const int CommandTimeoutSeconds = DataDbConnection.ImportCommandTimeoutSeconds;
    private const string DestinationTable = "[data].[UcPathTransactions]";

    // source reader column -> destination table column. EmployeeName, ExcludedByDate, AccountNotInAE, LoadedAt are absent on
    // purpose: the destination defaults apply to unmapped columns. FinanceDocTypeCd and
    // RateTypeCd are also unmapped: neither column exists on the labor views
    // (verified against the warehouse 2026-07-30), so they stay NULL.
    private static readonly ImportColumnMapping[] ColumnMappings =
    [
        new("labor_transaction_id", "LaborTransactionId"),
        new("entity", "Entity"),
        new("fund", "Fund"),
        new("financial_department", "FinancialDepartment"),
        new("parent_department", "ParentDepartment"),
        new("account", "Account"),
        new("purpose", "Purpose"),
        new("program", "Program"),
        new("project", "Project"),
        new("activity", "Activity"),
        new("erncd", "ErnCode"),
        new("ern_description", "ErnDescription"),
        new("employee_id", "EmployeeId"),
        new("position_number", "PositionNumber"),
        new("eff_dt", "EffDt"),
        new("job_code", "JobCode"),
        new("hours", "Hours"),
        new("amount", "Amount"),
        new("pay_rate", "PayRate"),
        new("calculated_fte", "CalculatedFte"),
        new("pay_period_end_date", "PayPeriodEndDate"),
        new("fringe_benefit_salary_cd", "FringeBenefitSalaryCd"),
        new("paid_percent", "PaidPercent"),
        new("ern_derived_percent", "ErnDerivedPercent"),
        new("fiscal_year", "FiscalYear"),
        new("period", "Period"),
        new("emp_rcd", "EmpRcd"),
        new("eff_seq", "EffSeq"),
    ];

    private static readonly ImportColumnMapping[] EmployeeNameMappings =
    [
        new("employee_id", "EmployeeId"),
        new("employee_name", "EmployeeName"),
    ];

    private static readonly ImportColumnMapping[] JobCodeMappings =
    [
        new("employee_id", "EmployeeId"),
        new("emp_rcd", "EmpRcd"),
        new("eff_dt", "EffDt"),
        new("eff_seq", "EffSeq"),
        new("position_number", "PositionNumber"),
        new("title_code", "TitleCode"),
    ];

    private readonly DataDbContext _dataDbContext;
    private readonly IConfiguration _configuration;
    private readonly ILogger<UcPathTransactionsImportService> _logger;
    private readonly ILinkedServerQueryExecutor _linkedServer;
    private readonly ISqlBulkCopyWriter _bulkCopy;

    public UcPathTransactionsImportService(
        DataDbContext dataDbContext,
        IConfiguration configuration,
        ILogger<UcPathTransactionsImportService> logger,
        ILinkedServerQueryExecutor linkedServer,
        ISqlBulkCopyWriter bulkCopy)
    {
        _dataDbContext = dataDbContext;
        _configuration = configuration;
        _logger = logger;
        _linkedServer = linkedServer;
        _bulkCopy = bulkCopy;
    }

    public async Task<int> ImportAsync(DateOnly cycleStart, DateOnly cycleEnd, CancellationToken cancellationToken = default)
    {
        var sourceConnectionString = DatamartConnection.Resolve(_configuration);
        var destinationConnectionString = DataDbConnection.Resolve(
            _configuration,
            _dataDbContext.Database.GetConnectionString());

        await using var destination = new SqlConnection(destinationConnectionString);
        await destination.OpenAsync(cancellationToken);

        var projects204 = await ImportSql.ReadListAsync(destination, ImportSql.Projects204Sql, cancellationToken);
        var (windowStart, windowEnd) = ImportSql.BufferedWindow(cycleStart, cycleEnd);
        var fteDenominatorHours = ImportSql.HoursInFederalFiscalYear(cycleEnd.Year);

        var salarySql = BuildSalaryQuery(projects204, fteDenominatorHours);
        var fringSql = BuildFringeQuery(projects204);

        await using var transaction = (SqlTransaction)await destination.BeginTransactionAsync(cancellationToken);

        await using (var delete = new SqlCommand(
            $"DELETE FROM {DestinationTable};", destination, transaction))
        {
            delete.CommandTimeout = CommandTimeoutSeconds;
            await delete.ExecuteNonQueryAsync(cancellationToken);
        }

        var commandText = $"EXEC (@remoteQuery, @windowStart, @windowEnd) AT [{HcmLinkedServer}];";
        var totalRowsCopied =
            await BulkCopyLinkedQueryAsync(
                sourceConnectionString,
                commandText,
                [
                    new SqlParameter("@remoteQuery", SqlDbType.NVarChar, -1) { Value = salarySql },
                    new SqlParameter("@windowStart", SqlDbType.Date) { Value = windowStart },
                    new SqlParameter("@windowEnd", SqlDbType.Date) { Value = windowEnd },
                ],
                destination,
                transaction,
                cancellationToken)
            + await BulkCopyLinkedQueryAsync(
                sourceConnectionString,
                commandText,
                [
                    new SqlParameter("@remoteQuery", SqlDbType.NVarChar, -1) { Value = fringSql },
                    new SqlParameter("@windowStart", SqlDbType.Date) { Value = windowStart },
                    new SqlParameter("@windowEnd", SqlDbType.Date) { Value = windowEnd },
                ],
                destination,
                transaction,
                cancellationToken);

        await transaction.CommitAsync(cancellationToken);

        var rowsImported = (int)totalRowsCopied;
        _logger.LogInformation("Imported {RowCount} UCPath transactions", rowsImported);

        await EnrichEmployeeNamesAsync(sourceConnectionString, destination, cancellationToken);
        await EnrichJobCodesAsync(sourceConnectionString, destination, windowEnd, cancellationToken);

        return rowsImported;
    }

    private Task<long> BulkCopyLinkedQueryAsync(
        string sourceConnectionString,
        string commandText,
        IReadOnlyList<SqlParameter> parameters,
        SqlConnection destination,
        SqlTransaction transaction,
        CancellationToken cancellationToken) =>
        _linkedServer.ExecuteReaderAsync(
            sourceConnectionString,
            commandText,
            parameters,
            (reader, ct) => _bulkCopy.WriteToServerAsync(
                destination,
                transaction,
                DestinationTable,
                ColumnMappings,
                reader,
                ct),
            cancellationToken);

    private async Task EnrichEmployeeNamesAsync(string sourceConnectionString, SqlConnection destination, CancellationToken ct)
    {
        await using (var create = new SqlCommand(
            "CREATE TABLE #EmployeeNames ([EmployeeId] NVARCHAR(10) NOT NULL, [EmployeeName] NVARCHAR(100) NULL);",
            destination))
        {
            await create.ExecuteNonQueryAsync(ct);
        }

        await _linkedServer.ExecuteReaderAsync(
            sourceConnectionString,
            $"EXEC (@remoteQuery) AT [{HcmLinkedServer}];",
            [new SqlParameter("@remoteQuery", SqlDbType.NVarChar, -1) { Value = BuildNamesQuery() }],
            (reader, cancellationToken) => _bulkCopy.WriteToServerAsync(
                destination,
                null,
                "#EmployeeNames",
                EmployeeNameMappings,
                reader,
                cancellationToken),
            ct);

        await using (var update = new SqlCommand(
            """
            -- UCD_PS_NAMES_V verified one row per EMPLID (2026-07-30: 27,275 rows, 27,275
            -- distinct EMPLIDs); MAX() keeps the update deterministic if that ever changes
            UPDATE t SET [EmployeeName] = LEFT(n.[EmployeeName], 100)
            FROM [data].[UcPathTransactions] t
            JOIN (SELECT [EmployeeId], MAX([EmployeeName]) AS [EmployeeName] FROM #EmployeeNames GROUP BY [EmployeeId]) n
                ON n.[EmployeeId] = t.[EmployeeId];
            DROP TABLE #EmployeeNames;
            """, destination)
        {
            CommandTimeout = CommandTimeoutSeconds,
        })
        {
            await update.ExecuteNonQueryAsync(ct);
        }
    }

    private async Task EnrichJobCodesAsync(
        string sourceConnectionString,
        SqlConnection destination,
        DateOnly effDtCeiling,
        CancellationToken ct)
    {
        await using (var create = new SqlCommand(
            "CREATE TABLE #PeopleSoftJobs ([EmployeeId] NVARCHAR(10), [EmpRcd] SMALLINT, [EffDt] DATETIME2(7), [EffSeq] SMALLINT, [PositionNumber] NVARCHAR(8), [TitleCode] NVARCHAR(4));",
            destination))
        {
            await create.ExecuteNonQueryAsync(ct);
        }

        await _linkedServer.ExecuteReaderAsync(
            sourceConnectionString,
            $"EXEC (@remoteQuery, @effDtCeiling) AT [{HcmLinkedServer}];",
            [
                new SqlParameter("@remoteQuery", SqlDbType.NVarChar, -1) { Value = BuildJobCodeQuery() },
                new SqlParameter("@effDtCeiling", SqlDbType.Date) { Value = effDtCeiling },
            ],
            (reader, cancellationToken) => _bulkCopy.WriteToServerAsync(
                destination,
                null,
                "#PeopleSoftJobs",
                JobCodeMappings,
                reader,
                cancellationToken),
            ct);

        await using (var update = new SqlCommand(
            """
            WITH Ranked AS (
                SELECT *,
                    ROW_NUMBER() OVER (PARTITION BY [EmployeeId], [EmpRcd], [EffDt] ORDER BY [EffSeq] DESC) AS DateRank,
                    ROW_NUMBER() OVER (PARTITION BY [EmployeeId], [EmpRcd], [PositionNumber] ORDER BY [EffDt] DESC, [EffSeq] DESC) AS PositionRank
                FROM #PeopleSoftJobs
            )
            UPDATE t
            SET [JobCode] = COALESCE(exactMatch.[TitleCode], positionMatch.[TitleCode])
            FROM [data].[UcPathTransactions] t
            LEFT JOIN (SELECT * FROM Ranked WHERE DateRank = 1) exactMatch
                ON exactMatch.[EmployeeId] = t.[EmployeeId] AND exactMatch.[EmpRcd] = t.[EmpRcd]
               AND exactMatch.[EffDt] = t.[EffDt] AND exactMatch.[EffSeq] = t.[EffSeq]
            LEFT JOIN (SELECT * FROM Ranked WHERE PositionRank = 1) positionMatch
                ON positionMatch.[EmployeeId] = t.[EmployeeId] AND positionMatch.[EmpRcd] = t.[EmpRcd]
               AND positionMatch.[PositionNumber] = t.[PositionNumber]
            WHERE t.[JobCode] IS NULL OR t.[JobCode] = '';
            DROP TABLE #PeopleSoftJobs;
            """, destination)
        {
            CommandTimeout = CommandTimeoutSeconds,
        })
        {
            await update.ExecuteNonQueryAsync(ct);
        }
    }

    public static string BuildNamesQuery() =>
        """
        SELECT EMPLID AS employee_id, NAME AS employee_name
        FROM CAES_HCMODS.UCD_PS_NAMES_V
        """;

    // PS_JOB_V columns verified against the warehouse 2026-07-30.
    public static string BuildJobCodeQuery() =>
        """
        SELECT EMPLID AS employee_id, EMPL_RCD AS emp_rcd, EFFDT AS eff_dt, EFFSEQ AS eff_seq,
            POSITION_NBR AS position_number, SUBSTR(JOBCODE, -4) AS title_code
        FROM CAES_HCMODS.PS_JOB_V
        WHERE JOBCODE <> 'CONV'
          AND JOBCODE NOT LIKE ' %'
          AND EFFDT <= ?
        """;

    // Column names verified against the warehouse 2026-07-30 (ALL_TAB_COLUMNS for
    // both labor views). PAY_END_DT is the pay period end date used for the window
    // filter; UC_EARN_END_DT also exists but the 2025 notes say not to use it.
    public static string BuildSalaryQuery(IReadOnlyList<string> projects204, int fteDenominatorHours) =>
        $"""
        SELECT
            JOURNAL_ID || '_' || JOURNAL_LINE || '_' || UC_ADDL_SEQ || '_' || EMPLID || '_' || EMPL_RCD || '_' || ERNCD || '_' || RUN_ID AS labor_transaction_id,
            NULLIF(TRIM(OPERATING_UNIT), '') AS entity,
            NULLIF(TRIM(FUND_CODE), '') AS fund,
            NULLIF(TRIM(DEPTID_CF), '') AS financial_department,
            NULLIF(TRIM(UC_DEPTID_ROLLUP), '') AS parent_department,
            NULLIF(TRIM(ACCOUNT), '') AS account,
            NULLIF(TRIM(CLASS_FLD), '') AS purpose,
            NULLIF(TRIM(PROGRAM_CODE), '') AS program,
            NULLIF(TRIM(PROJECT_ID), '') AS project,
            NULLIF(TRIM(CHARTFIELD1), '') AS activity,
            NULLIF(TRIM(ERNCD), '') AS erncd,
            NULLIF(TRIM(UC_EARNCD_DESCR), '') AS ern_description,
            NULLIF(TRIM(EMPLID), '') AS employee_id,
            NULLIF(TRIM(POSITION_NBR), '') AS position_number,
            EFFDT AS eff_dt,
            NULLIF(TRIM(SUBSTR(JOBCODE, -4)), '') AS job_code,
            HOURS1 AS hours,
            MONETARY_AMOUNT AS amount,
            CASE WHEN HOURS1 <> 0 THEN MONETARY_AMOUNT / HOURS1 END AS pay_rate,
            HOURS1 / {fteDenominatorHours} AS calculated_fte,
            PAY_END_DT AS pay_period_end_date,
            'S' AS fringe_benefit_salary_cd,
            UC_PCT_TOT_PAY AS paid_percent,
            UC_DRV_EFT_PCT AS ern_derived_percent,
            FISCAL_YEAR AS fiscal_year,
            TO_CHAR(ACCOUNTING_PERIOD) AS period,
            EMPL_RCD AS emp_rcd,
            EFFSEQ AS eff_seq
        FROM CAES_HCMODS.PS_UC_LL_SAL_DTL_V
        WHERE BUSINESS_UNIT IN ('DVCMP','UCANR')
          AND OPERATING_UNIT IN ('3310','3110')
          AND DML_IND <> 'D'
          AND PAY_END_DT BETWEEN ? AND ?
          AND NULLIF(TRIM(POSITION_NBR), '') IS NOT NULL
          AND (FUND_CODE = '13U02' OR CLASS_FLD IN ('44','45','78'){Source204Arm(projects204)})
        """;

    // Column names verified against the warehouse 2026-07-30. The fringe view has
    // no JOBCODE, hours, or percent columns; job_code is backfilled by the title
    // code enrichment step.
    public static string BuildFringeQuery(IReadOnlyList<string> projects204) =>
        $"""
        SELECT
            JOURNAL_ID || '_' || JOURNAL_LINE || '_' || UC_ADDL_SEQ || '_' || EMPLID || '_' || EMPL_RCD || '_' || 'XXX' || '_' || RUN_ID AS labor_transaction_id,
            NULLIF(TRIM(OPERATING_UNIT), '') AS entity,
            NULLIF(TRIM(FUND_CODE), '') AS fund,
            NULLIF(TRIM(DEPTID_CF), '') AS financial_department,
            NULLIF(TRIM(UC_DEPTID_ROLLUP), '') AS parent_department,
            NULLIF(TRIM(ACCOUNT), '') AS account,
            NULLIF(TRIM(CLASS_FLD), '') AS purpose,
            NULLIF(TRIM(PROGRAM_CODE), '') AS program,
            NULLIF(TRIM(PROJECT_ID), '') AS project,
            NULLIF(TRIM(CHARTFIELD1), '') AS activity,
            'XXX' AS erncd,
            CAST(NULL AS VARCHAR2(120)) AS ern_description,
            NULLIF(TRIM(EMPLID), '') AS employee_id,
            NULLIF(TRIM(POSITION_NBR), '') AS position_number,
            EFFDT AS eff_dt,
            CAST(NULL AS VARCHAR2(24)) AS job_code,
            0 AS hours,
            MONETARY_AMOUNT AS amount,
            CAST(NULL AS DECIMAL(17,4)) AS pay_rate,
            0 AS calculated_fte,
            PAY_END_DT AS pay_period_end_date,
            'F' AS fringe_benefit_salary_cd,
            CAST(NULL AS DECIMAL(7,4)) AS paid_percent,
            CAST(NULL AS DECIMAL(7,4)) AS ern_derived_percent,
            FISCAL_YEAR AS fiscal_year,
            TO_CHAR(ACCOUNTING_PERIOD) AS period,
            EMPL_RCD AS emp_rcd,
            EFFSEQ AS eff_seq
        FROM CAES_HCMODS.PS_UC_LL_FRNG_DTL_V
        WHERE BUSINESS_UNIT IN ('DVCMP','UCANR')
          AND OPERATING_UNIT IN ('3310','3110')
          AND DML_IND <> 'D'
          AND PAY_END_DT BETWEEN ? AND ?
          AND NULLIF(TRIM(POSITION_NBR), '') IS NOT NULL
          AND (FUND_CODE = '13U02' OR CLASS_FLD IN ('44','45','78'){Source204Arm(projects204)})
        """;

    private static string Source204Arm(IReadOnlyList<string> projects204) =>
        projects204.Count > 0 ? $" OR PROJECT_ID IN ({ImportSql.QuoteList(projects204)})" : string.Empty;
}
