using System.Globalization;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Server.Core.Data;

namespace Server.Core.Import;

public sealed class PgmProjectsImportService : IPgmProjectsImportService
{
    public const string ConnectionStringName = "Datamart";

    private const int CommandTimeoutSeconds = 600;
    private const string DestinationTable = "[data].[PGMProjects]";

    // source reader column -> destination table column
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
        ("organization", "Organization"),
        ("budget_period", "BudgetPeriod"),
        ("budget_start_date", "BudgetStartDate"),
        ("budget_end_date", "BudgetEndDate"),
        ("principal_investigator_names", "PrincipalInvestigatorNames"),
        ("pi_persons", "PiPersons"),
        ("award_copi_names", "AwardCopiNames"),
        ("project_manager_names", "ProjectManagerNames"),
        ("grant_administrators", "GrantAdministrators"),
        ("contract_admins", "ContractAdmins"),
        ("LoadedAt", "LoadedAt"),
    ];

    private readonly AppDbContext _dbContext;
    private readonly IConfiguration _configuration;
    private readonly ILogger<PgmProjectsImportService> _logger;

    public PgmProjectsImportService(
        AppDbContext dbContext,
        IConfiguration configuration,
        ILogger<PgmProjectsImportService> logger)
    {
        _dbContext = dbContext;
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

        var destinationConnectionString = _dbContext.Database.GetConnectionString()
            ?? throw new InvalidOperationException("The application database connection string is not available.");

        _logger.LogInformation("Importing PGM projects for report date {ReportDate}", reportDate);

        await using var source = new SqlConnection(sourceConnectionString);
        await source.OpenAsync(cancellationToken);

        await using var query = new SqlCommand(BuildSourceQuery(reportDate), source)
        {
            CommandTimeout = CommandTimeoutSeconds,
        };
        await using var reader = await query.ExecuteReaderAsync(cancellationToken);

        await using var destination = new SqlConnection(destinationConnectionString);
        await destination.OpenAsync(cancellationToken);
        await using var transaction = (SqlTransaction)await destination.BeginTransactionAsync(cancellationToken);

        await using (var truncate = new SqlCommand($"TRUNCATE TABLE {DestinationTable};", destination, transaction))
        {
            await truncate.ExecuteNonQueryAsync(cancellationToken);
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
    /// Builds the T-SQL run against the warehouse gateway server. The inner OPENQUERY string is
    /// executed by Redshift, so it uses Redshift dialect with single quotes doubled for T-SQL.
    /// One row per project_id: attributes come from the budget period containing the report date
    /// (falling back to the most recent period); people columns aggregate distinct names across
    /// all of the project's rows. Redshift disallows differing LISTAGG WITHIN GROUP orderings and
    /// a trailing semicolon inside OPENQUERY.
    /// </summary>
    public static string BuildSourceQuery(DateOnly reportDate)
    {
        var dateLiteral = reportDate.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);

        return $"""
            SELECT q.*, SYSUTCDATETIME() AS LoadedAt
            FROM OPENQUERY(AE_Redshift_PROD, '
            WITH ranked AS (
                SELECT pmd.*,
                    ROW_NUMBER() OVER (
                        PARTITION BY project_id
                        ORDER BY
                            CASE WHEN DATE ''{dateLiteral}''
                                 BETWEEN budget_start_date AND budget_end_date
                                 THEN 0 ELSE 1 END,
                            budget_start_date DESC,
                            contract_line_number
                    ) AS rn
                FROM ae_dwh.pgm_master_data pmd
            ),
            people AS (
                SELECT project_id,
                    LISTAGG(DISTINCT principal_investigator_person_name, ''; '') AS principal_investigator_names,
                    LISTAGG(DISTINCT piperson, ''; '') AS pi_persons,
                    LISTAGG(DISTINCT award_copi_name, ''; '') AS award_copi_names,
                    LISTAGG(DISTINCT project_manager_name, ''; '') AS project_manager_names,
                    LISTAGG(DISTINCT grant_administrator, ''; '') AS grant_administrators,
                    LISTAGG(DISTINCT contractadmin, ''; '') AS contract_admins
                FROM ae_dwh.pgm_master_data
                GROUP BY project_id
            )
            SELECT r.project_id, r.project_number, r.project_name, r.project_start_date, r.project_end_date,
                r.project_legal_entity, r.project_burden_schedule_base, r.project_burden_cost_rate,
                r.award_number, r.award_name, r.award_status, r.award_type, r.award_purpose,
                r.award_start_date, r.award_end_date, r.cfda, r.sponsor_award_number,
                r.primary_sponsor, r.primary_sponsor_name, r.funding_source_name, r.funding_source_number,
                r.awardfundcode, r.fund, r.owning_org_name, r.organization,
                r.budget_period, r.budget_start_date, r.budget_end_date,
                p.principal_investigator_names, p.pi_persons, p.award_copi_names,
                p.project_manager_names, p.grant_administrators, p.contract_admins
            FROM ranked r
            JOIN people p USING (project_id)
            WHERE r.rn = 1
            ') AS q;
            """;
    }
}
