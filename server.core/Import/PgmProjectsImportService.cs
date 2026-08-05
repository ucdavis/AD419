using System.Data;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Server.Core.Data;

namespace Server.Core.Import;

public sealed class PgmProjectsImportService : IPgmProjectsImportService
{
    public const string ConnectionStringName = "Datamart";

    public const string RemoteLinkedServer = "AE_Redshift_PROD";

    private const int CommandTimeoutSeconds = DataDbConnection.ImportCommandTimeoutSeconds;
    private const string DestinationTable = "[data].[PGMProjects]";
    private const int MaxInlineAggregateLength = 255;
    internal const string PeopleAggregateTruncationWarningMessage =
        "PGM project people aggregates were truncated by the {MaxLength}-byte import query cast: {TruncatedFields}";

    private static readonly PeopleAggregateField[] PeopleAggregateFields =
    [
        new(
            "principal_investigator_person_name",
            "principal_investigator_names",
            "PrincipalInvestigatorNames",
            "principal investigators"),
        new("piperson", "pi_persons", "PiPersons", "PI persons"),
        new("award_copi_name", "award_copi_names", "AwardCopiNames", "award co-PIs"),
        new("project_manager_name", "project_manager_names", "ProjectManagerNames", "project managers"),
        new("grant_administrator", "grant_administrators", "GrantAdministrators", "grant administrators"),
        new("contractadmin", "contract_admins", "ContractAdmins", "contract admins"),
    ];

    // source reader column -> destination table column.
    // LoadedAt is intentionally absent: the destination column defaults to
    // SYSUTCDATETIME(), and SqlBulkCopy applies that default to unmapped columns.
    private static readonly (string Source, string Destination)[] ColumnMappings =
    [
        ("project_id", "ProjectId"),
        ("project_number", "ProjectNumber"),
        ("project_name", "ProjectName"),
        ("project_start_date", "ProjectStartDate"),
        ("project_end_date", "ProjectEndDate"),
        ("project_legal_entity", "ProjectLegalEntity"),
        ("project_burden_schedule_base", "ProjectBurdenScheduleBase"),
        ("project_burden_cost_rate", "ProjectBurdenCostRate"),
        ("award_number", "AwardNumber"),
        ("award_name", "AwardName"),
        ("award_status", "AwardStatus"),
        ("award_type", "AwardType"),
        ("award_purpose", "AwardPurpose"),
        ("award_start_date", "AwardStartDate"),
        ("award_end_date", "AwardEndDate"),
        ("cfda", "Cfda"),
        ("sponsor_award_number", "SponsorAwardNumber"),
        ("sponsor_award_key", "SponsorAwardKey"),
        ("cfda_program_number", "CfdaProgramNumber"),
        ("primary_sponsor", "PrimarySponsor"),
        ("primary_sponsor_name", "PrimarySponsorName"),
        ("funding_source_name", "FundingSourceName"),
        ("funding_source_number", "FundingSourceNumber"),
        ("awardfundcode", "AwardFundCode"),
        ("fund", "Fund"),
        ("owning_org_name", "OwningOrgName"),
        ("financial_dept_code", "FinancialDeptCode"),
        ("financial_dept_name", "FinancialDeptName"),
        ("budget_period", "BudgetPeriod"),
        ("budget_start_date", "BudgetStartDate"),
        ("budget_end_date", "BudgetEndDate"),
        ("principal_investigator_names", "PrincipalInvestigatorNames"),
        ("pi_persons", "PiPersons"),
        ("award_copi_names", "AwardCopiNames"),
        ("project_manager_names", "ProjectManagerNames"),
        ("grant_administrators", "GrantAdministrators"),
        ("contract_admins", "ContractAdmins"),
    ];

    private readonly DataDbContext _dataDbContext;
    private readonly IConfiguration _configuration;
    private readonly ILogger<PgmProjectsImportService> _logger;

    public PgmProjectsImportService(
        DataDbContext dataDbContext,
        IConfiguration configuration,
        ILogger<PgmProjectsImportService> logger)
    {
        _dataDbContext = dataDbContext;
        _configuration = configuration;
        _logger = logger;
    }

    public async Task<PgmProjectsImportResult> ImportAsync(DateOnly reportDate, CancellationToken cancellationToken = default)
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

