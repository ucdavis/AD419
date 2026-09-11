using System.Text.Json;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Server.Assistant;
using Server.Core.Data;
using Server.Core.Domain;
using Server.ExpenseReview;
using Server.Models;
using Server.Models.ExpenseReview;
using Server.Tests;
using UCDavis.CaesAi.AppSdk;

namespace Server.Tests.Assistant;

public class ExpenseReviewToolDispatcherTests
{
    private static readonly Guid UserId = Guid.NewGuid();

    [Fact]
    public async Task Rejects_users_that_are_not_authorized()
    {
        await using var db = await DbWithCycleAsync(seedUser: false);
        var dispatcher = Dispatcher(db, new StubService());

        var response = await dispatcher.ExecuteAsync(
            Request(ExpenseReviewToolManifest.FilterOptions, "{}"), UserId.ToString(), CancellationToken.None);

        response.Ok.Should().BeFalse();
        response.Error!.Code.Should().Be("unauthorized");
    }

    [Fact]
    public async Task Rejects_user_references_that_are_not_guids()
    {
        await using var db = await DbWithCycleAsync();
        var dispatcher = Dispatcher(db, new StubService());

        var response = await dispatcher.ExecuteAsync(
            Request(ExpenseReviewToolManifest.FilterOptions, "{}"), "not-a-guid", CancellationToken.None);

        response.Error!.Code.Should().Be("unauthorized");
    }

    [Fact]
    public async Task Fails_when_no_cycle_is_confirmed()
    {
        await using var db = await DbWithCycleAsync(seedCycle: false);
        var dispatcher = Dispatcher(db, new StubService());

        var response = await dispatcher.ExecuteAsync(
            Request(ExpenseReviewToolManifest.FilterOptions, "{}"), UserId.ToString(), CancellationToken.None);

        response.Error!.Code.Should().Be("no_confirmed_cycle");
    }

    [Fact]
    public async Task Unknown_tools_fail_with_a_fixed_code()
    {
        await using var db = await DbWithCycleAsync();
        var dispatcher = Dispatcher(db, new StubService());

        var response = await dispatcher.ExecuteAsync(
            Request("delete_everything", "{}"), UserId.ToString(), CancellationToken.None);

        response.Error!.Code.Should().Be("unknown_tool");
    }

    [Fact]
    public async Task Invalid_query_arguments_return_the_parser_message()
    {
        await using var db = await DbWithCycleAsync();
        var dispatcher = Dispatcher(db, new StubService());

        var response = await dispatcher.ExecuteAsync(
            Request(ExpenseReviewToolManifest.QueryTransactions, """{"sortBy":"nope"}"""),
            UserId.ToString(),
            CancellationToken.None);

        response.Error!.Code.Should().Be("invalid_arguments");
        response.Error.Message.Should().StartWith("sortBy must be one of");
    }

    [Fact]
    public async Task Query_returns_a_columnar_table_and_clamps_page_size()
    {
        await using var db = await DbWithCycleAsync();
        var service = new StubService();
        var dispatcher = Dispatcher(db, service);

        var response = await dispatcher.ExecuteAsync(
            Request(ExpenseReviewToolManifest.QueryTransactions, """{"fund":["12345"],"includeState":"excluded","pageSize":400}"""),
            UserId.ToString(),
            CancellationToken.None);

        response.Ok.Should().BeTrue();
        service.LastRequest!.PageSize.Should().Be(ExpenseReviewToolManifest.MaxPageSize);
        service.LastRequest.IncludeState.Should().Be(ExpenseReviewIncludeState.Excluded);
        service.LastRequest.Filters.Fund.Should().Equal("12345");

        var data = JsonSerializer.SerializeToElement(response.Output!.Data, new JsonSerializerOptions(JsonSerializerDefaults.Web));
        data.GetProperty("columns").GetArrayLength().Should().Be(ExpenseReviewAssistantTable.Columns.Count);
        data.GetProperty("rows")[0][0].GetString().Should().Be("group-1");
        data.GetProperty("rows")[0][6].GetString().Should().Be("3110");
        data.GetProperty("totalAmount").GetDecimal().Should().Be(42.5m);
    }

