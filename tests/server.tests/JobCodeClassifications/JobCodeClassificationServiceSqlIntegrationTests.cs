using Dapper;
using FluentAssertions;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Server.JobCodeClassifications;
using Server.Models;
using Server.Tests.SqlIntegration;

namespace Server.Tests.JobCodeClassifications;

[Trait("Category", "SqlIntegration")]
[Collection(SqlIntegrationCollection.Name)]
public sealed class JobCodeClassificationServiceSqlIntegrationTests(SqlServerDataDbFixture fixture)
{
    [Fact]
    public async Task Get_lists_every_job_code_on_included_in_window_payroll_with_its_line()
    {
        await fixture.ClearDataTablesAsync();
        await JobCodeSeeds.SeedBaseScenarioAsync(fixture);
        await JobCodeSeeds.SeedJobCodeRowsAsync(fixture);
        await JobCodeSeeds.SeedJobCodeRowsExcludedFromReportAsync(fixture);

        var response = await CreateService().GetAsync(Cycle(), CancellationToken.None);

        response.FiscalYear.Should().Be("FY25");
        response.CycleStart.Should().Be(new DateOnly(2024, 10, 1));
        response.CycleEnd.Should().Be(new DateOnly(2025, 9, 30));

        var assigned = response.Rows.Single(row => row.JobCode == "1234");
        assigned.TitleName.Should().Be("Professor");
        assigned.StaffTypeCode.Should().Be("PROF");
        assigned.FteSfn.Should().Be("241");
        assigned.Blocking.Should().BeFalse();
        assigned.EmployeeCount.Should().Be(1);
        assigned.Amount.Should().Be(10m);
        assigned.Fte.Should().Be(0.100000m);

        // 0000 has two included rows; its out of window and flagged rows do not count.
        var noTitle = response.Rows.Single(row => row.JobCode == "0000");
        noTitle.TitleName.Should().BeNull();
        noTitle.StaffTypeCode.Should().BeNull();
        noTitle.FteSfn.Should().BeNull();
        noTitle.EmployeeCount.Should().Be(1);
        noTitle.Amount.Should().Be(30m);
        noTitle.Fte.Should().Be(0.300000m);

        // 5678 has one included row and one on the excluded fund.
        var noStaffType = response.Rows.Single(row => row.JobCode == "5678");
        noStaffType.Amount.Should().Be(10m);
        noStaffType.Fte.Should().Be(0.050000m);

        // 4460 is only outside the window, 4444 only on an excluded fund and
        // 4445 only on an unclassified department. Rows with a missing or
        // blank job code have nothing to classify.
        response.Rows.Select(row => row.JobCode).Should().BeEquivalentTo(["0000", "5678", "7777", "9999", "1234"]);
    }

    [Fact]
    public async Task Get_marks_unassigned_codes_that_matter_as_blocking()
    {
        await fixture.ClearDataTablesAsync();
        await JobCodeSeeds.SeedBaseScenarioAsync(fixture);
        await JobCodeSeeds.SeedJobCodeRowsAsync(fixture);
        await JobCodeSeeds.SeedJobCodeRowsWithoutReportedFteAsync(fixture);
        await JobCodeSeeds.SeedJobCodeRowsOnStateAppropriationsAsync(fixture);

        var response = await CreateService().GetAsync(Cycle(), CancellationToken.None);
        var rows = response.Rows.ToDictionary(row => row.JobCode);

        // No title, a title with no staff type, a staff type with no row and a
        // staff type with no line all leave reported FTE without a line.
        rows["0000"].Blocking.Should().BeTrue();
        rows["5678"].Blocking.Should().BeTrue();
        rows["7777"].Blocking.Should().BeTrue();
        rows["7777"].StaffTypeCode.Should().Be("GHOST");
        rows["7777"].FteSfn.Should().BeNull();
        rows["9999"].Blocking.Should().BeTrue();
        rows["9999"].StaffTypeCode.Should().Be("NOLINE");
        rows["9999"].FteSfn.Should().BeNull();

        // 4448 reports no FTE but has State Appropriations dollars, which rule
        // 220 only associates on line 241.
        rows["4448"].Blocking.Should().BeTrue();
        rows["4448"].Amount.Should().Be(40m);
        rows["4448"].Fte.Should().Be(0m);

        // Listed and assignable, but nothing rides on them: no reported FTE
        // off 13U02 (zero FTE, or FTE only on an excluded ERN), or 13U02
        // dollars that net to zero.
        rows["4446"].Blocking.Should().BeFalse();
        rows["4447"].Blocking.Should().BeFalse();
        rows["4447"].Fte.Should().Be(0m);
        rows["4449"].Blocking.Should().BeFalse();
        rows["4449"].Amount.Should().Be(0m);

        rows["1234"].Blocking.Should().BeFalse();
    }

