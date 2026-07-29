using System.Data;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Server.Core.Data;

namespace Server.Core.Import;

public sealed class UcPathTransactionsImportService
{
    public const string ConnectionStringName = "Datamart";
    public const string HcmLinkedServer = "AIT_BISTG_PRD-CAES_HCMODS_APPUSER";

    private const int CommandTimeoutSeconds = DataDbConnection.ImportCommandTimeoutSeconds;
    private const string DestinationTable = "[data].[UcPathTransactions]";

    // source reader column -> destination table column. Id, ExcludedByDate, AccountNotInAE, LoadedAt are absent on
    // purpose: the destination defaults apply to unmapped columns.
    private static readonly (string Source, string Destination)[] ColumnMappings =
    [
        ("labor_transaction_id", "LaborTransactionId"),
        ("entity", "Entity"),
        ("fund", "Fund"),
        ("financial_department", "FinancialDepartment"),
        ("parent_department", "ParentDepartment"),
        ("account", "Account"),
        ("purpose", "Purpose"),
        ("program", "Program"),
        ("project", "Project"),
        ("activity", "Activity"),
        ("finance_doc_type_cd", "FinanceDocTypeCd"),
        ("erncd", "ErnCode"),
        ("employee_id", "EmployeeId"),
        ("position_number", "PositionNumber"),
        ("eff_dt", "EffDt"),
        ("job_code", "JobCode"),
        ("rate_type_cd", "RateTypeCd"),
        ("hours", "Hours"),
        ("amount", "Amount"),
        ("pay_rate", "PayRate"),
        ("calculated_fte", "CalculatedFte"),
        ("pay_period_end_date", "PayPeriodEndDate"),
        ("fringe_benefit_salary_cd", "FringeBenefitSalaryCd"),
        ("paid_percent", "PaidPercent"),
        ("ern_derived_percent", "ErnDerivedPercent"),
        ("fiscal_year", "FiscalYear"),
        ("period", "Period"),
        ("emp_rcd", "EmpRcd"),
        ("eff_seq", "EffSeq"),
    ];

    private const string Projects204Sql = """
        SELECT DISTINCT [AEProjectNumber] FROM [data].[Projects] WHERE [Sfn] = '204'
        """;

    private readonly DataDbContext _dataDbContext;
    private readonly IConfiguration _configuration;
    private readonly ILogger<UcPathTransactionsImportService> _logger;

    public UcPathTransactionsImportService(
        DataDbContext dataDbContext,
        IConfiguration configuration,
        ILogger<UcPathTransactionsImportService> logger)
    {
        _dataDbContext = dataDbContext;
        _configuration = configuration;
        _logger = logger;
    }

