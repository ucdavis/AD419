using System.Data;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Server.Core.Data;

namespace Server.Core.Import;

public sealed class ChartSegmentsImportService
{
    public const string RemoteLinkedServer = "AE_Redshift_PROD";

    private const int CommandTimeoutSeconds = DataDbConnection.ImportCommandTimeoutSeconds;
    private const string DestinationTable = "[data].[ChartSegments]";

    public static readonly (string SegmentName, string SourceTable)[] Segments =
    [
        ("Entity", "ae_dwh.erp_entity"),
        ("Fund", "ae_dwh.erp_fund"),
        ("FinancialDepartment", "ae_dwh.erp_fin_dept"),
        ("Account", "ae_dwh.erp_account"),
        ("Purpose", "ae_dwh.erp_purpose"),
        ("Program", "ae_dwh.erp_program"),
        ("Project", "ae_dwh.erp_project"),
        ("Activity", "ae_dwh.erp_activity"),
    ];

    // source reader column -> destination table column. LoadedAt is absent on
    // purpose: the destination default applies to unmapped columns.
    // Source names verified against the warehouse 2026-07-30; all eight erp_*
    // tables share this schema.
    private static readonly ImportColumnMapping[] ColumnMappings =
    [
        new("segment_name", "SegmentName"),
        new("code", "Code"),
        new("value_id", "ValueId"),
        new("description", "Description"),
        new("value_desc", "ValueDesc"),
        new("hierarchy_depth", "HierarchyDepth"),
        new("summary_flag", "SummaryFlag"),
        new("enabled_flag", "EnabledFlag"),
        new("start_date_active", "StartDateActive"),
        new("end_date_active", "EndDateActive"),
        new("parent_level_0_code", "ParentLevel0Code"),
        new("parent_level_1_code", "ParentLevel1Code"),
        new("parent_level_2_code", "ParentLevel2Code"),
        new("parent_level_3_code", "ParentLevel3Code"),
        new("parent_level_4_code", "ParentLevel4Code"),
        new("parent_level_5_code", "ParentLevel5Code"),
    ];

    private readonly DataDbContext _dataDbContext;
    private readonly IConfiguration _configuration;
    private readonly ILogger<ChartSegmentsImportService> _logger;
    private readonly ILinkedServerQueryExecutor _linkedServer;
    private readonly ISqlBulkCopyWriter _bulkCopy;

    public ChartSegmentsImportService(
        DataDbContext dataDbContext,
        IConfiguration configuration,
        ILogger<ChartSegmentsImportService> logger,
        ILinkedServerQueryExecutor linkedServer,
        ISqlBulkCopyWriter bulkCopy)
    {
        _dataDbContext = dataDbContext;
        _configuration = configuration;
        _logger = logger;
        _linkedServer = linkedServer;
        _bulkCopy = bulkCopy;
    }

    public async Task<int> ImportSegmentAsync(string segmentName, CancellationToken cancellationToken = default)
    {
        var (_, sourceTable) = Segments.Single(s => s.SegmentName == segmentName);

        var sourceConnectionString = DatamartConnection.Resolve(_configuration);
        var destinationConnectionString = DataDbConnection.Resolve(
            _configuration,
            _dataDbContext.Database.GetConnectionString());

        await using var destination = new SqlConnection(destinationConnectionString);
        await destination.OpenAsync(cancellationToken);
        await using var transaction = (SqlTransaction)await destination.BeginTransactionAsync(cancellationToken);

        await using (var delete = new SqlCommand(
            $"DELETE FROM {DestinationTable} WHERE [SegmentName] = @segmentName;", destination, transaction))
        {
            delete.CommandTimeout = CommandTimeoutSeconds;
            delete.Parameters.Add(new SqlParameter("@segmentName", SqlDbType.NVarChar, 30) { Value = segmentName });
            await delete.ExecuteNonQueryAsync(cancellationToken);
        }

        var rowsCopied = await _linkedServer.ExecuteReaderAsync(
            sourceConnectionString,
            $"EXEC (@remoteQuery) AT [{RemoteLinkedServer}];",
            [new SqlParameter("@remoteQuery", SqlDbType.NVarChar, -1) { Value = BuildRemoteQuery(segmentName, sourceTable) }],
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

        _logger.LogInformation("Imported {RowCount} {Segment} chart segments", rowsImported, segmentName);
        return rowsImported;
    }

    /// <summary>
    /// Builds the Redshift query run on the warehouse via the pass-through. The segment_name
    /// is cast to a narrow VARCHAR(30) so MSDASQL binds it inline rather than as a streamed LOB.
    /// The Redshift ODBC driver reports wide/untyped VARCHAR as SQL_LONGVARCHAR (streamed), which
    /// EXEC ... AT cannot stream, failing with error 7341. Explicit narrow types force inline binding.
    ///
    /// Column names verified against the warehouse 2026-07-30.
    /// </summary>
    public static string BuildRemoteQuery(string segmentName, string sourceTable)
    {
        if (!Segments.Any(s => s.SegmentName == segmentName))
        {
            throw new ArgumentException($"Unknown segment name '{segmentName}'.", nameof(segmentName));
        }

        return $"""
            SELECT CAST('{segmentName}' AS VARCHAR(30)) AS segment_name,
                code, value_id, description, value_desc, hierarchy_depth,
                summary_flag, enabled_flag, start_date_active, end_date_active,
                parent_level_0_code, parent_level_1_code, parent_level_2_code,
                parent_level_3_code, parent_level_4_code, parent_level_5_code
            FROM {sourceTable}
            WHERE code IS NOT NULL
            """;
    }
}
