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

        await using var reader = await query.ExecuteReaderAsync(cancellationToken);

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

        await bulkCopy.WriteToServerAsync(reader, cancellationToken);
        var rowsImported = (int)bulkCopy.RowsCopied64;

        await transaction.CommitAsync(cancellationToken);

        _logger.LogInformation(
            "Imported {RowCount} PGM projects for report date {ReportDate}",
            rowsImported,
            reportDate);

        return new PgmProjectsImportResult(rowsImported, reportDate);
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
    /// Builds the Redshift query run on the warehouse via the pass-through. The single <c>?</c> is
    /// the report date, bound by <see cref="BuildSourceCommandText"/>. One row per project_id:
    /// single-valued attributes come from the budget period containing the report date (falling
    /// back to the most recent period); people columns aggregate distinct names across all of the
    /// project's rows. Rows with a null project_id are excluded (they otherwise collapse into one
    /// junk bucket). LISTAGG results are cast to a bounded VARCHAR so MSDASQL binds them inline
    /// rather than as LOBs, which EXEC ... AT cannot stream. Redshift also disallows differing
    /// LISTAGG WITHIN GROUP orderings and a trailing semicolon inside the pass-through. LoadedAt is
    /// not selected here; the destination column defaults to it.
    /// </summary>
    public static string BuildRemoteQuery() =>
        """
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
                CAST(LISTAGG(DISTINCT principal_investigator_person_name, '; ') AS VARCHAR(8000)) AS principal_investigator_names,
                CAST(LISTAGG(DISTINCT piperson, '; ') AS VARCHAR(8000)) AS pi_persons,
                CAST(LISTAGG(DISTINCT award_copi_name, '; ') AS VARCHAR(8000)) AS award_copi_names,
                CAST(LISTAGG(DISTINCT project_manager_name, '; ') AS VARCHAR(8000)) AS project_manager_names,
                CAST(LISTAGG(DISTINCT grant_administrator, '; ') AS VARCHAR(8000)) AS grant_administrators,
                CAST(LISTAGG(DISTINCT contractadmin, '; ') AS VARCHAR(8000)) AS contract_admins
            FROM ae_dwh.pgm_master_data
            WHERE project_id IS NOT NULL
            GROUP BY project_id
        )
        SELECT r.project_id, r.project_number, r.project_name, r.project_start_date, r.project_end_date,
            r.project_legal_entity, r.project_burden_schedule_base, r.project_burden_cost_rate,
            r.award_number, r.award_name, r.award_status, r.award_type, r.award_purpose,
            r.award_start_date, r.award_end_date, r.cfda, r.sponsor_award_number,
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
}
