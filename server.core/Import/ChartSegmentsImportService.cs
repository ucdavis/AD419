using System.Data;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Server.Core.Data;

namespace Server.Core.Import;

public sealed class ChartSegmentsImportService
{
    public const string ConnectionStringName = "Datamart";
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
    private static readonly (string Source, string Destination)[] ColumnMappings =
    [
        ("segment_name", "SegmentName"),
        ("code", "Code"),
        ("value_id", "ValueId"),
        ("description", "Description"),
        ("value_desc", "ValueDesc"),
        ("hierarchy_depth", "HierarchyDepth"),
        ("summary_flag", "SummaryFlag"),
        ("enabled_flag", "EnabledFlag"),
        ("start_date_active", "StartDateActive"),
        ("end_date_active", "EndDateActive"),
        ("parent_level_0", "ParentLevel0Code"),
        ("parent_level_1", "ParentLevel1Code"),
        ("parent_level_2", "ParentLevel2Code"),
        ("parent_level_3", "ParentLevel3Code"),
        ("parent_level_4", "ParentLevel4Code"),
        ("parent_level_5", "ParentLevel5Code"),
    ];

    private readonly DataDbContext _dataDbContext;
    private readonly IConfiguration _configuration;
    private readonly ILogger<ChartSegmentsImportService> _logger;

    public ChartSegmentsImportService(
        DataDbContext dataDbContext,
        IConfiguration configuration,
        ILogger<ChartSegmentsImportService> logger)
    {
        _dataDbContext = dataDbContext;
        _configuration = configuration;
        _logger = logger;
    }

    public async Task<int> ImportSegmentAsync(string segmentName, CancellationToken cancellationToken = default)
    {
        var (_, sourceTable) = Segments.Single(s => s.SegmentName == segmentName);

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

        await using var source = new SqlConnection(sourceConnectionString);
        await source.OpenAsync(cancellationToken);

        await using var query = new SqlCommand($"EXEC (@remoteQuery) AT [{RemoteLinkedServer}];", source)
        {
            CommandTimeout = CommandTimeoutSeconds,
        };
        query.Parameters.Add(new SqlParameter("@remoteQuery", SqlDbType.NVarChar, -1)
        {
            Value = BuildRemoteQuery(segmentName, sourceTable),
        });

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

        _logger.LogInformation("Imported {RowCount} {Segment} chart segments", rowsImported, segmentName);
        return rowsImported;
    }

    public static string BuildRemoteQuery(string segmentName, string sourceTable)
    {
        if (!Segments.Any(s => s.SegmentName == segmentName))
        {
            throw new ArgumentException($"Unknown segment name '{segmentName}'.", nameof(segmentName));
        }

        return $"""
            SELECT '{segmentName}' AS segment_name,
                code, value_id, description, value_desc, hierarchy_depth,
                summary_flag, enabled_flag, start_date_active, end_date_active,
                parent_level_0, parent_level_1, parent_level_2,
                parent_level_3, parent_level_4, parent_level_5
            FROM {sourceTable}
            WHERE code IS NOT NULL
            """;
    }
}
