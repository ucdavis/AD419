using System.Globalization;
using System.Security.Claims;
using Dapper;
using FluentAssertions;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Server.AutoAssociations;
using Server.Controllers;
using Server.Core.Domain;
using Server.ExpenseReview;
using Server.Models;
using Server.Models.ExpenseReview;
using Server.Models.SegmentClassifications;
using Server.Tests.Helpers;
using Server.Tests.OrgRReview;
using Server.Tests.SqlIntegration;
using Server.Workflow;

namespace Server.Tests.ExpenseReview;

[Trait("Category", "SqlIntegration")]
[Collection(SqlIntegrationCollection.Name)]
public sealed class ExpenseReviewEmployeeTransactionsSqlIntegrationTests(SqlServerDataDbFixture fixture)
{
    private const string MainId = "SCT100_1_0_E1_0_REG_RUN";
    private const string ZeroAmountId = "SCT100_9_0_E1_0_REG_RUN";
    private const string OtherDepartmentId = "PJ200_2_0_E1_0_REG_RUN";
    private const string NegativeId = "SCT300_3_0_E1_0_REG_RUN";
    private const string BonusId = "PJ500_5_0_E1_0_BON_RUN";
    private const string FringeId = "PJ600_6_0_E1_0_XXX_RUN";
    private const string ZeroGroupId = "SCT700_7_0_E1_0_REG_RUN";
    private const string ZeroGroupOffsetId = "SCT701_8_0_E1_0_REG_RUN";
    private const string ExcludedId = "PJ800_9_0_E1_0_REG_RUN";
    private const string UnclassifiedEarnId = "PJ900_10_0_E1_0_UNC_RUN";

    [Fact]
    public async Task Employee_report_rows_reconcile_to_staged_fte_and_all_scope_preserves_contributions()
    {
        await SeedAsync();
        var service = CreateService();
        var report = (await service.GetEmployeeTransactionsAsync(Cycle(), Request(), CancellationToken.None)).Response!;
        var all = (await service.GetEmployeeTransactionsAsync(Cycle(), Request("all"), CancellationToken.None)).Response!;
        var reportList = await new AutoAssociationReportService(fixture.CreateDataDbContext(), Configuration())
            .GetFteOverOneAsync(CancellationToken.None);

        report.FiscalYear.Should().Be("FY25");
        report.EmployeeId.Should().Be("E1");
        report.EmployeeName.Should().BeNull();
        report.ReportFte.Should().Be(1.25m).And.Be(reportList.Single(row => row.EmployeeId == "E1").Fte);
        report.TransactionCount.Should().Be(7);
        report.TotalAmount.Should().Be(168m);
        report.MatchingCount.Should().Be(7);
        report.MatchingAmount.Should().Be(168m);
        report.Rows.Should().HaveCount(7).And.OnlyContain(row => row.EmployeeId == "E1" && row.ReportIncluded == true);
        report.Rows.Select(row => row.Id).Should().BeEquivalentTo(
            new[] { MainId, ZeroAmountId, OtherDepartmentId, NegativeId, BonusId, FringeId, UnclassifiedEarnId });
        report.Rows.Sum(row => row.ReportFteContribution).Should().Be(report.ReportFte);
        report.Rows.Select(row => row.FinancialDepartment).Distinct().Should().BeEquivalentTo(new[] { "D1", "D2" });
        report.Rows.Should().OnlyContain(row => row.JobCode == null && row.FteSfn == null);
        report.Rows.Single(row => row.Id == NegativeId).ReportFteContribution.Should().Be(-0.1m);
        report.Rows.Single(row => row.Id == ZeroAmountId).ReportFteContribution.Should().Be(0.05m);
        foreach (var id in new[] { BonusId, FringeId, UnclassifiedEarnId })
        {
            var row = report.Rows.Single(row => row.Id == id);
            row.ReportFteContribution.Should().Be(0m);
            row.ExclusionReasons.Should().BeEmpty();
        }
        report.Rows.Single(row => row.Id == BonusId).CalculatedFte.Should().Be(0.7m);
        report.Rows.Single(row => row.Id == BonusId).ReportStatus.Should().ContainEquivalentOf("earnings");
        report.Rows.Single(row => row.Id == FringeId).SalaryFringe.Should().Be("Fringe");

        all.ReportFte.Should().Be(report.ReportFte);
        all.TransactionCount.Should().Be(10);
        all.TotalAmount.Should().Be(193m);
        all.Rows.Select(row => row.Id).Should().Contain(report.Rows.Select(row => row.Id));
        all.Rows.Sum(row => row.ReportFteContribution).Should().Be(report.ReportFte);
        all.Rows.Select(row => row.Id).Should().OnlyHaveUniqueItems();
        foreach (var id in new[] { ZeroGroupId, ZeroGroupOffsetId, ExcludedId })
        {
            var row = all.Rows.Single(row => row.Id == id);
            row.ReportIncluded.Should().BeFalse();
            row.ReportFteContribution.Should().Be(0m);
            row.ReportStatus.Should().NotBeNullOrWhiteSpace();
        }
        all.Rows.Single(row => row.Id == ZeroGroupId).ExclusionReasons.Should().BeEmpty();
        all.Rows.Single(row => row.Id == ExcludedId).ExclusionReasons.Select(reason => reason.Code)
            .Should().Contain("account:excluded");
        var latePay = all.Rows.Single(row => row.Id == MainId);
        latePay.TransactionDate.Should().Be(new DateTime(2024, 10, 1));
        latePay.UcEarnEndDate.Should().Be(new DateTime(2024, 9, 15));
        latePay.TransactionId.Should().Be("SCT100");
        latePay.Id.Should().Be(MainId);
        all.Rows.Single(row => row.Id == OtherDepartmentId).UcEarnEndDate.Should().BeNull();
    }

