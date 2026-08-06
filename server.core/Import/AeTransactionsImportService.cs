using System.Data;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Server.Core.Data;

namespace Server.Core.Import;

public sealed class AeTransactionsImportService
{
    public const string ConnectionStringName = "Datamart";
    public const string RemoteLinkedServer = "AE_Redshift_PROD";

    private const int CommandTimeoutSeconds = DataDbConnection.ImportCommandTimeoutSeconds;
    private const string DestinationTable = "[data].[AETransactions]";

    // source reader column -> destination table column. Id, ExcludedByDate, AccountInUcPath, LoadedAt are absent on
    // purpose: the destination defaults apply to unmapped columns.
    // Source names verified against the warehouse 2026-07-30; the table's two other
    // columns (actual_flag, encumbrance_type_code) are filter-only and not pulled.
    private static readonly (string Source, string Destination)[] ColumnMappings =
    [
        ("entity", "Entity"),
        ("fund", "Fund"),
        ("financial_department", "FinancialDepartment"),
        ("account", "Account"),
        ("purpose", "Purpose"),
        ("program", "Program"),
        ("project", "Project"),
        ("activity", "Activity"),
        ("entity_description", "EntityDescription"),
        ("fund_description", "FundDescription"),
        ("financial_department_description", "FinancialDepartmentDescription"),
        ("account_description", "AccountDescription"),
        ("purpose_description", "PurposeDescription"),
        ("program_description", "ProgramDescription"),
        ("project_description", "ProjectDescription"),
        ("activity_description", "ActivityDescription"),
        ("document_type", "DocumentType"),
        ("accounting_sequence_number", "AccountingSequenceNumber"),
        ("tracking_no", "TrackingNo"),
        ("reference", "Reference"),
        ("journal_line_description", "JournalLineDescription"),
        ("journal_acct_date", "JournalAcctDate"),
        ("journal_name", "JournalName"),
        ("journal_reference", "JournalReference"),
        ("period_name", "PeriodName"),
        ("journal_batch_name", "JournalBatchName"),
        ("journal_source", "JournalSource"),
        ("journal_category", "JournalCategory"),
        ("batch_status", "BatchStatus"),
        ("actual_amount", "Amount"),
        ("commitment_amount", "CommitmentAmount"),
        ("obligation_amount", "ObligationAmount"),
        ("etl_load_dt", "EtlLoadDt"),
    ];

    // The department lists are DACPAC views so the display views built in the
    // Expense Review work can share them.
    private const string CaesAnrDepartmentsSql = "SELECT [Code] FROM [data].[v_CaesAnrDepartments]";
    private const string BcbsDepartmentsSql = "SELECT [Code] FROM [data].[v_BcbsDepartments]";

    private readonly DataDbContext _dataDbContext;
    private readonly IConfiguration _configuration;
    private readonly ILogger<AeTransactionsImportService> _logger;

    public AeTransactionsImportService(
        DataDbContext dataDbContext,
        IConfiguration configuration,
        ILogger<AeTransactionsImportService> logger)
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

        var caesAnrDepartments = await ReadListAsync(destination, CaesAnrDepartmentsSql, cancellationToken);
        var bcbsDepartments = await ReadListAsync(destination, BcbsDepartmentsSql, cancellationToken);
        var projects204 = await ReadListAsync(destination, ImportSql.Projects204Sql, cancellationToken);

        var (windowStart, windowEnd) = ImportSql.BufferedWindow(cycleStart, cycleEnd);
        var periods = ImportSql.PeriodNames(windowStart, windowEnd);

        var remoteQuery = BuildRemoteQuery(periods, caesAnrDepartments, bcbsDepartments, projects204);

        await using var source = new SqlConnection(sourceConnectionString);
        await source.OpenAsync(cancellationToken);

        await using var query = new SqlCommand($"EXEC (@remoteQuery) AT [{RemoteLinkedServer}];", source)
        {
            CommandTimeout = CommandTimeoutSeconds,
        };
        query.Parameters.Add(new SqlParameter("@remoteQuery", SqlDbType.NVarChar, -1)
        {
            Value = remoteQuery,
        });

        await using var transaction = (SqlTransaction)await destination.BeginTransactionAsync(cancellationToken);

        await using (var delete = new SqlCommand(
            $"DELETE FROM {DestinationTable};", destination, transaction))
        {
            delete.CommandTimeout = CommandTimeoutSeconds;
            await delete.ExecuteNonQueryAsync(cancellationToken);
        }

        using var bulkCopy = new SqlBulkCopy(destination, SqlBulkCopyOptions.Default, transaction)
        {
            DestinationTableName = DestinationTable,
            BulkCopyTimeout = CommandTimeoutSeconds,
        };
        foreach (var (sourceColumn, destinationColumn) in ColumnMappings)
        {
            bulkCopy.ColumnMappings.Add(sourceColumn, destinationColumn);
        }

        await using (var reader = await query.ExecuteReaderAsync(cancellationToken))
        {
            await bulkCopy.WriteToServerAsync(reader, cancellationToken);
        }

        var rowsImported = (int)bulkCopy.RowsCopied64;
        await transaction.CommitAsync(cancellationToken);

        _logger.LogInformation("Imported {RowCount} AE transactions", rowsImported);
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
