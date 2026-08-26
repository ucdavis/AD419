using FluentAssertions;
using Microsoft.AspNetCore.Mvc;
using Server.Controllers;
using Server.Core.Data;
using Server.Core.Domain;
using Server.ExpenseReview;
using Server.Models;
using Server.Models.ExpenseReview;

namespace Server.Tests.ExpenseReview;

public class ExpenseReviewControllerTests
{
    [Fact]
    public async Task Transactions_conflicts_when_no_confirmed_workflow_cycle_exists()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        var service = new StubExpenseReviewService();
        var controller = new ExpenseReviewController(service, db);

        var result = await controller.Transactions(new ExpenseReviewTransactionsQuery(), CancellationToken.None);

        result.Should().BeOfType<ConflictObjectResult>();
        service.TransactionsCalled.Should().BeFalse();
    }

    [Fact]
    public async Task Filters_conflicts_when_no_confirmed_workflow_cycle_exists()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        var service = new StubExpenseReviewService();
        var controller = new ExpenseReviewController(service, db);

        var result = await controller.Filters(CancellationToken.None);

        result.Should().BeOfType<ConflictObjectResult>();
        service.FiltersCalled.Should().BeFalse();
    }

    [Fact]
    public async Task Transactions_sources_cycle_from_current_workflow_run()
    {
        await using var db = await CreateDbWithConfirmedRunAsync();
        var service = new StubExpenseReviewService();
        var controller = new ExpenseReviewController(service, db);

        var result = await controller.Transactions(
            new ExpenseReviewTransactionsQuery
            {
                IncludeState = "included",
                SortBy = "amount",
                SortDirection = "desc",
                Page = 2,
                PageSize = 25,
                FinancialDept = ["D0123"],
            },
            CancellationToken.None);

        var ok = result.Should().BeOfType<OkObjectResult>().Subject;
        var response = ok.Value.Should().BeOfType<ExpenseReviewTransactionsResponse>().Subject;
        response.Rows.Should().ContainSingle().Which.FteIncluded.Should().BeTrue();
        service.ReceivedTransactionsCycle.Should().Be(new FiscalYearCycle(
            "FY25",
            new DateOnly(2024, 10, 1),
            new DateOnly(2025, 9, 30)));
        service.ReceivedRequest.Should().NotBeNull();
        service.ReceivedRequest!.IncludeState.Should().Be(ExpenseReviewIncludeState.Included);
        service.ReceivedRequest.SortBy.Should().Be("amount");
        service.ReceivedRequest.SortDescending.Should().BeTrue();
        service.ReceivedRequest.Page.Should().Be(2);
        service.ReceivedRequest.PageSize.Should().Be(25);
        service.ReceivedRequest.Filters.FinancialDept.Should().Equal("D0123");
    }

    [Fact]
    public async Task Filters_sources_cycle_from_current_workflow_run()
    {
        await using var db = await CreateDbWithConfirmedRunAsync();
        var service = new StubExpenseReviewService();
        var controller = new ExpenseReviewController(service, db);

        var result = await controller.Filters(CancellationToken.None);

        result.Should().BeOfType<OkObjectResult>();
        service.ReceivedFiltersCycle.Should().Be(new FiscalYearCycle(
            "FY25",
            new DateOnly(2024, 10, 1),
            new DateOnly(2025, 9, 30)));
    }

    [Theory]
    [MemberData(nameof(InvalidQueries))]
    public async Task Transactions_validates_invalid_query_inputs(ExpenseReviewTransactionsQuery query)
    {
        await using var db = await CreateDbWithConfirmedRunAsync();
        var service = new StubExpenseReviewService();
        var controller = new ExpenseReviewController(service, db);

        var result = await controller.Transactions(query, CancellationToken.None);

        result.Should().BeOfType<BadRequestObjectResult>();
        service.TransactionsCalled.Should().BeFalse();
    }

    public static IEnumerable<object[]> InvalidQueries()
    {
        yield return [new ExpenseReviewTransactionsQuery { Page = 0 }];
        yield return [new ExpenseReviewTransactionsQuery { PageSize = 0 }];
        yield return [new ExpenseReviewTransactionsQuery { PageSize = ExpenseReviewRequestParser.MaxPageSize + 1 }];
        yield return [new ExpenseReviewTransactionsQuery { IncludeState = "maybe" }];
        yield return [new ExpenseReviewTransactionsQuery { SortBy = "drop table" }];
        yield return [new ExpenseReviewTransactionsQuery { SortDirection = "sideways" }];
    }

    private static async Task<AppDbContext> CreateDbWithConfirmedRunAsync()
    {
        var db = TestDbContextFactory.CreateInMemory();
        db.WorkflowRuns.Add(new WorkflowRun
        {
            FiscalYear = "FY25",
            CycleStart = new DateOnly(2024, 10, 1),
            CycleEnd = new DateOnly(2025, 9, 30),
            IsCurrent = true,
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow,
        });
        await db.SaveChangesAsync();
        return db;
    }

    private sealed class StubExpenseReviewService : IExpenseReviewService
    {
        public bool TransactionsCalled { get; private set; }
        public bool FiltersCalled { get; private set; }
        public FiscalYearCycle? ReceivedTransactionsCycle { get; private set; }
        public FiscalYearCycle? ReceivedFiltersCycle { get; private set; }
        public ExpenseReviewTransactionsRequest? ReceivedRequest { get; private set; }

        public Task<ExpenseReviewTransactionsResponse> GetTransactionsAsync(
            FiscalYearCycle cycle,
            ExpenseReviewTransactionsRequest request,
            CancellationToken cancellationToken)
        {
            TransactionsCalled = true;
            ReceivedTransactionsCycle = cycle;
            ReceivedRequest = request;

            return Task.FromResult(new ExpenseReviewTransactionsResponse(
                cycle.FiscalYear,
                cycle.CycleStart,
                cycle.CycleEnd,
                new ExpenseReviewCountsDto(0, 0, 0),
                0,
                request.Page,
                request.PageSize,
                0,
                [
                    new ExpenseReviewTransactionDto(
                        "UCP:1",
                        "1",
                        "UCP",
                        new ExpenseReviewCodeNameDto("D0123", "Department"),
                        new ExpenseReviewCodeNameDto("13U02", "Fund"),
                        new ExpenseReviewCodeNameDto("500000", "Account"),
                        new ExpenseReviewCodeNameDto("K1234", "Project"),
                        "Oct-24",
                        "220",
                        "Agricultural Experiment Station",
                        12.34m,
                        0.5m,
                        true,
                        true),
                ]));
        }

        public Task<ExpenseReviewFilterOptionsResponse> GetFilterOptionsAsync(
            FiscalYearCycle cycle,
            CancellationToken cancellationToken)
        {
            FiltersCalled = true;
            ReceivedFiltersCycle = cycle;

            return Task.FromResult(new ExpenseReviewFilterOptionsResponse([], [], [], [], [], [], []));
        }
    }
}
