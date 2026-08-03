using System.Data;
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
                   OR NULLIF(LTRIM(RTRIM([PgmAwardKeyOverride])), '') IS NOT NULL
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

        var candidates = await connection.QueryAsync<PgmAwardCandidateDto>(new CommandDefinition(
            PgmAwardCandidatesSql,
            new ProjectListQueryParameters(
                accession.Trim(),
                NormalizeSearch(search),
                cycle.CycleStart.ToDateTime(TimeOnly.MinValue),
                cycle.CycleEnd.ToDateTime(TimeOnly.MinValue)),
            commandTimeout: DataDbConnection.ImportCommandTimeoutSeconds,
            cancellationToken: cancellationToken));

        return candidates.ToList();
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

        var statusResult = await ValidateCurrentStatusAsync(
            connection,
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
            WHERE [AccessionNumber] = @accession;
            """,
            new { accession = accession.Trim() },
            commandTimeout: DataDbConnection.ImportCommandTimeoutSeconds,
            cancellationToken: cancellationToken));

        return rows == 1
            ? ProjectListUpdateResult.Updated
            : new ProjectListUpdateResult(ProjectListUpdateStatus.NotFound, "Project row was not found.");
    }

    public async Task<ProjectListUpdateResult> LinkAllProjectAsync(
        FiscalYearCycle cycle,
        string accession,
        int allProjectId,
        CancellationToken cancellationToken)
    {
        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);

        var statusResult = await ValidateCurrentStatusAsync(
            connection,
            cycle,
            accession,
            [NotInAllProjectsStatus],
            cancellationToken);
        if (statusResult is not null)
        {
            return statusResult;
        }

        var exists = await connection.ExecuteScalarAsync<int>(new CommandDefinition(
            "SELECT COUNT(1) FROM [data].[AllProjects] WHERE [AllProjectId] = @allProjectId;",
            new { allProjectId },
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
            WHERE [AccessionNumber] = @accession;
            """,
            new { accession = accession.Trim(), allProjectId },
            commandTimeout: DataDbConnection.ImportCommandTimeoutSeconds,
            cancellationToken: cancellationToken));

        return rows == 1
            ? ProjectListUpdateResult.Updated
            : new ProjectListUpdateResult(ProjectListUpdateStatus.NotFound, "Project row was not found.");
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

        var statusResult = await ValidateCurrentStatusAsync(
            connection,
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
            WHERE [AccessionNumber] = @accession;
            """,
            new { accession = accession.Trim(), awardKey = normalizedAwardKey },
            commandTimeout: DataDbConnection.ImportCommandTimeoutSeconds,
            cancellationToken: cancellationToken));

        return rows == 1
            ? ProjectListUpdateResult.Updated
            : new ProjectListUpdateResult(ProjectListUpdateStatus.NotFound, "Project row was not found.");
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

        var statusResult = await ValidateCurrentStatusAsync(
            connection,
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
            WHERE [AccessionNumber] = @accession;
            """,
            new { accession = accession.Trim(), sfn = normalizedSfn },
            commandTimeout: DataDbConnection.ImportCommandTimeoutSeconds,
            cancellationToken: cancellationToken));

        return rows == 1
            ? ProjectListUpdateResult.Updated
            : new ProjectListUpdateResult(ProjectListUpdateStatus.NotFound, "Project row was not found.");
    }

    public async Task<int> BuildProjectsAsync(FiscalYearCycle cycle, CancellationToken cancellationToken)
    {
        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);

        var result = await connection.QuerySingleAsync<ProjectRowsBuiltResult>(new CommandDefinition(
            "[data].[BuildProjects]",
            CycleParameters(cycle),
            commandType: CommandType.StoredProcedure,
            commandTimeout: DataDbConnection.ImportCommandTimeoutSeconds,
            cancellationToken: cancellationToken));

        return result.ProjectRowsBuilt;
    }

    private SqlConnection CreateConnection()
    {
        var connectionString = DataDbConnection.Resolve(
            configuration,
            dataDbContext.Database.GetConnectionString());

        return new SqlConnection(connectionString);
    }

    private static string? NormalizeSearch(string? search) =>
        string.IsNullOrWhiteSpace(search) ? null : search.Trim();

    private static string NormalizeAwardKey(string awardKey) =>
        awardKey.Trim().Replace("-", "", StringComparison.Ordinal);

    private static CycleQueryParameters CycleParameters(FiscalYearCycle cycle) =>
        new(
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
        FiscalYearCycle cycle,
        string accession,
        IReadOnlyCollection<string>? allowedStatuses,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(accession))
        {
            return new ProjectListUpdateResult(ProjectListUpdateStatus.InvalidRequest, "Accession number is required.");
        }

        var status = await connection.ExecuteScalarAsync<string?>(new CommandDefinition(
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
                [ProjectNumber]
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
        CROSS JOIN CurrentProject cp
        WHERE (ap.[ProjectEndDate] IS NULL OR ap.[ProjectEndDate] >= @cycleStart)
          AND (ap.[ProjectStartDate] IS NULL OR ap.[ProjectStartDate] <= @cycleEnd)
          AND (
                @search IS NULL
                OR ap.[ProjectNumber] LIKE '%' + @search + '%'
                OR ap.[AccessionNumber] LIKE '%' + @search + '%'
                OR ap.[AwardNumber] LIKE '%' + @search + '%'
                OR ap.[Title] LIKE '%' + @search + '%'
                OR ap.[ProjectDirector] LIKE '%' + @search + '%'
                OR ap.[Department] LIKE '%' + @search + '%'
          )
        ORDER BY
            CASE WHEN NULLIF(LTRIM(RTRIM(ap.[ProjectNumber])), '') = NULLIF(LTRIM(RTRIM(cp.[ProjectNumber])), '') THEN 0 ELSE 1 END,
            CASE WHEN NULLIF(LTRIM(RTRIM(ap.[AccessionNumber])), '') = NULLIF(LTRIM(RTRIM(cp.[AccessionNumber])), '') THEN 0 ELSE 1 END,
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
            MIN(CASE WHEN pc.[AwardKey] = cp.[AwardKey] THEN 0 ELSE 1 END) AS [SortRank]
        FROM [data].[v_PgmProjectSfnBuckets] pc
        INNER JOIN [data].[PGMProjects] pgm
            ON pgm.[ProjectId] = pc.[ProjectId]
        CROSS JOIN CurrentProject cp
        WHERE pc.[AwardKey] IS NOT NULL
          AND (
                @search IS NULL
                OR pc.[AwardKey] LIKE '%' + REPLACE(@search, '-', '') + '%'
                OR pc.[SponsorAwardNumber] LIKE '%' + @search + '%'
                OR pgm.[AwardName] LIKE '%' + @search + '%'
                OR pc.[ProjectNumber] LIKE '%' + @search + '%'
                OR pgm.[PrincipalInvestigatorNames] LIKE '%' + @search + '%'
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

    private sealed record SfnCandidateRow(string? NifaSfn, string? PgmSfnBucket);

    private sealed record ProjectRowsBuiltResult(int ProjectRowsBuilt);
}