    [Theory]
    [InlineData("report", "transactionId", false)]
    [InlineData("all", "ucEarnEndDate", true)]
    [InlineData("all", "reportFteContribution", false)]
    [InlineData("all", "financialDepartment", true)]
    public async Task Employee_pagination_and_csv_share_sort_order_and_do_not_change_full_totals(
        string scope, string sort, bool descending)
    {
        await SeedAsync();
        var service = CreateService();
        var request = Request(scope) with { SortBy = sort, SortDescending = descending };
        var full = (await service.GetEmployeeTransactionsAsync(Cycle(), request, CancellationToken.None)).Response!;
        var paged = new List<string>();
        for (var page = 1; page <= (int)Math.Ceiling(full.MatchingCount / 2d); page++)
        {
            var result = (await service.GetEmployeeTransactionsAsync(Cycle(), request with { Page = page, PageSize = 2 }, CancellationToken.None)).Response!;
            result.ReportFte.Should().Be(full.ReportFte);
            result.TransactionCount.Should().Be(full.TransactionCount);
            result.TotalAmount.Should().Be(full.TotalAmount);
            result.MatchingCount.Should().Be(full.MatchingCount);
            result.PageCount.Should().Be((int)Math.Ceiling(full.MatchingCount / 2d));
            paged.AddRange(result.Rows.Select(row => row.Id));
        }
        paged.Should().Equal(full.Rows.Select(row => row.Id)).And.OnlyHaveUniqueItems();
        var again = (await service.GetEmployeeTransactionsAsync(Cycle(), request, CancellationToken.None)).Response!;
        again.Rows.Select(row => row.Id).Should().Equal(paged);

        await using var output = new MemoryStream();
        await service.WriteEmployeeTransactionsCsvAsync(Cycle(), request with { Page = 2, PageSize = 1 }, full,
            output, CancellationToken.None);
        output.Position = 0;
        using var csv = new CsvHelper.CsvReader(new StreamReader(output), CultureInfo.InvariantCulture);
        await csv.ReadAsync();
        csv.ReadHeader();
        csv.HeaderRecord.Should().Contain(new[] { "Employee ID", "Transaction ID", "Pay End Date", "UC Earn End Date", "Report FTE contribution" });
        var ids = new List<string>();
        decimal contribution = 0;
        while (await csv.ReadAsync())
        {
            ids.Add(csv.GetField("Labor transaction ID")!);
            contribution += csv.GetField<decimal>("Report FTE contribution");
        }
        ids.Should().Equal(paged);
        contribution.Should().Be(full.ReportFte);
    }

