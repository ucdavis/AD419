using System.Data;
using System.Diagnostics;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Server.Core.Data;
using Server.Models;
using Server.Models.ProjectList;
using Server.Models.SegmentClassifications;

namespace Server.ProjectList;

public sealed class ProjectListService(
    DataDbContext dataDbContext,
    IConfiguration configuration) : IProjectListService
{
    private const string CleanStatus = "Clean";
    private const string NoPgmMatchStatus = "No PGM match";
    private const string NotInAllProjectsStatus = "Not in All Projects";
    private const string SfnMismatchStatus = "SFN mismatch";
    private const string BuildProjectsLockName = "AD419:data.BuildProjects";
    private static readonly ActivitySource ActivitySource = new("Server.ProjectList");

    public async Task<ProjectListResponse> GetAsync(FiscalYearCycle cycle, CancellationToken cancellationToken)
    {
        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);

        var rows = (await connection.QueryAsync<ProjectListRowDto>(new CommandDefinition(
            "[data].[GetProjectList]",
            CycleParameters(cycle),
            commandType: CommandType.StoredProcedure,
            commandTimeout: DataDbConnection.ImportCommandTimeoutSeconds,
            cancellationToken: cancellationToken))).ToList();

        var summaryCounts = await connection.QuerySingleAsync<ProjectListSummaryCounts>(new CommandDefinition(
            SummaryCountsSql,
            new
            {
                cycleStart = cycle.CycleStart.ToDateTime(TimeOnly.MinValue),
                cycleEnd = cycle.CycleEnd.ToDateTime(TimeOnly.MinValue),
            },
            commandTimeout: DataDbConnection.ImportCommandTimeoutSeconds,
            cancellationToken: cancellationToken));

        return ProjectListResponseFactory.Create(
            cycle,
            rows,
            summaryCounts.ActiveNifa,
            summaryCounts.AllNifa,
            summaryCounts.PgmRecords,
            summaryCounts.AlnCodes);
    }

    public async Task<bool> HasResolutionEditsAsync(CancellationToken cancellationToken)
    {
        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);

        return await connection.ExecuteScalarAsync<bool>(new CommandDefinition(
            """
            SELECT CAST(CASE WHEN EXISTS
            (
                SELECT 1
                FROM [data].[ActiveProjects]
                WHERE ISNULL([ExcludeFromUi], 0) = 1
                   OR [AllProjectIdOverride] IS NOT NULL
                   OR [PgmAwardKeyOverrideNormalized] IS NOT NULL
                   OR NULLIF(LTRIM(RTRIM([SfnOverride])), '') IS NOT NULL
            )
            THEN 1 ELSE 0 END AS BIT);
            """,
            commandTimeout: DataDbConnection.ImportCommandTimeoutSeconds,
            cancellationToken: cancellationToken));
    }

    public async Task<IReadOnlyList<AllProjectCandidateDto>> GetAllProjectCandidatesAsync(
        FiscalYearCycle cycle,
        string accession,
        string? search,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(accession))
        {
            return [];
        }

        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);

        var candidates = await connection.QueryAsync<AllProjectCandidateRow>(new CommandDefinition(
            AllProjectCandidatesSql,
            new ProjectListQueryParameters(
                accession.Trim(),
                NormalizeSearch(search),
                cycle.CycleStart.ToDateTime(TimeOnly.MinValue),
                cycle.CycleEnd.ToDateTime(TimeOnly.MinValue)),
            commandTimeout: DataDbConnection.ImportCommandTimeoutSeconds,
            cancellationToken: cancellationToken));

        return candidates
            .Select(candidate => new AllProjectCandidateDto(
                candidate.AllProjectId,
                candidate.AccessionNumber,
                candidate.ProjectNumber,
                candidate.AwardNumber,
                candidate.Title,
                candidate.Department,
                candidate.ProjectDirector,
                ToDateOnly(candidate.ProjectStartDate),
                ToDateOnly(candidate.ProjectEndDate)))
            .ToList();
    }

    public async Task<IReadOnlyList<PgmAwardCandidateDto>> GetPgmAwardCandidatesAsync(
        FiscalYearCycle cycle,
        string accession,
        string? search,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(accession))
        {
            return [];
        }

        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);

        var candidates = await connection.QueryAsync<PgmAwardCandidateRow>(new CommandDefinition(
            PgmAwardCandidatesSql,
            new ProjectListQueryParameters(
                accession.Trim(),
                NormalizeSearch(search),
                cycle.CycleStart.ToDateTime(TimeOnly.MinValue),
                cycle.CycleEnd.ToDateTime(TimeOnly.MinValue)),
            commandTimeout: DataDbConnection.ImportCommandTimeoutSeconds,
            cancellationToken: cancellationToken));

        return candidates
            .Select(candidate => new PgmAwardCandidateDto(
                candidate.AwardKey,
                candidate.SponsorAwardNumber,
                candidate.AwardName,
                candidate.ProjectNumbers,
                candidate.PgmSfnBucket,
                candidate.PrincipalInvestigatorNames))
            .ToList();
    }

    public async Task<IReadOnlyList<SfnCandidateDto>> GetSfnCandidatesAsync(
        FiscalYearCycle cycle,
        string accession,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(accession))
        {
            return [];
        }

        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);

        var values = (await connection.QueryAsync<SfnCandidateRow>(new CommandDefinition(
            SfnCandidateValuesSql,
            new ProjectListQueryParameters(
                accession.Trim(),
                null,
                cycle.CycleStart.ToDateTime(TimeOnly.MinValue),
                cycle.CycleEnd.ToDateTime(TimeOnly.MinValue)),
            commandTimeout: DataDbConnection.ImportCommandTimeoutSeconds,
            cancellationToken: cancellationToken))).ToList();

        var candidates = new List<SfnCandidateDto>();
        foreach (var row in values)
        {
            AddSfnCandidate(candidates, row.NifaSfn, "NIFA project suffix");

            var pgmSfn = row.PgmSfnBucket switch
            {
                "203" or "204" or "205" => row.PgmSfnBucket,
                "HATCH" when row.NifaSfn is "201" or "202" => row.NifaSfn,
                _ => null,
            };
            AddSfnCandidate(candidates, pgmSfn, "PGM master data");
        }

        return candidates;
    }

    public async Task<ProjectListUpdateResult> ExcludeAsync(
        FiscalYearCycle cycle,
        string accession,
        CancellationToken cancellationToken)
    {
        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(cancellationToken);

        var statusResult = await ValidateCurrentStatusAsync(
            connection,
            transaction,
            cycle,
            accession,
            [NoPgmMatchStatus, NotInAllProjectsStatus],
            cancellationToken);
        if (statusResult is not null)
        {
            return statusResult;
        }

        var rows = await connection.ExecuteAsync(new CommandDefinition(
            """
            UPDATE [data].[ActiveProjects]
            SET [ExcludeFromUi] = 1
            WHERE [AccessionNumber] = @accession
              AND EXISTS
              (
                  SELECT 1
                  FROM [data].[ProjectListForCycle](@cycleStart, @cycleEnd)
                  WHERE [Accession] = @accession
              );
            """,
            ActionParameters(cycle, accession),
            transaction: transaction,
            commandTimeout: DataDbConnection.ImportCommandTimeoutSeconds,
            cancellationToken: cancellationToken));

        if (rows == 1)
        {
            await transaction.CommitAsync(cancellationToken);
            return ProjectListUpdateResult.Updated;
        }

        return new ProjectListUpdateResult(ProjectListUpdateStatus.NotFound, "Project row was not found.");
    }

    public async Task<ProjectListUpdateResult> LinkAllProjectAsync(
        FiscalYearCycle cycle,
        string accession,
        int allProjectId,
        CancellationToken cancellationToken)
    {
        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(cancellationToken);

        var statusResult = await ValidateCurrentStatusAsync(
            connection,
            transaction,
            cycle,
            accession,
            [NotInAllProjectsStatus],
            cancellationToken);
        if (statusResult is not null)
        {
            return statusResult;
        }

        var exists = await connection.ExecuteScalarAsync<int>(new CommandDefinition(
            """
            SELECT COUNT(1)
            FROM [data].[AllProjects]
            WHERE [AllProjectId] = @allProjectId
              AND ([ProjectEndDate] IS NULL OR [ProjectEndDate] >= @cycleStart)
              AND ([ProjectStartDate] IS NULL OR [ProjectStartDate] <= @cycleEnd);
            """,
            new
            {
                allProjectId,
                cycleStart = cycle.CycleStart.ToDateTime(TimeOnly.MinValue),
                cycleEnd = cycle.CycleEnd.ToDateTime(TimeOnly.MinValue),
            },
            transaction: transaction,
            commandTimeout: DataDbConnection.ImportCommandTimeoutSeconds,
            cancellationToken: cancellationToken));
        if (exists == 0)
        {
            return new ProjectListUpdateResult(ProjectListUpdateStatus.InvalidRequest, "All Projects row was not found.");
        }

        var rows = await connection.ExecuteAsync(new CommandDefinition(
            """
            UPDATE [data].[ActiveProjects]
            SET [AllProjectIdOverride] = @allProjectId
            WHERE [AccessionNumber] = @accession
              AND EXISTS
              (
                  SELECT 1
                  FROM [data].[ProjectListForCycle](@cycleStart, @cycleEnd)
                  WHERE [Accession] = @accession
              );
            """,
            new
            {
                accession = accession.Trim(),
                allProjectId,
                cycleStart = cycle.CycleStart.ToDateTime(TimeOnly.MinValue),
                cycleEnd = cycle.CycleEnd.ToDateTime(TimeOnly.MinValue),
            },
            transaction: transaction,
            commandTimeout: DataDbConnection.ImportCommandTimeoutSeconds,
            cancellationToken: cancellationToken));

        if (rows == 1)
        {
            await transaction.CommitAsync(cancellationToken);
            return ProjectListUpdateResult.Updated;
        }

        return new ProjectListUpdateResult(ProjectListUpdateStatus.NotFound, "Project row was not found.");
    }

    public async Task<ProjectListUpdateResult> LinkPgmAwardAsync(
        FiscalYearCycle cycle,
        string accession,
        string awardKey,
        CancellationToken cancellationToken)
    {
        var normalizedAwardKey = NormalizeAwardKey(awardKey);
        if (string.IsNullOrWhiteSpace(normalizedAwardKey))
        {
            return new ProjectListUpdateResult(ProjectListUpdateStatus.InvalidRequest, "Award key is required.");
        }

        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(cancellationToken);

        var statusResult = await ValidateCurrentStatusAsync(
            connection,
            transaction,
            cycle,
            accession,
            [NoPgmMatchStatus],
            cancellationToken);
        if (statusResult is not null)
        {
            return statusResult;
        }

        var exists = await connection.ExecuteScalarAsync<int>(new CommandDefinition(
            """
            SELECT COUNT(1)
            FROM [data].[v_PgmProjectSfnBuckets]
            WHERE [AwardKey] = @awardKey;
            """,
            new { awardKey = normalizedAwardKey },
            transaction: transaction,
            commandTimeout: DataDbConnection.ImportCommandTimeoutSeconds,
            cancellationToken: cancellationToken));
        if (exists == 0)
        {
            return new ProjectListUpdateResult(ProjectListUpdateStatus.InvalidRequest, "PGM award was not found.");
        }

        var rows = await connection.ExecuteAsync(new CommandDefinition(
            """
            UPDATE [data].[ActiveProjects]
            SET [PgmAwardKeyOverride] = @awardKey
            WHERE [AccessionNumber] = @accession
              AND EXISTS
              (
                  SELECT 1
                  FROM [data].[ProjectListForCycle](@cycleStart, @cycleEnd)
                  WHERE [Accession] = @accession
              );
            """,
            new
            {
                accession = accession.Trim(),
                awardKey = normalizedAwardKey,
                cycleStart = cycle.CycleStart.ToDateTime(TimeOnly.MinValue),
                cycleEnd = cycle.CycleEnd.ToDateTime(TimeOnly.MinValue),
            },
            transaction: transaction,
            commandTimeout: DataDbConnection.ImportCommandTimeoutSeconds,
            cancellationToken: cancellationToken));

        if (rows == 1)
        {
            await transaction.CommitAsync(cancellationToken);
            return ProjectListUpdateResult.Updated;
        }

        return new ProjectListUpdateResult(ProjectListUpdateStatus.NotFound, "Project row was not found.");
    }

    public async Task<ProjectListUpdateResult> SetSfnAsync(
        FiscalYearCycle cycle,
        string accession,
        string sfn,
        CancellationToken cancellationToken)
    {
        var normalizedSfn = sfn.Trim();
        if (!SfnCatalog.Entries.Any(entry => entry.Code == normalizedSfn))
        {
            return new ProjectListUpdateResult(ProjectListUpdateStatus.InvalidRequest, "SFN is not valid for project resolution.");
        }

        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(cancellationToken);

        var statusResult = await ValidateCurrentStatusAsync(
            connection,
            transaction,
            cycle,
            accession,
            [SfnMismatchStatus],
            cancellationToken);
        if (statusResult is not null)
        {
            return statusResult;
        }

        var rows = await connection.ExecuteAsync(new CommandDefinition(
            """
            UPDATE [data].[ActiveProjects]
            SET [SfnOverride] = @sfn
            WHERE [AccessionNumber] = @accession
              AND EXISTS
              (
                  SELECT 1
                  FROM [data].[ProjectListForCycle](@cycleStart, @cycleEnd)
                  WHERE [Accession] = @accession
              );
            """,
            new
            {
                accession = accession.Trim(),
                sfn = normalizedSfn,
                cycleStart = cycle.CycleStart.ToDateTime(TimeOnly.MinValue),
                cycleEnd = cycle.CycleEnd.ToDateTime(TimeOnly.MinValue),
            },
            transaction: transaction,
            commandTimeout: DataDbConnection.ImportCommandTimeoutSeconds,
            cancellationToken: cancellationToken));

        if (rows == 1)
        {
            await transaction.CommitAsync(cancellationToken);
            return ProjectListUpdateResult.Updated;
        }

        return new ProjectListUpdateResult(ProjectListUpdateStatus.NotFound, "Project row was not found.");
    }

    public async Task<int> BuildProjectsAsync(FiscalYearCycle cycle, CancellationToken cancellationToken)
    {
        using var activity = ActivitySource.StartActivity("BuildProjects");
        activity?.SetTag("ad419.fiscal_year", cycle.FiscalYear);
        activity?.SetTag("ad419.cycle_start", cycle.CycleStart.ToString("O"));
        activity?.SetTag("ad419.cycle_end", cycle.CycleEnd.ToString("O"));

        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(cancellationToken);

        var lockResult = await connection.ExecuteScalarAsync<int>(new CommandDefinition(
            """
            DECLARE @result INT;

            EXEC @result = sp_getapplock
                @Resource = @resource,
                @LockMode = 'Exclusive',
                @LockOwner = 'Transaction',
                @LockTimeout = @lockTimeout;

            SELECT @result;
            """,
            new
            {
                resource = BuildProjectsLockName,
                lockTimeout = DataDbConnection.ImportCommandTimeoutSeconds * 1000,
            },
            transaction: transaction,
            commandTimeout: DataDbConnection.ImportCommandTimeoutSeconds,
            cancellationToken: cancellationToken));

        if (lockResult < 0)
        {
            activity?.SetTag("ad419.lock_acquired", false);
            throw new InvalidOperationException("Project rebuild is already running.");
        }

        activity?.SetTag("ad419.lock_acquired", true);

        var result = await connection.QuerySingleAsync<ProjectRowsBuiltResult>(new CommandDefinition(
            "[data].[BuildProjects]",
            CycleParameters(cycle),
            transaction: transaction,
            commandType: CommandType.StoredProcedure,
            commandTimeout: DataDbConnection.ImportCommandTimeoutSeconds,
            cancellationToken: cancellationToken));

        await transaction.CommitAsync(cancellationToken);
        activity?.SetTag("ad419.rows_built", result.ProjectRowsBuilt);
        return result.ProjectRowsBuilt;
    }

    private SqlConnection CreateConnection()
    {
        var connectionString = DataDbConnection.Resolve(
            configuration,
            dataDbContext.Database.GetConnectionString());

        return new SqlConnection(connectionString);
    }

    private static string? NormalizeSearch(string? search)
    {
        if (string.IsNullOrWhiteSpace(search))
        {
            return null;
        }

        return search
            .Trim()
            .Replace(@"\", @"\\", StringComparison.Ordinal)
            .Replace("%", @"\%", StringComparison.Ordinal)
            .Replace("_", @"\_", StringComparison.Ordinal)
            .Replace("[", @"\[", StringComparison.Ordinal);
    }

    private static string NormalizeAwardKey(string awardKey) =>
        awardKey.Trim().Replace("-", "", StringComparison.Ordinal);

    private static CycleQueryParameters CycleParameters(FiscalYearCycle cycle) =>
        new(
            cycle.CycleStart.ToDateTime(TimeOnly.MinValue),
            cycle.CycleEnd.ToDateTime(TimeOnly.MinValue));

    private static ResolutionActionParameters ActionParameters(
        FiscalYearCycle cycle,
        string accession) =>
        new(
            accession.Trim(),
            cycle.CycleStart.ToDateTime(TimeOnly.MinValue),
            cycle.CycleEnd.ToDateTime(TimeOnly.MinValue));

    private static void AddSfnCandidate(
        List<SfnCandidateDto> candidates,
        string? sfn,
        string source)
    {
        if (string.IsNullOrWhiteSpace(sfn)
            || !SfnCatalog.Entries.Any(entry => entry.Code == sfn)
            || candidates.Any(candidate => candidate.Sfn == sfn && candidate.Source == source))
        {
            return;
        }

        candidates.Add(new SfnCandidateDto(sfn, source));
    }

    private static DateOnly? ToDateOnly(DateTime? value)
    {
        if (!value.HasValue)
        {
            return null;
        }

        return DateOnly.FromDateTime(value.Value);
    }

    private static async Task<ProjectListUpdateResult?> ValidateCurrentStatusAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        FiscalYearCycle cycle,
        string accession,
        IReadOnlyCollection<string>? allowedStatuses,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(accession))
        {
            return new ProjectListUpdateResult(ProjectListUpdateStatus.InvalidRequest, "Accession number is required.");
        }

        var status = await connection.QuerySingleOrDefaultAsync<string>(new CommandDefinition(
            """
            SELECT [Status]
            FROM [data].[ProjectListForCycle](@cycleStart, @cycleEnd)
            WHERE [Accession] = @accession;
            """,
            new
            {
                accession = accession.Trim(),
                cycleStart = cycle.CycleStart.ToDateTime(TimeOnly.MinValue),
                cycleEnd = cycle.CycleEnd.ToDateTime(TimeOnly.MinValue),
            },
            transaction: transaction,
            commandTimeout: DataDbConnection.ImportCommandTimeoutSeconds,
            cancellationToken: cancellationToken));

        if (status is null)
        {
            return new ProjectListUpdateResult(ProjectListUpdateStatus.NotFound, "Project row was not found.");
        }

        if (status == CleanStatus || (allowedStatuses is not null && !allowedStatuses.Contains(status)))
        {
            return new ProjectListUpdateResult(
                ProjectListUpdateStatus.Conflict,
                $"Project has status '{status}' and cannot use that resolution action.");
        }

        return null;
    }

    private const string SummaryCountsSql = """
        SELECT
            ActiveNifa = (
                SELECT COUNT(*)
                FROM [data].[ActiveProjects]
                WHERE ISNULL([ExcludeFromUi], 0) = 0
            ),
            AllNifa = (
                SELECT COUNT(*)
                FROM [data].[AllProjects]
                WHERE ([ProjectEndDate] IS NULL OR [ProjectEndDate] >= @cycleStart)
                  AND ([ProjectStartDate] IS NULL OR [ProjectStartDate] <= @cycleEnd)
            ),
            PgmRecords = (
                SELECT COUNT(*)
                FROM [data].[PGMProjects]
            ),
            AlnCodes = (
                SELECT COUNT(*)
                FROM [data].[AssistanceListingNumbers]
                WHERE [ProgramNumber] IS NOT NULL
            );
        """;

    private const string AllProjectCandidatesSql = """
        WITH CurrentProject AS
        (
            SELECT
                [AccessionNumber],
                [ProjectNumber],
                [AccessionNumberNormalized],
                [ProjectNumberNormalized]
            FROM [data].[ActiveProjects]
            WHERE [AccessionNumber] = @accession
        )
        SELECT TOP (50)
            ap.[AllProjectId],
            ap.[AccessionNumber],
            ap.[ProjectNumber],
            ap.[AwardNumber],
            CAST(ap.[Title] AS NVARCHAR(MAX)) AS [Title],
            ap.[Department],
            ap.[ProjectDirector],
            ap.[ProjectStartDate],
            ap.[ProjectEndDate]
        FROM [data].[AllProjects] ap
        LEFT JOIN CurrentProject cp
            ON 1 = 1
        WHERE (ap.[ProjectEndDate] IS NULL OR ap.[ProjectEndDate] >= @cycleStart)
          AND (ap.[ProjectStartDate] IS NULL OR ap.[ProjectStartDate] <= @cycleEnd)
          AND (
                @search IS NULL
                OR ap.[ProjectNumber] LIKE '%' + @search + '%' ESCAPE '\'
                OR ap.[AccessionNumber] LIKE '%' + @search + '%' ESCAPE '\'
                OR ap.[AwardNumber] LIKE '%' + @search + '%' ESCAPE '\'
                OR ap.[AwardKey] LIKE '%' + REPLACE(@search, '-', '') + '%' ESCAPE '\'
                OR ap.[Title] LIKE '%' + @search + '%' ESCAPE '\'
                OR ap.[ProjectDirector] LIKE '%' + @search + '%' ESCAPE '\'
                OR ap.[Department] LIKE '%' + @search + '%' ESCAPE '\'
          )
        ORDER BY
            CASE WHEN cp.[ProjectNumberNormalized] IS NOT NULL AND ap.[ProjectNumberNormalized] = cp.[ProjectNumberNormalized] THEN 0 ELSE 1 END,
            CASE WHEN cp.[AccessionNumberNormalized] IS NOT NULL AND ap.[AccessionNumberNormalized] = cp.[AccessionNumberNormalized] THEN 0 ELSE 1 END,
            ap.[AllProjectId];
        """;

    private const string PgmAwardCandidatesSql = """
        WITH CurrentProject AS
        (
            SELECT
                nv.[AwardKey]
            FROM [data].[NifaProjectsForCycle](@cycleStart, @cycleEnd) nv
            WHERE nv.[AccessionNumber] = @accession
        )
        SELECT TOP (50)
            pc.[AwardKey],
            MIN(pc.[SponsorAwardNumber]) AS [SponsorAwardNumber],
            MIN(pgm.[AwardName]) AS [AwardName],
            STRING_AGG(CAST(pc.[ProjectNumber] AS NVARCHAR(MAX)), ', ') AS [ProjectNumbers],
            MIN(pc.[PgmSfnBucket]) AS [PgmSfnBucket],
            MIN(pgm.[PrincipalInvestigatorNames]) AS [PrincipalInvestigatorNames],
            MIN(CASE WHEN cp.[AwardKey] IS NOT NULL AND pc.[AwardKey] = cp.[AwardKey] THEN 0 ELSE 1 END) AS [SortRank]
        FROM [data].[v_PgmProjectSfnBuckets] pc
        INNER JOIN [data].[PGMProjects] pgm
            ON pgm.[ProjectId] = pc.[ProjectId]
        LEFT JOIN CurrentProject cp
            ON 1 = 1
        WHERE pc.[AwardKey] IS NOT NULL
          AND (
                @search IS NULL
                OR pc.[AwardKey] LIKE '%' + REPLACE(@search, '-', '') + '%' ESCAPE '\'
                OR pc.[SponsorAwardNumber] LIKE '%' + @search + '%' ESCAPE '\'
                OR pgm.[AwardName] LIKE '%' + @search + '%' ESCAPE '\'
                OR pc.[ProjectNumber] LIKE '%' + @search + '%' ESCAPE '\'
                OR pgm.[PrincipalInvestigatorNames] LIKE '%' + @search + '%' ESCAPE '\'
          )
        GROUP BY pc.[AwardKey]
        ORDER BY
            [SortRank],
            pc.[AwardKey];
        """;

    private const string SfnCandidateValuesSql = """
        SELECT
            nv.[NifaSfn],
            pc.[PgmSfnBucket]
        FROM [data].[NifaProjectsForCycle](@cycleStart, @cycleEnd) nv
        LEFT JOIN [data].[v_PgmProjectSfnBuckets] pc
            ON pc.[AwardKey] = nv.[AwardKey]
        WHERE nv.[AccessionNumber] = @accession;
        """;

    private sealed record CycleQueryParameters(DateTime CycleStart, DateTime CycleEnd);

    private sealed record ResolutionActionParameters(
        string Accession,
        DateTime CycleStart,
        DateTime CycleEnd);

    private sealed record ProjectListQueryParameters(
        string Accession,
        string? Search,
        DateTime CycleStart,
        DateTime CycleEnd);

    private sealed record ProjectListSummaryCounts(
        int ActiveNifa,
        int AllNifa,
        int PgmRecords,
        int AlnCodes);

    private sealed record AllProjectCandidateRow(
        int AllProjectId,
        string? AccessionNumber,
        string? ProjectNumber,
        string? AwardNumber,
        string? Title,
        string? Department,
        string? ProjectDirector,
        DateTime? ProjectStartDate,
        DateTime? ProjectEndDate);

    private sealed record PgmAwardCandidateRow(
        string AwardKey,
        string? SponsorAwardNumber,
        string? AwardName,
        string? ProjectNumbers,
        string? PgmSfnBucket,
        string? PrincipalInvestigatorNames,
        int SortRank);

    private sealed record SfnCandidateRow(string? NifaSfn, string? PgmSfnBucket);

    private sealed record ProjectRowsBuiltResult(int ProjectRowsBuilt);
}