    [Fact]
    public async Task Query_defaults_page_size_to_25()
    {
        await using var db = await DbWithCycleAsync();
        var service = new StubService();
        var dispatcher = Dispatcher(db, service);

        await dispatcher.ExecuteAsync(
            Request(ExpenseReviewToolManifest.QueryTransactions, "{}"), UserId.ToString(), CancellationToken.None);

        service.LastRequest!.PageSize.Should().Be(ExpenseReviewToolManifest.DefaultPageSize);
        service.LastRequest.Page.Should().Be(1);
    }

    [Fact]
    public async Task Summary_validates_group_by_and_passes_options_through()
    {
        await using var db = await DbWithCycleAsync();
        var service = new StubService();
        var dispatcher = Dispatcher(db, service);

        var bad = await dispatcher.ExecuteAsync(
            Request(ExpenseReviewToolManifest.Summarize, """{"groupBy":"nope"}"""), UserId.ToString(), CancellationToken.None);
        bad.Error!.Code.Should().Be("invalid_arguments");

        var good = await dispatcher.ExecuteAsync(
            Request(ExpenseReviewToolManifest.Summarize, """{"groupBy":"fund","includeState":"excluded","limit":900,"sortBy":"rowCount"}"""),
            UserId.ToString(),
            CancellationToken.None);

        good.Ok.Should().BeTrue();
        service.LastSummaryRequest!.GroupBy.Should().Be("fund");
        service.LastSummaryRequest.IncludeState.Should().Be(ExpenseReviewIncludeState.Excluded);
        service.LastSummaryRequest.Limit.Should().Be(ExpenseReviewToolManifest.MaxSummaryLimit);
        service.LastSummaryRequest.SortByRowCount.Should().BeTrue();
    }

    [Fact]
    public async Task Filter_options_are_returned_as_code_name_pairs_and_hidden()
    {
        await using var db = await DbWithCycleAsync();
        var dispatcher = Dispatcher(db, new StubService());

        var response = await dispatcher.ExecuteAsync(
            Request(ExpenseReviewToolManifest.FilterOptions, "{}"), UserId.ToString(), CancellationToken.None);

        response.Ok.Should().BeTrue();
        response.Output!.Display!.Visibility.Should().Be(CaesAiDisplayVisibility.Hidden);
        var data = JsonSerializer.SerializeToElement(response.Output.Data, new JsonSerializerOptions(JsonSerializerDefaults.Web));
        data.GetProperty("fund")[0].GetProperty("code").GetString().Should().Be("12345");
        data.GetProperty("fund")[0].GetProperty("name").GetString().Should().Be("12345 - Hatch");
        data.GetProperty("fiscalYear").GetString().Should().Be("FY25");
    }

    [Fact]
    public async Task Service_exceptions_become_a_fixed_failure()
    {
        await using var db = await DbWithCycleAsync();
        var dispatcher = Dispatcher(db, new StubService { Throw = true });

        var response = await dispatcher.ExecuteAsync(
            Request(ExpenseReviewToolManifest.FilterOptions, "{}"), UserId.ToString(), CancellationToken.None);

        response.Error!.Code.Should().Be("tool_failed");
        response.Error.Message.Should().NotContain("boom");
    }

    [Fact]
    public async Task Cancellation_propagates_instead_of_becoming_a_tool_failure()
    {
        await using var db = await DbWithCycleAsync();
        var dispatcher = Dispatcher(db, new StubService { ThrowCancelled = true });
        using var cts = new CancellationTokenSource();
        await cts.CancelAsync();

        var act = () => dispatcher.ExecuteAsync(
            Request(ExpenseReviewToolManifest.FilterOptions, "{}"), UserId.ToString(), cts.Token);

        await act.Should().ThrowAsync<OperationCanceledException>();
    }

    private static ExpenseReviewToolDispatcher Dispatcher(AppDbContext db, IExpenseReviewService service) =>
        new(service, new ConfirmedCycleProvider(db), db, NullLogger<ExpenseReviewToolDispatcher>.Instance);

    private static ToolExecutionRequest Request(string toolName, string argumentsJson) =>
        new(
            CaesAiProtocol.CurrentVersion,
            Guid.NewGuid(),
            "call-1",
            toolName,
            new string('a', 64),
            JsonDocument.Parse(argumentsJson).RootElement.Clone(),
            "context-token-placeholder-value");

