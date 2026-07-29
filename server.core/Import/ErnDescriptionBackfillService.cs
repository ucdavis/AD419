using System.Data;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Server.Core.Data;

namespace Server.Core.Import;

public sealed class ErnDescriptionBackfillService
{
    private const int CommandTimeoutSeconds = DataDbConnection.ImportCommandTimeoutSeconds;

    private readonly DataDbContext _dataDbContext;
    private readonly IConfiguration _configuration;
    private readonly ILogger<ErnDescriptionBackfillService> _logger;

    public ErnDescriptionBackfillService(DataDbContext dataDbContext, IConfiguration configuration, ILogger<ErnDescriptionBackfillService> logger)
    {
        _dataDbContext = dataDbContext;
        _configuration = configuration;
        _logger = logger;
    }

    public async Task<int> BackfillAsync(CancellationToken cancellationToken = default)
    {
        var destinationConnectionString = DataDbConnection.Resolve(
            _configuration,
            _dataDbContext.Database.GetConnectionString());

        await using var destination = new SqlConnection(destinationConnectionString);
        await destination.OpenAsync(cancellationToken);

        var ernCodes = await ReadErnCodesNeedingDescriptionsAsync(destination, cancellationToken);
        if (ernCodes.Count == 0)
        {
            return 0;
        }

        var sourceConnectionString = _configuration["DATAMART_CONNECTION"]
            ?? _configuration.GetConnectionString(UcPathTransactionsImportService.ConnectionStringName);
        if (string.IsNullOrWhiteSpace(sourceConnectionString))
        {
            throw new InvalidOperationException(
                "No datamart connection string configured. Set the DATAMART_CONNECTION environment variable " +
                $"or configure ConnectionStrings:{UcPathTransactionsImportService.ConnectionStringName}.");
        }

        await using var source = new SqlConnection(sourceConnectionString);
        await source.OpenAsync(cancellationToken);

        var descriptionQuery = BuildDescriptionQuery(ernCodes);
        var descriptions = new Dictionary<string, string>();

        await using (var query = new SqlCommand($"EXEC (@remoteQuery) AT [{UcPathTransactionsImportService.HcmLinkedServer}];", source)
        {
            CommandTimeout = CommandTimeoutSeconds,
        })
        {
            query.Parameters.Add(new SqlParameter("@remoteQuery", SqlDbType.NVarChar, -1) { Value = descriptionQuery });
            await using var reader = await query.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
            {
                var code = reader.GetString(0);
                var description = reader.IsDBNull(1) ? null : reader.GetString(1);
                if (string.IsNullOrWhiteSpace(description))
                {
                    continue;
                }

                if (!descriptions.ContainsKey(code))
                {
                    descriptions[code] = description;
                }
            }
        }

        int totalUpdated = 0;
        foreach (var (code, description) in descriptions)
        {
            await using var update = new SqlCommand(
                """
                UPDATE [data].[SegmentClassifications]
                SET [Description] = LEFT(@description, 300)
                WHERE [SegmentType] = 'Ern' AND [Code] = @code AND [Description] IS NULL
                """, destination)
            {
                CommandTimeout = CommandTimeoutSeconds,
            };
            update.Parameters.Add(new SqlParameter("@description", SqlDbType.NVarChar, -1) { Value = description });
            update.Parameters.Add(new SqlParameter("@code", SqlDbType.NVarChar, 10) { Value = code });
            totalUpdated += await update.ExecuteNonQueryAsync(cancellationToken);
        }

        if (totalUpdated > 0)
        {
            _logger.LogInformation("Backfilled {UpdatedCount} ERN descriptions", totalUpdated);
        }

        return totalUpdated;
    }

    public static string BuildDescriptionQuery(IReadOnlyList<string> ernCodes) =>
        $"""
        SELECT DISTINCT ERNCD, UC_EARNCD_DESCR
        FROM CAES_HCMODS.PS_UC_LL_SAL_DTL_V
        WHERE ERNCD IN ({ImportSql.QuoteList(ernCodes)})
        """;

    private static async Task<List<string>> ReadErnCodesNeedingDescriptionsAsync(SqlConnection connection, CancellationToken ct)
    {
        var codes = new List<string>();
        await using var command = new SqlCommand(
            """
            SELECT [Code] FROM [data].[SegmentClassifications]
            WHERE [SegmentType] = 'Ern' AND [Description] IS NULL
            """, connection)
        {
            CommandTimeout = CommandTimeoutSeconds
        };
        await using var reader = await command.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct))
        {
            codes.Add(reader.GetString(0));
        }

        return codes;
    }
}