    public async Task<int> ImportAsync(DateOnly cycleStart, DateOnly cycleEnd, CancellationToken cancellationToken = default)
    {
        var sourceConnectionString = _configuration["DATAMART_CONNECTION"]
            ?? _configuration.GetConnectionString(ConnectionStringName);
        if (string.IsNullOrWhiteSpace(sourceConnectionString))
        {
            throw new InvalidOperationException(
                "No datamart connection string configured. Set the DATAMART_CONNECTION environment variable " +
                $"or configure ConnectionStrings:{ConnectionStringName}.");
        }

        var destinationConnectionString = DataDbConnection.Resolve(
            _configuration,
            _dataDbContext.Database.GetConnectionString());

        await using var destination = new SqlConnection(destinationConnectionString);
        await destination.OpenAsync(cancellationToken);

        var projects204 = await ReadListAsync(destination, Projects204Sql, cancellationToken);
        var (windowStart, windowEnd) = ImportSql.BufferedWindow(cycleStart, cycleEnd);
        var fteDenominatorHours = ImportSql.HoursInFederalFiscalYear(cycleEnd.Year);

        var salarySql = BuildSalaryQuery(projects204, fteDenominatorHours);
        var fringSql = BuildFringeQuery(projects204);

        await using var source = new SqlConnection(sourceConnectionString);
        await source.OpenAsync(cancellationToken);

        await using var salaryQuery = new SqlCommand(
            $"EXEC (@remoteQuery, @windowStart, @windowEnd) AT [{HcmLinkedServer}];", source)
        {
            CommandTimeout = CommandTimeoutSeconds,
        };
        salaryQuery.Parameters.Add(new SqlParameter("@remoteQuery", SqlDbType.NVarChar, -1) { Value = salarySql });
        salaryQuery.Parameters.Add(new SqlParameter("@windowStart", SqlDbType.Date) { Value = windowStart });
        salaryQuery.Parameters.Add(new SqlParameter("@windowEnd", SqlDbType.Date) { Value = windowEnd });

        await using var fringeQuery = new SqlCommand(
            $"EXEC (@remoteQuery, @windowStart, @windowEnd) AT [{HcmLinkedServer}];", source)
        {
            CommandTimeout = CommandTimeoutSeconds,
        };
        fringeQuery.Parameters.Add(new SqlParameter("@remoteQuery", SqlDbType.NVarChar, -1) { Value = fringSql });
        fringeQuery.Parameters.Add(new SqlParameter("@windowStart", SqlDbType.Date) { Value = windowStart });
        fringeQuery.Parameters.Add(new SqlParameter("@windowEnd", SqlDbType.Date) { Value = windowEnd });

        await using var transaction = (SqlTransaction)await destination.BeginTransactionAsync(cancellationToken);

        await using (var delete = new SqlCommand(
            $"DELETE FROM {DestinationTable};", destination, transaction))
        {
            delete.CommandTimeout = CommandTimeoutSeconds;
            await delete.ExecuteNonQueryAsync(cancellationToken);
        }

        long totalRowsCopied = 0;

        using (var bulkCopy = new SqlBulkCopy(destination, SqlBulkCopyOptions.Default, transaction)
        {
            DestinationTableName = DestinationTable,
            BulkCopyTimeout = CommandTimeoutSeconds,
        })
        {
            foreach (var (sourceColumn, destinationColumn) in ColumnMappings)
            {
                bulkCopy.ColumnMappings.Add(sourceColumn, destinationColumn);
            }

            await using (var reader = await salaryQuery.ExecuteReaderAsync(cancellationToken))
            {
                await bulkCopy.WriteToServerAsync(reader, cancellationToken);
            }

            totalRowsCopied += bulkCopy.RowsCopied64;
        }

        using (var bulkCopy = new SqlBulkCopy(destination, SqlBulkCopyOptions.Default, transaction)
        {
            DestinationTableName = DestinationTable,
            BulkCopyTimeout = CommandTimeoutSeconds,
        })
        {
            foreach (var (sourceColumn, destinationColumn) in ColumnMappings)
            {
                bulkCopy.ColumnMappings.Add(sourceColumn, destinationColumn);
            }

            await using (var reader = await fringeQuery.ExecuteReaderAsync(cancellationToken))
            {
                await bulkCopy.WriteToServerAsync(reader, cancellationToken);
            }

            totalRowsCopied += bulkCopy.RowsCopied64;
        }

        await transaction.CommitAsync(cancellationToken);

        var rowsImported = (int)totalRowsCopied;
        _logger.LogInformation("Imported {RowCount} UCPath transactions", rowsImported);
        return rowsImported;
    }