        _logger.LogInformation("Importing PGM projects for report date {ReportDate}", reportDate);

        await using var source = new SqlConnection(sourceConnectionString);
        await source.OpenAsync(cancellationToken);

        await using var query = new SqlCommand(BuildSourceCommandText(), source)
        {
            CommandTimeout = CommandTimeoutSeconds,
        };
        // The report date is a bound parameter, never concatenated into SQL: it is passed to
        // Redshift as the EXEC ... AT pass-through parameter, so the warehouse reuses one plan
        // across report dates. @remoteQuery carries the Redshift SQL; @reportDate binds to its
        // single ? placeholder.
        query.Parameters.Add(new SqlParameter("@remoteQuery", SqlDbType.NVarChar, -1) { Value = BuildRemoteQuery() });
        query.Parameters.Add(new SqlParameter("@reportDate", SqlDbType.Date) { Value = reportDate });

        await using var destination = new SqlConnection(destinationConnectionString);
        await destination.OpenAsync(cancellationToken);
        await using var transaction = (SqlTransaction)await destination.BeginTransactionAsync(cancellationToken);

        await using (var delete = new SqlCommand($"DELETE FROM {DestinationTable};", destination, transaction))
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

        await LogPeopleAggregateTruncationWarningsAsync(source, destination, cancellationToken);

        _logger.LogInformation(
            "Imported {RowCount} PGM projects for report date {ReportDate}",
            rowsImported,
            reportDate);