    [Theory]
    [InlineData("SCT100", 2)]
    [InlineData("2024-09-15", 1)]
    [InlineData("2025-09-30", 1)]
    [InlineData("E1", 7)]
    [InlineData("no match %_[]", 0)]
    public async Task Employee_search_covers_new_fields_preserves_header_and_exports_only_matches(string search, int matches)
    {
        await SeedAsync();
        var service = CreateService();
        var request = Request() with { Search = search, PageSize = 1 };
        var response = (await service.GetEmployeeTransactionsAsync(Cycle(), request, CancellationToken.None)).Response!;
        response.ReportFte.Should().Be(1.25m);
        response.TransactionCount.Should().Be(7);
        response.TotalAmount.Should().Be(168m);
        response.MatchingCount.Should().Be(matches);
        response.Rows.Should().HaveCount(Math.Min(1, matches));
        await using var output = new MemoryStream();
        await service.WriteEmployeeTransactionsCsvAsync(Cycle(), request, response, output, CancellationToken.None);
        output.Position = 0;
        using var csv = new CsvHelper.CsvReader(new StreamReader(output), CultureInfo.InvariantCulture);
        await csv.ReadAsync();
        csv.ReadHeader();
        var count = 0;
        while (await csv.ReadAsync()) count++;
        count.Should().Be(matches);
    }

    [Fact]
    public async Task Employee_details_require_current_build_and_summary_membership()
    {
        await fixture.ClearDataTablesAsync();
        var service = CreateService();
        var missing = await service.GetEmployeeTransactionsAsync(Cycle(), Request(), CancellationToken.None);
        missing.BuildAvailable.Should().BeFalse();
        missing.Response.Should().BeNull();
        await SeedAsync();
        var unknown = await service.GetEmployeeTransactionsAsync(Cycle(), Request() with { EmployeeId = "unknown" }, CancellationToken.None);
        unknown.BuildAvailable.Should().BeTrue();
        unknown.Response.Should().BeNull();
        var differentCycle = new FiscalYearCycle("FY26", new(2025, 10, 1), new(2026, 9, 30));
        var stale = await service.GetEmployeeTransactionsAsync(differentCycle, Request("all"), CancellationToken.None);
        stale.BuildAvailable.Should().BeFalse();
        stale.Response.Should().BeNull();
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Earnings_edit_invalidates_employee_endpoints_until_workflow_rebuild(bool include)
    {
        await SeedAsync();
        await using var dataDb = fixture.CreateDataDbContext();
        await using var appDb = TestDbContextFactory.CreateInMemory();
        var user = new ClaimsPrincipal(new ClaimsIdentity([new Claim("name", "Reviewer")], "Test"));
        var now = DateTimeOffset.UtcNow;
        appDb.WorkflowRuns.Add(new WorkflowRun
        {
            FiscalYear = Cycle().FiscalYear,
            CycleStart = Cycle().CycleStart,
            CycleEnd = Cycle().CycleEnd,
            IsCurrent = true,
            CreatedAt = now,
            UpdatedAt = now,
            StageStates = WorkflowStages.All.Where(stage => stage.IsRequired).Select(stage => new WorkflowStageState
            {
                StageId = stage.Id,
                Status = WorkflowStageStatus.Complete,
                StartedAt = now,
                CompletedAt = now,
            }).ToList(),
        });
        await appDb.SaveChangesAsync();
        var builder = new AutoAssociationBuilder(dataDb, NullLogger<AutoAssociationBuilder>.Instance);
        var workflow = new WorkflowService(appDb, dataDb, new FakeOrgRReviewSeeder(), builder);
        var service = new ExpenseReviewService(dataDb, Configuration());
        var details = new ExpenseReviewController(service, new ConfirmedCycleProvider(appDb))
        {
            ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext { User = user } },
        };
        var query = new ExpenseReviewEmployeeTransactionsQuery { PageSize = 100 };
        var before = (await details.EmployeeTransactions("E1", query, CancellationToken.None))
            .Should().BeOfType<OkObjectResult>().Subject;
        before.Value.Should().BeOfType<ExpenseReviewEmployeeTransactionsResponse>()
            .Which.ReportFte.Should().Be(1.25m);
        var classifications = new SegmentClassificationsController(dataDb,
            new RecordingExpenseReviewFilterCacheInvalidator(), workflow)
        {
            ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext { User = user } },
        };

        (await classifications.UpdateClassification(
            new UpdateClassificationRequest("Ern", include ? "BON" : "REG", include, null), CancellationToken.None))
            .Should().BeOfType<NoContentResult>();

