using System.Data;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Server.Core.Data;

namespace Server.Core.Import;

public sealed class AeTransactionsImportService
{
    public const string RemoteLinkedServer = "AE_Redshift_PROD";

    private const int CommandTimeoutSeconds = DataDbConnection.ImportCommandTimeoutSeconds;
    private const string DestinationTable = "[data].[AETransactions]";

    // source reader column -> destination table column. Id, ExcludedByDate, AccountInUcPath, LoadedAt are absent on
    // purpose: the destination defaults apply to unmapped columns.
    // Source names verified against the warehouse 2026-07-30; the table's two other
    // columns (actual_flag, encumbrance_type_code) are filter-only and not pulled.
    private static readonly ImportColumnMapping[] ColumnMappings =
    [
        new("entity", "Entity"),
        new("fund", "Fund"),
        new("financial_department", "FinancialDepartment"),
        new("account", "Account"),
        new("purpose", "Purpose"),
        new("program", "Program"),
        new("project", "Project"),
        new("activity", "Activity"),
        new("entity_description", "EntityDescription"),
        new("fund_description", "FundDescription"),
        new("financial_department_description", "FinancialDepartmentDescription"),
        new("account_description", "AccountDescription"),
        new("purpose_description", "PurposeDescription"),
        new("program_description", "ProgramDescription"),
        new("project_description", "ProjectDescription"),
        new("activity_description", "ActivityDescription"),
        new("document_type", "DocumentType"),
        new("accounting_sequence_number", "AccountingSequenceNumber"),
        new("tracking_no", "TrackingNo"),
        new("reference", "Reference"),
        new("journal_line_description", "JournalLineDescription"),
        new("journal_acct_date", "JournalAcctDate"),
        new("journal_name", "JournalName"),
        new("journal_reference", "JournalReference"),
        new("period_name", "PeriodName"),
        new("journal_batch_name", "JournalBatchName"),
        new("journal_source", "JournalSource"),
        new("journal_category", "JournalCategory"),
        new("batch_status", "BatchStatus"),
        new("actual_amount", "Amount"),
        new("commitment_amount", "CommitmentAmount"),
        new("obligation_amount", "ObligationAmount"),
        new("etl_load_dt", "EtlLoadDt"),
    ];

    // The department lists are DACPAC views so the display views built in the
    // Expense Review work can share them.
    private const string CaesAnrDepartmentsSql = "SELECT [Code] FROM [data].[v_CaesAnrDepartments]";
    private const string BcbsDepartmentsSql = "SELECT [Code] FROM [data].[v_BcbsDepartments]";

    private readonly DataDbContext _dataDbContext;
    private readonly IConfiguration _configuration;
    private readonly ILogger<AeTransactionsImportService> _logger;
    private readonly ILinkedServerQueryExecutor _linkedServer;
    private readonly ISqlBulkCopyWriter _bulkCopy;

    public AeTransactionsImportService(
        DataDbContext dataDbContext,
        IConfiguration configuration,
        ILogger<AeTransactionsImportService> logger,
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

        var caesAnrDepartments = await ImportSql.ReadListAsync(destination, CaesAnrDepartmentsSql, cancellationToken);
        var bcbsDepartments = await ImportSql.ReadListAsync(destination, BcbsDepartmentsSql, cancellationToken);
        var projects204 = await ImportSql.ReadListAsync(destination, ImportSql.Projects204Sql, cancellationToken);

        var (windowStart, windowEnd) = ImportSql.BufferedWindow(cycleStart, cycleEnd);
        var periods = ImportSql.PeriodNames(windowStart, windowEnd);

        var remoteQuery = BuildRemoteQuery(periods, caesAnrDepartments, bcbsDepartments, projects204);

        await using var transaction = (SqlTransaction)await destination.BeginTransactionAsync(cancellationToken);

        await using (var delete = new SqlCommand(
            $"DELETE FROM {DestinationTable};", destination, transaction))
        {
            delete.CommandTimeout = CommandTimeoutSeconds;
            await delete.ExecuteNonQueryAsync(cancellationToken);
        }

        var rowsCopied = await _linkedServer.ExecuteReaderAsync(
            sourceConnectionString,
            $"EXEC (@remoteQuery) AT [{RemoteLinkedServer}];",
            [new SqlParameter("@remoteQuery", SqlDbType.NVarChar, -1) { Value = remoteQuery }],
            (reader, ct) => _bulkCopy.WriteToServerAsync(
                destination,
                transaction,
                DestinationTable,
                ColumnMappings,
                reader,
                ct),
            cancellationToken);

        var rowsImported = (int)rowsCopied;
        await transaction.CommitAsync(cancellationToken);

        _logger.LogInformation("Imported {RowCount} AE transactions", rowsImported);
        return rowsImported;
    }

    public static string BuildRemoteQuery(
        IReadOnlyList<string> periodNames,
        IReadOnlyList<string> caesAnrDepartments,
        IReadOnlyList<string> bcbsDepartments,
        IReadOnlyList<string> projects204)
    {
        if (caesAnrDepartments.Count == 0)
        {
            throw new InvalidOperationException(
                "CAES/ANR department list is empty; run the ChartSegments reference import first.");
        }

        // The wide net: departments under CAES/ANR, plus any 204-mapped project, plus
        // BCBS departments only on fund 13U02 (204 BCBS rows come in via the project arm).
        // No purpose, account, fund, or activity filters here; those are visible
        // exclusion reasons applied downstream.
        var arms = new List<string>
        {
            $"financial_department IN ({ImportSql.QuoteList(caesAnrDepartments)})",
        };

        if (projects204.Count > 0)
        {
            arms.Add($"project IN ({ImportSql.QuoteList(projects204)})");
        }

        if (bcbsDepartments.Count > 0)
        {
            arms.Add($"(financial_department IN ({ImportSql.QuoteList(bcbsDepartments)}) AND fund = '13U02')");
        }

        return $"""
            SELECT entity, fund, financial_department, account, purpose, program, project, activity,
                entity_description, fund_description, financial_department_description, account_description,
                purpose_description, program_description, project_description, activity_description,
                document_type, accounting_sequence_number, tracking_no, reference, journal_line_description,
                journal_acct_date, journal_name, journal_reference, period_name, journal_batch_name,
                journal_source, journal_category, batch_status,
                actual_amount, commitment_amount, obligation_amount, etl_load_dt
            FROM ae_dwh.transactional_listing_report
            WHERE actual_flag = 'A'
              AND period_name IN ({ImportSql.QuoteList(periodNames)})
              AND ({string.Join("\n               OR ", arms)})
            """;
    }
}