        return new PgmProjectsImportResult(rowsImported, reportDate);
    }

    private async Task LogPeopleAggregateTruncationWarningsAsync(
        SqlConnection source,
        SqlConnection destination,
        CancellationToken cancellationToken)
    {
        try
        {
            var sourceLengths = await ReadOversizedSourceAggregateLengthsAsync(source, cancellationToken);
            if (sourceLengths.Count == 0)
            {
                return;
            }

            var storedLengths = await ReadStoredAggregateLengthsAsync(destination, cancellationToken);
            var truncatedFields = FindTruncatedAggregateFields(sourceLengths, storedLengths);

            if (truncatedFields.Count == 0)
            {
                return;
            }

            _logger.LogWarning(
                PeopleAggregateTruncationWarningMessage,
                MaxInlineAggregateLength,
                string.Join("; ", truncatedFields));
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            _logger.LogWarning(
                ex,
                "Unable to validate PGM project aggregate truncation after import.");
        }
    }

    private static async Task<List<PeopleAggregateLengths>> ReadOversizedSourceAggregateLengthsAsync(
        SqlConnection source,
        CancellationToken cancellationToken)
    {
        await using var command = new SqlCommand(BuildAggregateLengthCheckCommandText(), source)
        {
            CommandTimeout = CommandTimeoutSeconds,
        };
        command.Parameters.Add(
            new SqlParameter("@remoteQuery", SqlDbType.NVarChar, -1) { Value = BuildAggregateLengthCheckQuery() });

        var sourceLengths = new List<PeopleAggregateLengths>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            sourceLengths.Add(ReadAggregateLengths(reader, "project_id", field => $"{field.RemoteAlias}_length"));
        }

        return sourceLengths;
    }

    private static async Task<Dictionary<long, PeopleAggregateLengths>> ReadStoredAggregateLengthsAsync(
        SqlConnection destination,
        CancellationToken cancellationToken)
    {
        await using var command = new SqlCommand(BuildStoredAggregateLengthQuery(), destination)
        {
            CommandTimeout = CommandTimeoutSeconds,
        };

        var storedLengths = new Dictionary<long, PeopleAggregateLengths>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            var lengths = ReadAggregateLengths(reader, "ProjectId", field => $"{field.DestinationColumn}Length");
            storedLengths[lengths.ProjectId] = lengths;
        }

        return storedLengths;
    }

    private static List<string> FindTruncatedAggregateFields(
        IReadOnlyList<PeopleAggregateLengths> sourceLengths,
        IReadOnlyDictionary<long, PeopleAggregateLengths> storedLengths)
    {
        var truncatedFields = new List<string>();

        foreach (var sourceRow in sourceLengths)
        {
            if (!storedLengths.TryGetValue(sourceRow.ProjectId, out var storedRow))
            {
                continue;
            }

            for (var i = 0; i < PeopleAggregateFields.Length; i++)
            {
                var sourceLength = sourceRow.FieldLengths[i];
                var storedLength = storedRow.FieldLengths[i];

                if (sourceLength <= storedLength)
                {
                    continue;
                }

                truncatedFields.Add(
                    $"project {sourceRow.ProjectId} {PeopleAggregateFields[i].DisplayName}: source length {sourceLength}, stored length {storedLength}");
            }
        }

        return truncatedFields;
    }

    private static PeopleAggregateLengths ReadAggregateLengths(
        IDataRecord record,
        string projectIdColumn,
        Func<PeopleAggregateField, string> lengthColumnName)
    {
        var lengths = new long[PeopleAggregateFields.Length];
        for (var i = 0; i < PeopleAggregateFields.Length; i++)
        {
            lengths[i] = ReadInt64(record, lengthColumnName(PeopleAggregateFields[i]));
        }

        return new PeopleAggregateLengths(ReadInt64(record, projectIdColumn), lengths);
    }

    private static long ReadInt64(IDataRecord record, string columnName)
    {
        var value = record.GetValue(record.GetOrdinal(columnName));
        return value == DBNull.Value ? 0 : Convert.ToInt64(value);
    }

    /// <summary>
    /// The T-SQL run against the warehouse gateway server. It executes the Redshift query as a
    /// parameterized pass-through via EXEC ... AT: <c>@remoteQuery</c> is the Redshift SQL and
    /// <c>@reportDate</c> binds to its single <c>?</c> placeholder. EXEC ... AT (unlike OPENQUERY,
    /// whose argument must be a string literal) lets the date be a real bound parameter, so it is
    /// never concatenated into SQL and the warehouse caches one plan across report dates.
    /// Requires "RPC Out" enabled on the <c>AE_Redshift_PROD</c> linked server.
    /// </summary>
    public static string BuildSourceCommandText() =>
        $"EXEC (@remoteQuery, @reportDate) AT [{RemoteLinkedServer}];";

    /// <summary>
    /// The T-SQL run against the warehouse gateway server to check whether any source people
    /// aggregates exceed the inline cast limit used by the import query.
    /// </summary>
    public static string BuildAggregateLengthCheckCommandText() =>
        $"EXEC (@remoteQuery) AT [{RemoteLinkedServer}];";

    /// <summary>
    /// Builds the Redshift query that returns numeric aggregate length telemetry. It intentionally
    /// does not return the LISTAGG values themselves, so the linked server can bind the results as
    /// ordinary numeric columns instead of streamed LOBs.
    /// </summary>
    public static string BuildAggregateLengthCheckQuery() =>
        $$"""
        WITH people_lengths AS (
            SELECT project_id,
        {{BuildSourceAggregateLengthSelectList()}}
            FROM ae_dwh.pgm_master_data
            WHERE project_id IS NOT NULL
            GROUP BY project_id
        )
        SELECT project_id,
        {{BuildSourceAggregateLengthResultList()}}
        FROM people_lengths
        WHERE {{BuildSourceAggregateLengthWhereClause()}}
        """;

    public static string BuildStoredAggregateLengthQuery() =>
        $"""
        SELECT ProjectId,
        {BuildStoredAggregateLengthSelectList()}
        FROM {DestinationTable}
        """;

    private static string BuildSourceAggregateLengthSelectList() =>
        string.Join(
            ",\n",
            PeopleAggregateFields.Select(field =>
                $"            OCTET_LENGTH(LISTAGG(DISTINCT {field.SourceColumn}, '; ')) AS {field.RemoteAlias}_length"));

    private static string BuildSourceAggregateLengthResultList() =>
        string.Join(
            ",\n",
            PeopleAggregateFields.Select(field => $"    COALESCE({field.RemoteAlias}_length, 0) AS {field.RemoteAlias}_length"));

    private static string BuildSourceAggregateLengthWhereClause() =>
        string.Join(
            "\n   OR ",
            PeopleAggregateFields.Select(field => $"{field.RemoteAlias}_length > {MaxInlineAggregateLength}"));

    private static string BuildStoredAggregateLengthSelectList() =>
        string.Join(
            ",\n",
            PeopleAggregateFields.Select(field =>
                $"    COALESCE(DATALENGTH({field.DestinationColumn}) / 2, 0) AS {field.DestinationColumn}Length"));

    /// <summary>
    /// Builds the Redshift query run on the warehouse via the pass-through. The single <c>?</c> is
    /// the report date, bound by <see cref="BuildSourceCommandText"/>. One row per project_id:
    /// single-valued attributes come from the budget period containing the report date (falling
    /// back to the most recent period); people columns aggregate distinct names across all of the
    /// project's rows. Rows with a null project_id are excluded (they otherwise collapse into one
    /// junk bucket). LISTAGG results are cast to a narrow VARCHAR(255) so MSDASQL binds them inline
    /// rather than as LOBs, which EXEC ... AT cannot stream: the Redshift ODBC driver reports any
    /// wider VARCHAR as SQL_LONGVARCHAR (streamed) even when the values are short, which fails with
    /// error 7341 "cannot get the current row value". Real values are tiny (observed max ~43 chars,
    /// a project has at most a handful of distinct people), so 255 has ample headroom. Redshift also disallows differing
    /// LISTAGG WITHIN GROUP orderings and a trailing semicolon inside the pass-through. LoadedAt is
    /// not selected here; the destination column defaults to it.
    /// </summary>
    public static string BuildRemoteQuery() =>
        $"""
        WITH ranked AS (
            SELECT pmd.*,
                ROW_NUMBER() OVER (
                    PARTITION BY project_id
                    ORDER BY
                        CASE WHEN ? BETWEEN budget_start_date AND budget_end_date
                             THEN 0 ELSE 1 END,
                        budget_start_date DESC,
                        contract_line_number
                ) AS rn
            FROM ae_dwh.pgm_master_data pmd
            WHERE project_id IS NOT NULL
        ),
        people AS (
            SELECT project_id,
        {BuildPeopleAggregateSelectList()}
            FROM ae_dwh.pgm_master_data
            WHERE project_id IS NOT NULL
            GROUP BY project_id
        )
        SELECT r.project_id, r.project_number, r.project_name, r.project_start_date, r.project_end_date,
            r.project_legal_entity, r.project_burden_schedule_base, r.project_burden_cost_rate,
            r.award_number, r.award_name, r.award_status, r.award_type, r.award_purpose,
            r.award_start_date, r.award_end_date,
            NULLIF(TRIM(r.cfda), '') AS cfda,
            NULLIF(TRIM(r.sponsor_award_number), '') AS sponsor_award_number,
            NULLIF(REPLACE(TRIM(r.sponsor_award_number), '-', ''), '') AS sponsor_award_key,
            CASE
                WHEN POSITION('.' IN TRIM(r.cfda)) > 0
                THEN LEFT(TRIM(r.cfda), POSITION('.' IN TRIM(r.cfda)))
                     || LEFT(SUBSTRING(TRIM(r.cfda), POSITION('.' IN TRIM(r.cfda)) + 1, 10) || '000', 3)
                ELSE NULLIF(TRIM(r.cfda), '')
            END AS cfda_program_number,
            r.primary_sponsor, r.primary_sponsor_name, r.funding_source_name, r.funding_source_number,
            r.awardfundcode, r.fund, r.owning_org_name,
            NULLIF(LEFT(r.organization, 7), '') AS financial_dept_code,
            CASE WHEN POSITION(' - ' IN r.organization) > 0
                 THEN SUBSTRING(r.organization FROM POSITION(' - ' IN r.organization) + 3)
            END AS financial_dept_name,
            r.budget_period, r.budget_start_date, r.budget_end_date,
            p.principal_investigator_names, p.pi_persons, p.award_copi_names,
            p.project_manager_names, p.grant_administrators, p.contract_admins
        FROM ranked r
        JOIN people p USING (project_id)
        WHERE r.rn = 1
        """;

    private static string BuildPeopleAggregateSelectList() =>
        string.Join(
            ",\n",
            PeopleAggregateFields.Select(field =>
                $"            CAST(LISTAGG(DISTINCT {field.SourceColumn}, '; ') AS VARCHAR({MaxInlineAggregateLength})) AS {field.RemoteAlias}"));

    private sealed record PeopleAggregateField(
        string SourceColumn,
        string RemoteAlias,
        string DestinationColumn,
        string DisplayName);

    private sealed record PeopleAggregateLengths(long ProjectId, long[] FieldLengths);
}