        var reopened = await workflow.GetSnapshotAsync(user, CancellationToken.None);
        reopened.CurrentStageId.Should().Be(WorkflowStageIds.DataClassification);
        var classificationStage = reopened.Stages.Single(stage => stage.Id == WorkflowStageIds.DataClassification);
        reopened.Stages.Where(stage => stage.Number > classificationStage.Number && stage.IsRequired)
            .Should().OnlyContain(stage => stage.Status == WorkflowStageStatus.NotStarted && !stage.CanAccess);
        (await builder.BuildExistsAsync(CancellationToken.None)).Should().BeFalse();
        (await details.EmployeeTransactions("E1", query, CancellationToken.None))
            .Should().BeOfType<ConflictObjectResult>().Which.StatusCode.Should().Be(409);
        await using var output = new MemoryStream();
        details.Response.Body = output;
        (await details.EmployeeTransactionsCsv("E1", query, CancellationToken.None))
            .Should().BeOfType<ConflictObjectResult>().Which.StatusCode.Should().Be(409);
        output.Length.Should().Be(0);

        foreach (var stageId in new[] { WorkflowStageIds.DataClassification, WorkflowStageIds.ExpenseReview, WorkflowStageIds.OrgRReview })
        {
            (await workflow.SetStageStatusAsync(stageId, WorkflowStageStatus.Complete, user, CancellationToken.None))
                .Should().NotBeNull();
        }