    [Fact]
    public async Task Get_orders_blocking_then_other_unassigned_then_assigned_each_by_job_code()
    {
        await fixture.ClearDataTablesAsync();
        await JobCodeSeeds.SeedBaseScenarioAsync(fixture);
        await JobCodeSeeds.SeedJobCodeRowsAsync(fixture);
        await JobCodeSeeds.SeedJobCodeRowsWithoutReportedFteAsync(fixture);
        await JobCodeSeeds.SeedJobCodeRowsOnStateAppropriationsAsync(fixture);

        var response = await CreateService().GetAsync(Cycle(), CancellationToken.None);

        response.Rows.Select(row => row.JobCode).Should().Equal(
            "0000", "4448", "5678", "7777", "9999",
            "4446", "4447", "4449",
            "1234");
    }

    [Fact]
    public async Task Get_returns_staff_type_options_that_have_a_line()
    {
        await fixture.ClearDataTablesAsync();
        await JobCodeSeeds.SeedBaseScenarioAsync(fixture);
        await JobCodeSeeds.SeedJobCodeRowsAsync(fixture);
        await ExecuteAsync(
            """
            INSERT INTO [data].[StaffTypes] ([StaffTypeCode], [FteSfn], [Description])
            VALUES ('TECH', '243', 'Technical Support'), ('EMER', '241', NULL);
            """);

        var response = await CreateService().GetAsync(Cycle(), CancellationToken.None);

        // NOLINE has no line. Two staff types share line 241 and both are offered.
        response.StaffTypes.Select(option => (option.StaffTypeCode, option.FteSfn, option.Description)).Should().Equal(
            ("EMER", "241", null),
            ("PROF", "241", "Professors"),
            ("TECH", "243", "Technical Support"));
    }

    [Fact]
    public async Task HasBlocking_matches_the_list()
    {
        await fixture.ClearDataTablesAsync();
        await JobCodeSeeds.SeedBaseScenarioAsync(fixture);
        await JobCodeSeeds.SeedJobCodeRowsAsync(fixture);
        await JobCodeSeeds.SeedJobCodeRowsWithoutReportedFteAsync(fixture);
        await JobCodeSeeds.SeedJobCodeRowsOnStateAppropriationsAsync(fixture);
        var service = CreateService();

        (await service.HasBlockingAsync(Cycle(), CancellationToken.None)).Should().BeTrue();

        var blocking = (await service.GetAsync(Cycle(), CancellationToken.None)).Rows.Where(row => row.Blocking).ToList();
        blocking.Should().NotBeEmpty();
        foreach (var row in blocking)
        {
            (await service.AssignAsync(row.JobCode, "PROF", CancellationToken.None)).Should().Be(JobCodeAssignResult.Assigned);
        }

        // 4446, 4447 and 4449 are still unassigned, and none of them blocks.
        (await service.HasBlockingAsync(Cycle(), CancellationToken.None)).Should().BeFalse();
        (await service.GetAsync(Cycle(), CancellationToken.None)).Rows.Should().NotContain(row => row.Blocking);
    }

