using FluentAssertions;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Server.Controllers;
using Server.ExpenseReview;
using Server.Models;
using Server.Models.ExpenseReview;

namespace Server.Tests.ExpenseReview;

public partial class ExpenseReviewControllerTests
{
    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Employee_endpoints_validate_input_cycle_build_and_employee(bool csv)
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        var service = new StubExpenseReviewService();
        var controller = new ExpenseReviewController(service, new ConfirmedCycleProvider(db));
        async Task<IActionResult> Call(string employeeId, ExpenseReviewEmployeeTransactionsQuery query) => csv
            ? await controller.EmployeeTransactionsCsv(employeeId, query, CancellationToken.None)
            : await controller.EmployeeTransactions(employeeId, query, CancellationToken.None);

        (await Call("E1", new() { Scope = "invalid" })).Should().BeOfType<BadRequestObjectResult>();
        service.EmployeeRequest.Should().BeNull();
        (await Call("E1", new())).Should().BeOfType<ConflictObjectResult>();
        service.EmployeeRequest.Should().BeNull();

        await using var confirmedDb = await CreateDbWithConfirmedRunAsync();
        controller = new ExpenseReviewController(service, new ConfirmedCycleProvider(confirmedDb));
        service.EmployeeResult = new(false, null);
        (await Call("E1", new())).Should().BeOfType<ConflictObjectResult>();
        service.EmployeeResult = new(true, null);
        (await Call("E1", new())).Should().BeOfType<NotFoundObjectResult>();
        service.EmployeeCsvRequest.Should().BeNull();
    }

    [Fact]
    public async Task Employee_endpoints_pass_scope_search_sort_and_confirmed_cycle_to_service()
    {
        await using var db = await CreateDbWithConfirmedRunAsync();
        var cycle = new FiscalYearCycle("FY25", new(2024, 10, 1), new(2025, 9, 30));
        var response = new ExpenseReviewEmployeeTransactionsResponse(cycle.FiscalYear, cycle.CycleStart, cycle.CycleEnd,
            "E1", "Employee One", 1.25m, "all", 60, 160m, 0, 0m, 2, 10, 0, []);
        var service = new StubExpenseReviewService { EmployeeResult = new(true, response) };
        var controller = new ExpenseReviewController(service, new ConfirmedCycleProvider(db))
        {
            ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext() },
        };
        var query = new ExpenseReviewEmployeeTransactionsQuery
        {
            Scope = "all", Page = 2, PageSize = 10, Search = "  SCT%_[]  ",
            DetailSortBy = "ucEarnEndDate", DetailSortDirection = "desc",
        };

        var result = (await controller.EmployeeTransactions("E1", query, CancellationToken.None))
            .Should().BeOfType<OkObjectResult>().Subject;

        result.Value.Should().BeSameAs(response);
        service.EmployeeCycle.Should().Be(cycle);
        service.EmployeeRequest.Should().Be(new ExpenseReviewEmployeeTransactionsRequest(
            "E1", "all", 2, 10, "ucEarnEndDate", true, "SCT%_[]"));
        await using var output = new MemoryStream();
        controller.Response.Body = output;
        (await controller.EmployeeTransactionsCsv("E1", query, CancellationToken.None)).Should().BeOfType<EmptyResult>();
        service.EmployeeCsvRequest.Should().Be(new ExpenseReviewEmployeeTransactionsRequest(
            "E1", "all", 2, 10, "ucEarnEndDate", true, "SCT%_[]"));
        controller.Response.ContentType.Should().Be("text/csv; charset=utf-8");
        controller.Response.Headers.ContentDisposition.ToString().Should().Contain(".csv");
        System.Text.Encoding.UTF8.GetString(output.ToArray()).Should().Be("employee-csv");
    }

    [Theory]
    [InlineData(false, StatusCodes.Status409Conflict)]
    [InlineData(true, StatusCodes.Status404NotFound)]
    public async Task Employee_csv_returns_report_guard_error_if_state_disappears_after_preflight(bool buildAvailable, int statusCode)
    {
        await using var db = await CreateDbWithConfirmedRunAsync();
        var response = new ExpenseReviewEmployeeTransactionsResponse("FY25", new(2024, 10, 1), new(2025, 9, 30),
            "E1", "Employee One", 1.25m, "report", 1, 100m, 1, 100m, 1, 25, 1, []);
        var service = new StubExpenseReviewService
        {
            EmployeeResult = new(true, response),
            EmployeeExportFailure = new ExpenseReviewEmployeeTransactionsUnavailableException(buildAvailable),
        };
        var controller = new ExpenseReviewController(service, new ConfirmedCycleProvider(db))
        {
            ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext() },
        };
        await using var output = new MemoryStream();
        controller.Response.Body = output;

        var result = await controller.EmployeeTransactionsCsv("E1", new(), CancellationToken.None);

        result.Should().BeAssignableTo<ObjectResult>().Which.StatusCode.Should().Be(statusCode);
        service.EmployeeRequest.Should().NotBeNull();
        service.EmployeeCsvRequest.Should().NotBeNull();
        controller.Response.ContentType.Should().BeNull();
        controller.Response.Headers.Should().NotContainKey("Content-Disposition");
        output.Length.Should().Be(0);
    }

    [Theory]
    [InlineData("", 1, 25, null, null, null)]
    [InlineData("12345678901", 1, 25, null, null, null)]
    [InlineData("E1", 0, 25, null, null, null)]
    [InlineData("E1", 1, 0, null, null, null)]
    [InlineData("E1", 1, 501, null, null, null)]
    [InlineData("E1", int.MaxValue, 100, null, null, null)]
    [InlineData("E1", 1, 25, "exclusionReasons", null, null)]
    [InlineData("E1", 1, 25, "amount", "sideways", null)]
    [InlineData("E1", 1, 25, "amount", "asc", "included")]
    public void Employee_parser_rejects_invalid_input(string employeeId, int page, int size,
        string? sort, string? direction, string? scope)
    {
        ExpenseReviewEmployeeTransactionsParser.TryParse(employeeId, new()
        {
            Page = page, PageSize = size, DetailSortBy = sort, DetailSortDirection = direction, Scope = scope,
        }, out _, out var error).Should().BeFalse();
        error.Should().NotBeNullOrWhiteSpace();
    }

    [Fact]
    public void Employee_parser_defaults_to_report_and_accepts_new_diagnostic_columns()
    {
        ExpenseReviewEmployeeTransactionsParser.TryParse("E1", new(), out var defaults, out _).Should().BeTrue();
        defaults.Should().Be(new ExpenseReviewEmployeeTransactionsRequest("E1", "report", 1, 25,
            "transactionDate", false, null));
        foreach (var sort in new[] { "employeeId", "transactionId", "ucEarnEndDate", "reportFteContribution", "reportStatus", "financialDepartment" })
        {
            ExpenseReviewEmployeeTransactionsParser.TryParse("E1", new()
            {
                DetailSortBy = sort, Scope = "all", Search = "  literal%_[]  ",
            }, out var request, out _).Should().BeTrue();
            request.Search.Should().Be("literal%_[]");
            request.SortBy.Should().Be(sort);
            request.Scope.Should().Be("all");
        }
        ExpenseReviewEmployeeTransactionsParser.TryParse("E1", new() { Search = new string('x', 501) },
            out _, out _).Should().BeFalse();
    }
}