    private static async Task<List<string>> ReadListAsync(SqlConnection connection, string sql, CancellationToken ct)
    {
        var values = new List<string>();
        await using var command = new SqlCommand(sql, connection) { CommandTimeout = CommandTimeoutSeconds };
        await using var reader = await command.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct))
        {
            values.Add(reader.GetString(0));
        }

        return values;
    }

    public static string BuildSalaryQuery(IReadOnlyList<string> projects204, int fteDenominatorHours) =>
        $"""
        SELECT
            JRNL_ID || '_' || JRNL_LINE_NBR || '_' || ADDL_SEQ_NBR || '_' || EMPLID || '_' || EMPL_RCD || '_' || ERNCD || '_' || RUN_ID AS labor_transaction_id,
            NULLIF(TRIM(OPERATING_UNIT), '') AS entity,
            NULLIF(TRIM(FUND_CODE), '') AS fund,
            NULLIF(TRIM(DEPTID_CF), '') AS financial_department,
            NULLIF(TRIM(UC_DEPTID_ROLLUP), '') AS parent_department,
            NULLIF(TRIM(ACCOUNT), '') AS account,
            NULLIF(TRIM(CLASS_FLD), '') AS purpose,
            NULLIF(TRIM(PROGRAM_CODE), '') AS program,
            NULLIF(TRIM(PROJECT_ID), '') AS project,
            NULLIF(TRIM(CHARTFIELD1), '') AS activity,
            NULLIF(TRIM(FINANCE_DOC_TYPE_CD), '') AS finance_doc_type_cd,
            NULLIF(TRIM(ERNCD), '') AS erncd,
            NULLIF(TRIM(EMPLID), '') AS employee_id,
            NULLIF(TRIM(POSITION_NBR), '') AS position_number,
            EFFDT AS eff_dt,
            NULLIF(TRIM(JOBCODE), '') AS job_code,
            NULLIF(TRIM(RATE_TYPE_CD), '') AS rate_type_cd,
            HOURS AS hours,
            AMOUNT AS amount,
            CASE WHEN HOURS <> 0 THEN AMOUNT / HOURS END AS pay_rate,
            HOURS / {fteDenominatorHours} AS calculated_fte,
            PAY_END_DT AS pay_period_end_date,
            'S' AS fringe_benefit_salary_cd,
            PAID_PERCENT AS paid_percent,
            ERN_DERIVED_PERCENT AS ern_derived_percent,
            FISCAL_YEAR AS fiscal_year,
            ACCOUNTING_PERIOD AS period,
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

    public static string BuildFringeQuery(IReadOnlyList<string> projects204) =>
        $"""
        SELECT
            JRNL_ID || '_' || JRNL_LINE_NBR || '_' || ADDL_SEQ_NBR || '_' || EMPLID || '_' || EMPL_RCD || '_' || 'XXX' || '_' || RUN_ID AS labor_transaction_id,
            NULLIF(TRIM(OPERATING_UNIT), '') AS entity,
            NULLIF(TRIM(FUND_CODE), '') AS fund,
            NULLIF(TRIM(DEPTID_CF), '') AS financial_department,
            NULLIF(TRIM(UC_DEPTID_ROLLUP), '') AS parent_department,
            NULLIF(TRIM(ACCOUNT), '') AS account,
            NULLIF(TRIM(CLASS_FLD), '') AS purpose,
            NULLIF(TRIM(PROGRAM_CODE), '') AS program,
            NULLIF(TRIM(PROJECT_ID), '') AS project,
            NULLIF(TRIM(CHARTFIELD1), '') AS activity,
            NULLIF(TRIM(FINANCE_DOC_TYPE_CD), '') AS finance_doc_type_cd,
            'XXX' AS erncd,
            NULLIF(TRIM(EMPLID), '') AS employee_id,
            NULLIF(TRIM(POSITION_NBR), '') AS position_number,
            EFFDT AS eff_dt,
            NULLIF(TRIM(JOBCODE), '') AS job_code,
            NULLIF(TRIM(RATE_TYPE_CD), '') AS rate_type_cd,
            0 AS hours,
            AMOUNT AS amount,
            CAST(NULL AS DECIMAL(17,4)) AS pay_rate,
            0 AS calculated_fte,
            PAY_END_DT AS pay_period_end_date,
            'F' AS fringe_benefit_salary_cd,
            CAST(NULL AS DECIMAL(7,4)) AS paid_percent,
            CAST(NULL AS DECIMAL(7,4)) AS ern_derived_percent,
            FISCAL_YEAR AS fiscal_year,
            ACCOUNTING_PERIOD AS period,
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