    [Fact]
    public async Task Blocking_codes_are_the_ones_the_built_summary_leaves_without_a_line()
    {
        await fixture.ClearDataTablesAsync();
        await JobCodeSeeds.SeedBaseScenarioAsync(fixture);
        await JobCodeSeeds.SeedJobCodeRowsAsync(fixture);
        await JobCodeSeeds.SeedJobCodeRowsExcludedFromReportAsync(fixture);
        await JobCodeSeeds.SeedJobCodeRowsWithoutReportedFteAsync(fixture);
        await JobCodeSeeds.SeedJobCodeRowsOnStateAppropriationsAsync(fixture);
        await JobCodeSeeds.SeedJobCodeRowsOffsettingAcrossSummaryRowsAsync(fixture);

        // BuildAutoAssociations needs an OrgR for every included row and a
        // project list. 4461 has 13U02 dollars for one PI that offset across
        // two accounts, the newest column in the build's grouping.
        await ExecuteAsync(
            """
            INSERT INTO [data].[OrgRs] ([Code]) VALUES ('AAAA'), ('BBBB');

            INSERT INTO [data].[OrgRFinancialDepartments] ([FinancialDepartment], [OrgR])
            VALUES ('D1', 'AAAA'), ('D2', 'BBBB');

            INSERT INTO [data].[Projects] ([AccessionNumber], [NifaProjectNumber], [Is204], [Sfn], [UcpEmployeeId])
            VALUES
                ('1000001', 'CA-D-ABC-1001-H', 0, '201', '30000013'),
                ('1000002', 'CA-D-ABC-1002-H', 0, '201', '30000014');

            INSERT INTO [data].[SegmentClassifications] ([SegmentType], [Code], [Description], [IncludeInReport], [Sfn])
            VALUES ('Account', 'A2', 'Account Two', 1, NULL);

            INSERT INTO [data].[UcPathTransactions]
                ([LaborTransactionId], [Entity], [Fund], [FinancialDepartment], [ParentDepartment], [Account],
                 [Purpose], [Program], [Project], [Activity], [ErnCode], [EmployeeId], [PositionNumber], [JobCode],
                 [Hours], [Amount], [CalculatedFte], [PayPeriodEndDate], [FringeBenefitSalaryCd],
                 [FiscalYear], [Period], [EmpRcd], [EffSeq], [ExcludedByDate], [AccountNotInAE])
            VALUES
                ('JC-STATE-OFFSET-ACCOUNT-A', '3310', '13U02', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000026', 'POS26', '4461', 0,  25.00, 0.000000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('JC-STATE-OFFSET-ACCOUNT-B', '3310', '13U02', 'D1', 'D1', 'A2', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000026', 'POS26', '4461', 0, -25.00, 0.000000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0);
            """);

        var cycle = Cycle();
        var window = new { cycleStart = cycle.CycleStart.ToDateTime(TimeOnly.MinValue), cycleEnd = cycle.CycleEnd.ToDateTime(TimeOnly.MinValue) };
        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();
        await connection.ExecuteAsync("EXEC [data].[BuildAutoAssociations] @cycleStart, @cycleEnd", window);

        // The service regroups transactions itself, so this checks that its
        // grouping agrees with the summary the build really produced: the same
        // test (FTE, or on 13U02) applied to the built rows picks the same codes.
        var expected = (await connection.QueryAsync<string>(
            """
            SELECT DISTINCT [JobCode]
            FROM [data].[ExpenseSummary]
            WHERE [Source] = N'UCPath'
              AND [FteSfn] IS NULL
              AND NULLIF([JobCode], N'') IS NOT NULL
              AND ([Fte] <> 0 OR [Fund] = '13U02')
            """)).ToList();

        var service = CreateService();
        var response = await service.GetAsync(cycle, CancellationToken.None);

        // 4450 and 4451 offset across employees, 4454 to 4459 across the other
        // grouping columns. 4452's FTE cancels inside one summary row and
        // 4453's dollars net to zero, so the build has nothing for them.
        expected.Should().Contain(["0000", "4448", "4450", "4451", "4454", "4455", "4456", "4457", "4458", "4459", "4461"]);
        expected.Should().NotContain(["4452", "4453"]);
        response.Rows.Where(row => row.Blocking).Select(row => row.JobCode).Should().BeEquivalentTo(expected);

        // Why 4450 has to block: nothing of it is associated yet, and
        // assigning it to line 241 gives rule 220 a row for each PI.
        const string staged4450Sql =
            """
            SELECT s.[EmployeeId], a.[Expenses]
            FROM [data].[StagedAssociations] a
            JOIN [data].[ExpenseSummary] s ON s.[ExpenseId] = a.[ExpenseId]
            WHERE a.[Rule] = N'220' AND s.[JobCode] = '4450'
            """;
        (await connection.QueryAsync<(string EmployeeId, decimal Expenses)>(staged4450Sql)).Should().BeEmpty();

        (await service.AssignAsync("4450", "PROF", CancellationToken.None)).Should().Be(JobCodeAssignResult.Assigned);
        await connection.ExecuteAsync("EXEC [data].[BuildAutoAssociations] @cycleStart, @cycleEnd", window);

        (await connection.QueryAsync<(string EmployeeId, decimal Expenses)>(staged4450Sql)).Should().BeEquivalentTo(new[]
        {
            ("30000013", 25m),
            ("30000014", -25m),
        });
        var after = (await service.GetAsync(cycle, CancellationToken.None)).Rows.Single(row => row.JobCode == "4450");
        after.Blocking.Should().BeFalse();
        after.FteSfn.Should().Be("241");
    }

    [Fact]
    public async Task Assign_updates_an_existing_title()
    {
        await fixture.ClearDataTablesAsync();
        await JobCodeSeeds.SeedBaseScenarioAsync(fixture);
        await JobCodeSeeds.SeedJobCodeRowsAsync(fixture);
        await ExecuteAsync(
            "INSERT INTO [data].[StaffTypes] ([StaffTypeCode], [FteSfn], [Description]) VALUES ('TECH', '243', 'Technical Support');");
        var service = CreateService();

        // Surrounding whitespace is not part of the code.
        (await service.AssignAsync(" 5678 ", " TECH ", CancellationToken.None)).Should().Be(JobCodeAssignResult.Assigned);

        (await TitlesAsync("5678")).Should().Equal(("5678", "TECH", "Unclassified title"));
        var row = (await service.GetAsync(Cycle(), CancellationToken.None)).Rows.Single(candidate => candidate.JobCode == "5678");
        row.StaffTypeCode.Should().Be("TECH");
        row.FteSfn.Should().Be("243");
        row.Blocking.Should().BeFalse();

        // An assigned code can be moved to another line.
        (await service.AssignAsync("5678", "PROF", CancellationToken.None)).Should().Be(JobCodeAssignResult.Assigned);
        (await TitlesAsync("5678")).Should().Equal(("5678", "PROF", "Unclassified title"));
    }