        var rebuilt = (await details.EmployeeTransactions("E1", query, CancellationToken.None))
            .Should().BeOfType<OkObjectResult>().Subject.Value
            .Should().BeOfType<ExpenseReviewEmployeeTransactionsResponse>().Subject;
        rebuilt.ReportFte.Should().Be(include ? 1.95m : 0m);
        rebuilt.Rows.Should().NotBeEmpty();
        rebuilt.Rows.Sum(row => row.ReportFteContribution).Should().Be(rebuilt.ReportFte);
        (await details.EmployeeTransactionsCsv("E1", query, CancellationToken.None)).Should().BeOfType<EmptyResult>();
        output.Position = 0;
        using var csv = new CsvHelper.CsvReader(new StreamReader(output), CultureInfo.InvariantCulture);
        await csv.ReadAsync();
        csv.ReadHeader();
        decimal contribution = 0;
        var rowCount = 0;
        while (await csv.ReadAsync())
        {
            csv.GetField<decimal>("Report FTE").Should().Be(rebuilt.ReportFte);
            contribution += csv.GetField<decimal>("Report FTE contribution");
            rowCount++;
        }
        rowCount.Should().Be(rebuilt.Rows.Count);
        contribution.Should().Be(rebuilt.ReportFte);
    }

    [Fact]
    public async Task Group_details_expose_new_ucpath_fields_in_search_sort_and_csv()
    {
        await SeedAsync();
        var service = CreateService();
        ExpenseReviewRequestParser.TryParse(new ExpenseReviewTransactionsQuery
        {
            Source = ["UCP"], FinancialDept = ["D2"], IncludeState = "all",
        }, out var context, out _).Should().BeTrue();
        var group = (await service.GetTransactionsAsync(Cycle(), context, CancellationToken.None)).Rows.Single();
        var request = new ExpenseReviewGroupTransactionsRequest(group.Id, context, "transactionId", false, null);
        var original = (await service.GetGroupTransactionsAsync(Cycle(), request, CancellationToken.None))!;
        original.Rows.Should().ContainSingle().Which.UcEarnEndDate.Should().BeNull();
        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();
        await connection.ExecuteAsync("UPDATE [data].[UcPathTransactions] SET [UcEarnEndDate] = '2023-12-31' WHERE [LaborTransactionId] = @id", new { id = OtherDepartmentId });
        foreach (var search in new[] { "E1", "PJ200", "2023-12-31", "2025-09-30" })
        {
            var response = (await service.GetGroupTransactionsAsync(Cycle(), request with { Search = search, SortBy = "ucEarnEndDate" }, CancellationToken.None))!;
            var row = response.Rows.Should().ContainSingle().Subject;
            row.EmployeeId.Should().Be("E1");
            row.TransactionId.Should().Be("PJ200");
            row.Id.Should().Be(OtherDepartmentId);
            row.TransactionDate.Should().Be(new DateTime(2025, 9, 30));
            row.UcEarnEndDate.Should().Be(new DateTime(2023, 12, 31));
        }
        await using var output = new MemoryStream();
        await service.WriteGroupTransactionsCsvAsync(Cycle(), request with { Search = "2023-12-31" }, group, output, CancellationToken.None);
        output.Position = 0;
        using var csv = new CsvHelper.CsvReader(new StreamReader(output), CultureInfo.InvariantCulture);
        await csv.ReadAsync();
        csv.ReadHeader();
        (await csv.ReadAsync()).Should().BeTrue();
        csv.GetField("Employee ID").Should().Be("E1");
        csv.GetField("Transaction ID").Should().Be("PJ200");
        csv.GetField("Labor transaction ID").Should().Be(OtherDepartmentId);
        csv.GetField("Pay End Date").Should().Be("2025-09-30");
        csv.GetField("UC Earn End Date").Should().Be("2023-12-31");
        (await csv.ReadAsync()).Should().BeFalse();
    }

    [Theory]
    [InlineData("missing-build", false)]
    [InlineData("changed-cycle", false)]
    [InlineData("missing-employee", true)]
    public async Task Employee_export_revalidates_report_before_writing_any_csv(string change, bool buildAvailable)
    {
        await SeedAsync();
        var service = CreateService();
        var request = Request();
        var preflight = await service.GetEmployeeTransactionsAsync(Cycle(), request, CancellationToken.None);
        preflight.BuildAvailable.Should().BeTrue();
        preflight.Response.Should().NotBeNull();
        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();
        var sql = change switch
        {
            "missing-build" => "DELETE FROM [data].[AutoAssociationBuilds]",
            "changed-cycle" => "UPDATE [data].[AutoAssociationBuilds] SET [CycleStart] = '2025-10-01', [CycleEnd] = '2026-09-30'",
            _ => "DELETE FROM [data].[ExpenseSummary] WHERE [EmployeeId] = 'E1'",
        };
        await connection.ExecuteAsync(sql);
        await using var output = new MemoryStream();

        var export = () => service.WriteEmployeeTransactionsCsvAsync(Cycle(), request, preflight.Response!, output, CancellationToken.None);

        var exception = await export.Should().ThrowAsync<ExpenseReviewEmployeeTransactionsUnavailableException>();
        exception.Which.BuildAvailable.Should().Be(buildAvailable);
        output.Length.Should().Be(0);
    }

    private static FiscalYearCycle Cycle() => new("FY25", new(2024, 10, 1), new(2025, 9, 30));
    private static ExpenseReviewEmployeeTransactionsRequest Request(string scope = "report") => new("E1", scope, 1, 100, "id", false, null);
    private IConfiguration Configuration() => new ConfigurationBuilder().AddInMemoryCollection(
        new Dictionary<string, string?> { ["ConnectionStrings:DataConnection"] = fixture.ConnectionString }).Build();
    private ExpenseReviewService CreateService() => new(fixture.CreateDataDbContext(), Configuration());

    private async Task SeedAsync()
    {
        await fixture.ClearDataTablesAsync();
        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();
        await connection.ExecuteAsync("""
            INSERT INTO [data].[Sfns] ([Sfn], [Label]) VALUES ('201', 'Hatch');
            INSERT INTO [data].[SegmentClassifications] ([SegmentType], [Code], [IncludeInReport], [Sfn]) VALUES
                ('FinancialDepartment', 'D1', 1, NULL), ('FinancialDepartment', 'D2', 1, NULL),
                ('Fund', 'F1', 1, '201'), ('Account', 'A1', 1, NULL), ('Account', 'A2', 0, NULL),
                ('Activity', 'AC1', 1, NULL), ('Purpose', 'P1', 1, NULL),
                ('Ern', 'REG', 1, NULL), ('Ern', 'BON', 0, NULL);
            INSERT INTO [data].[OrgRs] ([Code]) VALUES ('AAAA'), ('BBBB');
            INSERT INTO [data].[OrgRFinancialDepartments] ([FinancialDepartment], [OrgR]) VALUES ('D1', 'AAAA'), ('D2', 'BBBB');
            INSERT INTO [data].[Projects] ([AccessionNumber], [NifaProjectNumber], [Is204], [Sfn])
            VALUES ('1000001', 'CA-D-ABC-1001-H', 0, '201');
            INSERT INTO [data].[UcPathTransactions]
                ([LaborTransactionId], [Entity], [Fund], [FinancialDepartment], [ParentDepartment], [Account],
                 [Purpose], [Program], [Project], [Activity], [ErnCode], [EmployeeId], [PositionNumber],
                 [Hours], [Amount], [CalculatedFte], [PayPeriodEndDate], [UcEarnEndDate], [FringeBenefitSalaryCd],
                 [FiscalYear], [Period], [EmpRcd], [ExcludedByDate], [AccountNotInAE])
            VALUES
                ('SCT100_1_0_E1_0_REG_RUN', '3310', 'F1', 'D1', 'D1', 'A1', 'P1', NULL, 'PR1', 'AC1', 'REG', 'E1', 'POS1', 100, 100, 0.8, '2024-10-01', '2024-09-15', 'S', 2025, '4', 0, 0, 0),
                ('PJ200_2_0_E1_0_REG_RUN',  '3310', 'F1', 'D2', 'D2', 'A1', 'P1', NULL, 'PR2', 'AC1', 'REG', 'E1', 'POS1', 60, 60, 0.5, '2025-09-30', NULL, 'S', 2026, '3', 0, 0, 0),
                ('SCT300_3_0_E1_0_REG_RUN', '3310', 'F1', 'D1', 'D1', 'A1', 'P1', NULL, 'PR1', 'AC1', 'REG', 'E1', 'POS1', -10, -10, -0.1, '2024-11-15', '2024-10-31', 'S', 2025, '5', 0, 0, 0),
                ('SCT100_9_0_E1_0_REG_RUN', '3310', 'F1', 'D1', 'D1', 'A1', 'P1', NULL, 'PR1', 'AC1', 'REG', 'E1', 'POS1', 1, 0, 0.05, '2024-11-15', NULL, 'S', 2025, '5', 0, 0, 0),
                ('PJ500_5_0_E1_0_BON_RUN',  '3310', 'F1', 'D1', 'D1', 'A1', 'P1', NULL, 'PR1', 'AC1', 'BON', 'E1', 'POS1', 10, 10, 0.7, '2024-11-15', '2024-11-01', 'S', 2025, '5', 0, 0, 0),
                ('PJ600_6_0_E1_0_XXX_RUN',  '3310', 'F1', 'D1', 'D1', 'A1', 'P1', NULL, 'PR1', 'AC1', 'XXX', 'E1', 'POS1', 0, 5, 0, '2024-11-15', '2024-11-01', 'F', 2025, '5', 0, 0, 0),
                ('SCT700_7_0_E1_0_REG_RUN', '3310', 'F1', 'D1', 'D1', 'A1', 'P1', NULL, 'ZERO', 'AC1', 'REG', 'E1', 'POS1', 20, 20, 0.3, '2024-11-15', NULL, 'S', 2025, '5', 0, 0, 0),
                ('SCT701_8_0_E1_0_REG_RUN', '3310', 'F1', 'D1', 'D1', 'A1', 'P1', NULL, 'ZERO', 'AC1', 'REG', 'E1', 'POS1', 0, -20, 0, '2024-11-15', NULL, 'S', 2025, '5', 0, 0, 0),
                ('PJ800_9_0_E1_0_REG_RUN',  '3310', 'F1', 'D1', 'D1', 'A2', 'P1', NULL, 'PR1', 'AC1', 'REG', 'E1', 'POS1', 25, 25, 2, '2024-11-15', NULL, 'S', 2025, '5', 0, 0, 0),
                ('PJ900_10_0_E1_0_UNC_RUN', '3310', 'F1', 'D1', 'D1', 'A1', 'P1', NULL, 'PR1', 'AC1', 'UNC', 'E1', 'POS1', 3, 3, 0.8, '2024-11-15', NULL, 'S', 2025, '5', 0, 0, 0),
                ('PJBEFORE_1_0_E1_0_REG_RUN', '3310', 'F1', 'D1', 'D1', 'A1', 'P1', NULL, 'PR1', 'AC1', 'REG', 'E1', 'POS1', 400, 400, 4, '2024-09-30', '2024-10-01', 'S', 2025, '3', 0, 0, 0),
                ('PJAFTER_1_0_E1_0_REG_RUN', '3310', 'F1', 'D1', 'D1', 'A1', 'P1', NULL, 'PR1', 'AC1', 'REG', 'E1', 'POS1', 400, 400, 4, '2025-10-01', '2025-09-30', 'S', 2026, '4', 0, 0, 0),
                ('PJOTHER_1_0_E2_0_REG_RUN', '3310', 'F1', 'D1', 'D1', 'A1', 'P1', NULL, 'PR1', 'AC1', 'REG', 'E2', 'POS2', 100, 100, 1.2, '2024-11-15', NULL, 'S', 2025, '5', 0, 0, 0);
            EXEC [data].[BuildAutoAssociations] @cycleStart, @cycleEnd;
            """, new { cycleStart = Cycle().CycleStart.ToDateTime(TimeOnly.MinValue), cycleEnd = Cycle().CycleEnd.ToDateTime(TimeOnly.MinValue) });
    }
}