    private static async Task<AppDbContext> DbWithCycleAsync(bool seedUser = true, bool seedCycle = true)
    {
        var db = TestDbContextFactory.CreateInMemory();
        if (seedUser)
        {
            db.Users.Add(new User { EntraId = UserId, Name = "Shannon", Email = "shannon@example.edu" });
        }

        if (seedCycle)
        {
            db.WorkflowRuns.Add(new WorkflowRun
            {
                FiscalYear = "FY25",
                CycleStart = new DateOnly(2024, 10, 1),
                CycleEnd = new DateOnly(2025, 9, 30),
                IsCurrent = true,
                CreatedAt = DateTimeOffset.UtcNow,
                UpdatedAt = DateTimeOffset.UtcNow,
            });
        }

        await db.SaveChangesAsync();
        return db;
    }

    private sealed class StubService : IExpenseReviewService
    {
        public bool Throw { get; init; }
        public bool ThrowCancelled { get; init; }
        public ExpenseReviewTransactionsRequest? LastRequest { get; private set; }
        public ExpenseReviewSummaryRequest? LastSummaryRequest { get; private set; }

        public Task<ExpenseReviewTransactionsResponse> GetTransactionsAsync(
            FiscalYearCycle cycle, ExpenseReviewTransactionsRequest request, CancellationToken cancellationToken)
        {
            LastRequest = request;
            return Task.FromResult(new ExpenseReviewTransactionsResponse(
                cycle.FiscalYear, cycle.CycleStart, cycle.CycleEnd,
                new ExpenseReviewCountsDto(1, 0, 1), 1, 42.5m, request.Page, request.PageSize, 1,
                [
                    new ExpenseReviewTransactionDto(
                        "group-1", "AE",
                        new ExpenseReviewCodeNameDto("3110", "UC Davis"),
                        new ExpenseReviewCodeNameDto("ADNO003", "Plant Sciences"),
                        new ExpenseReviewCodeNameDto("12345", "Hatch"),
                        new ExpenseReviewCodeNameDto("770000", "Supplies"),
                        new ExpenseReviewCodeNameDto("K30", "Project"),
                        null,
                        new ExpenseReviewCodeNameDto("44", "Research"),
                        new ExpenseReviewCodeNameDto("000", "Default"),
                        new ExpenseReviewCodeNameDto("000000", "Default"),
                        "C", "Hatch", 42.5m, false, []),
                ]));
        }

        public Task<ExpenseReviewFilterOptionsResponse> GetFilterOptionsAsync(
            FiscalYearCycle cycle, CancellationToken cancellationToken)
        {
            if (Throw)
            {
                throw new InvalidOperationException("boom");
            }

            if (ThrowCancelled)
            {
                throw new OperationCanceledException(cancellationToken);
            }

            IReadOnlyList<ExpenseReviewFilterOptionDto> fund = [new("12345", "12345 - Hatch")];
            IReadOnlyList<ExpenseReviewFilterOptionDto> none = [];
            return Task.FromResult(new ExpenseReviewFilterOptionsResponse(
                none, none, fund, none, none, none, none, none, none, none, none, none));
        }

        public Task<UnmatchedJobCodesResponse> GetUnmatchedJobCodesAsync(
            FiscalYearCycle cycle, CancellationToken cancellationToken) =>
            Task.FromResult(new UnmatchedJobCodesResponse(cycle.FiscalYear, cycle.CycleStart, cycle.CycleEnd, []));

        public Task<ExpenseReviewSummaryResponse> GetSummaryAsync(
            FiscalYearCycle cycle, ExpenseReviewSummaryRequest request, CancellationToken cancellationToken)
        {
            LastSummaryRequest = request;
            return Task.FromResult(new ExpenseReviewSummaryResponse(cycle.FiscalYear, request.GroupBy, 0, 0m, 0, []));
        }

        public Task WriteTransactionsCsvAsync(
            FiscalYearCycle cycle, ExpenseReviewTransactionsRequest request, Stream output, CancellationToken cancellationToken) =>
            Task.CompletedTask;
    }
}