    [Fact]
    public async Task Assign_inserts_a_title_for_an_unknown_job_code()
    {
        await fixture.ClearDataTablesAsync();
        await JobCodeSeeds.SeedBaseScenarioAsync(fixture);
        await JobCodeSeeds.SeedJobCodeRowsAsync(fixture);

        (await CreateService().AssignAsync("0000", "PROF", CancellationToken.None)).Should().Be(JobCodeAssignResult.Assigned);

        (await TitlesAsync("0000")).Should().Equal(("0000", "PROF", null));
    }

    [Fact]
    public async Task Assign_twice_for_a_missing_title_keeps_one_row_with_the_last_value()
    {
        await fixture.ClearDataTablesAsync();
        await JobCodeSeeds.SeedBaseScenarioAsync(fixture);
        await JobCodeSeeds.SeedJobCodeRowsAsync(fixture);
        await ExecuteAsync(
            """
            INSERT INTO [data].[StaffTypes] ([StaffTypeCode], [FteSfn], [Description])
            VALUES ('TECH', '243', 'Technical Support'), ('CLER', '244', 'Clerical');
            """);

        // Two saves racing to create the same Titles row.
        var results = await Task.WhenAll(
            CreateService().AssignAsync("0000", "PROF", CancellationToken.None),
            CreateService().AssignAsync("0000", "TECH", CancellationToken.None));

        results.Should().OnlyContain(result => result == JobCodeAssignResult.Assigned);
        var raced = await TitlesAsync("0000");
        raced.Should().ContainSingle();
        raced[0].StaffTypeCode.Should().BeOneOf("PROF", "TECH");

        (await CreateService().AssignAsync("0000", "CLER", CancellationToken.None)).Should().Be(JobCodeAssignResult.Assigned);
        (await TitlesAsync("0000")).Should().Equal(("0000", "CLER", null));
    }

    [Theory]
    [InlineData(null, "PROF", JobCodeAssignResult.InvalidJobCode)]
    [InlineData("", "PROF", JobCodeAssignResult.InvalidJobCode)]
    [InlineData("   ", "PROF", JobCodeAssignResult.InvalidJobCode)]
    [InlineData("12345", "PROF", JobCodeAssignResult.InvalidJobCode)]
    [InlineData("0000", null, JobCodeAssignResult.InvalidStaffType)]
    [InlineData("0000", "", JobCodeAssignResult.InvalidStaffType)]
    [InlineData("0000", "NOPE", JobCodeAssignResult.InvalidStaffType)]
    [InlineData("0000", "NOLINE", JobCodeAssignResult.InvalidStaffType)]
    public async Task Assign_rejects_bad_input(string? jobCode, string? staffTypeCode, JobCodeAssignResult expected)
    {
        await fixture.ClearDataTablesAsync();
        await JobCodeSeeds.SeedBaseScenarioAsync(fixture);
        await JobCodeSeeds.SeedJobCodeRowsAsync(fixture);
        var before = await AllTitlesAsync();

        (await CreateService().AssignAsync(jobCode, staffTypeCode, CancellationToken.None)).Should().Be(expected);

        (await AllTitlesAsync()).Should().Equal(before);
    }

    private JobCodeClassificationService CreateService()
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:DataConnection"] = fixture.ConnectionString,
            })
            .Build();
        return new JobCodeClassificationService(fixture.CreateDataDbContext(), configuration);
    }

    private static FiscalYearCycle Cycle()
    {
        FiscalYearCycle.TryParse("FY25", out var cycle).Should().BeTrue();
        return cycle!;
    }

    private async Task ExecuteAsync(string sql)
    {
        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();
        await connection.ExecuteAsync(sql);
    }

    private async Task<List<(string TitleCode, string? StaffTypeCode, string? Name)>> TitlesAsync(string titleCode)
    {
        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();
        return (await connection.QueryAsync<(string, string?, string?)>(
            "SELECT [TitleCode], [StaffTypeCode], [Name] FROM [data].[Titles] WHERE [TitleCode] = @titleCode",
            new { titleCode })).ToList();
    }

    private async Task<List<(string TitleCode, string? StaffTypeCode, string? Name)>> AllTitlesAsync()
    {
        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();
        return (await connection.QueryAsync<(string, string?, string?)>(
            "SELECT [TitleCode], [StaffTypeCode], [Name] FROM [data].[Titles] ORDER BY [TitleCode]")).ToList();
    }
}
