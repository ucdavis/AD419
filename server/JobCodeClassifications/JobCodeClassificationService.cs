using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Server.Core.Data;
using Server.Models;
using Server.Models.JobCodeClassifications;

namespace Server.JobCodeClassifications;

/// <summary>
/// Job code to job SFN classification for the Data Classification stage. A job
/// code gets its FTE line through data.Titles (job code to staff type) and
/// data.StaffTypes (staff type to line); assigning a job code edits its Titles
/// row, so v_TransactionSfn and everything that reads it pick the change up.
/// </summary>
public sealed class JobCodeClassificationService(
    DataDbContext dataDbContext,
    IConfiguration configuration) : IJobCodeClassificationService
{
    private const int JobCodeMaxLength = 4;

    // One row per job code on in-window UCPath payroll that the report
    // includes. Rows the report drops are skipped, so a job code only shows
    // when it is on reported dollars; rows with no job code are skipped too,
    // there is no code to classify.
    // FTE is the reported FTE: like BuildAutoAssociations, a row's FTE counts
    // only when its ERN code is classified included.
    // Matters says whether assigning the job code can change the build. The
    // build works on expense summary rows, not job codes, so SummaryRows
    // groups the way BuildAutoAssociations does and the test is made per
    // summary row. Dollars or FTE that offset across employees or chart
    // strings still leave a summary row each. A summary row counts when the
    // build keeps it and it either reports FTE, which needs a line to land
    // on, or is on State Appropriations (13U02), where rule 220 in
    // AutoAssociationCandidates only associates the dollars on FTE line 241.
    // The build keeps a row that has dollars or FTE, so FTE counts even when
    // its dollars net to zero.
    // SummaryRows leaves out four of the build's grouping columns because
    // they cannot split a job code's rows any further: Source is always
    // UCPath here, OrgR follows the job code and financial department
    // (v_TransactionOrgR), ExpenseSfn follows the fund and project
    // (v_TransactionSfn), and FteSfn follows the job code and the employee
    // (the PI rule in v_TransactionSfn moves a PI from 242 to 241, never to
    // or from NULL).
    // FteSfn is the title's own line, read straight from the lookup rather
    // than from v_TransactionSfn, because this is the value the user edits.
    // The list and the gate share this text so they cannot drift apart.
    private const string ClassifiedJobCodesCte = """
        WITH SummaryRows AS
        (
            SELECT
                u.[JobCode],
                u.[EmployeeId],
                u.[Fund],
                SUM(u.[Amount]) AS [Amount],
                SUM(CASE WHEN incl.[ErnIncludeInReport] = 1 THEN COALESCE(u.[CalculatedFte], 0) ELSE 0 END) AS [Fte]
            FROM [data].[UcPathTransactions] u
            JOIN [data].[v_TransactionInclusion] incl
                ON incl.[Source] = N'UCPath' AND incl.[LaborTransactionId] = u.[LaborTransactionId]
            WHERE CAST(u.[PayPeriodEndDate] AS DATE) BETWEEN @cycleStart AND @cycleEnd
              AND NULLIF(u.[JobCode], N'') IS NOT NULL
              AND incl.[Included] = 1
            GROUP BY u.[JobCode], u.[Entity], u.[Project], u.[Activity], u.[Fund], u.[FinancialDepartment], u.[Account],
                     u.[EmployeeId], u.[EmployeeName]
        ),
        JobCodes AS
        (
            SELECT
                s.[JobCode],
                COUNT(DISTINCT s.[EmployeeId]) AS [EmployeeCount],
                SUM(s.[Amount]) AS [Amount],
                SUM(s.[Fte]) AS [Fte],
                MAX(CASE WHEN s.[Fte] <> 0 OR (s.[Amount] <> 0 AND s.[Fund] = '13U02') THEN 1 ELSE 0 END) AS [Matters]
            FROM SummaryRows s
            GROUP BY s.[JobCode]
        ),
        Classified AS
        (
            SELECT
                j.[JobCode],
                title.[Name] AS [TitleName],
                title.[StaffTypeCode],
                staffType.[FteSfn],
                CAST(CASE WHEN staffType.[FteSfn] IS NULL AND j.[Matters] = 1 THEN 1 ELSE 0 END AS BIT) AS [Blocking],
                j.[EmployeeCount],
                j.[Amount],
                j.[Fte]
            FROM JobCodes j
            LEFT JOIN [data].[Titles] title
                ON title.[TitleCode] = j.[JobCode]
            LEFT JOIN [data].[StaffTypes] staffType
                ON staffType.[StaffTypeCode] = title.[StaffTypeCode]
        )
        """;

    // Blocking codes first, then the other unassigned codes, then assigned ones.
    private const string ListSql = ClassifiedJobCodesCte + """

        SELECT [JobCode], [TitleName], [StaffTypeCode], [FteSfn], [Blocking], [EmployeeCount], [Amount], [Fte]
        FROM Classified
        ORDER BY
            CASE WHEN [Blocking] = 1 THEN 0 WHEN [FteSfn] IS NULL THEN 1 ELSE 2 END,
            [JobCode];
        """;

    private const string HasBlockingSql = ClassifiedJobCodesCte + """

        SELECT CASE WHEN EXISTS (SELECT 1 FROM Classified WHERE [Blocking] = 1) THEN 1 ELSE 0 END;
        """;

    private const string StaffTypeOptionsSql = """
        SELECT [StaffTypeCode], [FteSfn], [Description]
        FROM [data].[StaffTypes]
        WHERE [FteSfn] IS NOT NULL
        ORDER BY [FteSfn], [StaffTypeCode];
        """;

    private const string StaffTypeHasLineSql = """
        SELECT COUNT(1)
        FROM [data].[StaffTypes]
        WHERE [StaffTypeCode] = @staffTypeCode AND [FteSfn] IS NOT NULL;
        """;

    // HOLDLOCK makes the match and the insert one step, so two saves for a job
    // code with no title row cannot both try to insert it.
    private const string AssignSql = """
        MERGE [data].[Titles] WITH (HOLDLOCK) AS target
        USING (SELECT @jobCode AS [TitleCode]) AS source
            ON target.[TitleCode] = source.[TitleCode]
        WHEN MATCHED THEN
            UPDATE SET [StaffTypeCode] = @staffTypeCode
        WHEN NOT MATCHED THEN
            INSERT ([TitleCode], [StaffTypeCode]) VALUES (@jobCode, @staffTypeCode);
        """;

    public async Task<JobCodeClassificationsResponse> GetAsync(FiscalYearCycle cycle, CancellationToken cancellationToken)
    {
        await using var connection = await OpenAsync(cancellationToken);

        var rows = (await connection.QueryAsync<JobCodeClassificationDto>(
            Command(ListSql, cancellationToken, CycleParameters(cycle)))).ToList();
        var staffTypes = (await connection.QueryAsync<StaffTypeOptionDto>(
            Command(StaffTypeOptionsSql, cancellationToken))).ToList();

        return new JobCodeClassificationsResponse(cycle.FiscalYear, cycle.CycleStart, cycle.CycleEnd, rows, staffTypes);
    }

    public async Task<bool> HasBlockingAsync(FiscalYearCycle cycle, CancellationToken cancellationToken)
    {
        await using var connection = await OpenAsync(cancellationToken);
        var blocking = await connection.ExecuteScalarAsync<int>(
            Command(HasBlockingSql, cancellationToken, CycleParameters(cycle)));
        return blocking == 1;
    }

    public async Task<JobCodeAssignResult> AssignAsync(
        string? jobCode,
        string? staffTypeCode,
        CancellationToken cancellationToken)
    {
        var code = jobCode?.Trim() ?? string.Empty;
        if (code.Length == 0 || code.Length > JobCodeMaxLength)
        {
            return JobCodeAssignResult.InvalidJobCode;
        }

        var staffType = staffTypeCode?.Trim() ?? string.Empty;
        if (staffType.Length == 0)
        {
            return JobCodeAssignResult.InvalidStaffType;
        }

        await using var connection = await OpenAsync(cancellationToken);

        var parameters = new { jobCode = code, staffTypeCode = staffType };
        var hasLine = await connection.ExecuteScalarAsync<int>(
            Command(StaffTypeHasLineSql, cancellationToken, parameters));
        if (hasLine == 0)
        {
            return JobCodeAssignResult.InvalidStaffType;
        }

        await connection.ExecuteAsync(Command(AssignSql, cancellationToken, parameters));
        return JobCodeAssignResult.Assigned;
    }

    private static object CycleParameters(FiscalYearCycle cycle) => new
    {
        cycleStart = cycle.CycleStart.ToDateTime(TimeOnly.MinValue),
        cycleEnd = cycle.CycleEnd.ToDateTime(TimeOnly.MinValue),
    };

    private async Task<SqlConnection> OpenAsync(CancellationToken cancellationToken)
    {
        var connectionString = DataDbConnection.Resolve(configuration, dataDbContext.Database.GetConnectionString());
        var connection = new SqlConnection(connectionString);
        await connection.OpenAsync(cancellationToken);
        return connection;
    }

    private static CommandDefinition Command(string sql, CancellationToken cancellationToken, object? parameters = null) =>
        new(sql, parameters, commandTimeout: DataDbConnection.ImportCommandTimeoutSeconds, cancellationToken: cancellationToken);
}
