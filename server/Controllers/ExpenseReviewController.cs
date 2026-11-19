using Microsoft.AspNetCore.Mvc;
using Microsoft.Net.Http.Headers;
using Server.ExpenseReview;
using Server.Models;
using Server.Models.ExpenseReview;

namespace Server.Controllers;

[ApiController]
[Route("api/[controller]")]
public sealed class ExpenseReviewController(
    IExpenseReviewService expenseReviewService,
    IConfirmedCycleProvider confirmedCycles) : ApiControllerBase
{
    [HttpGet("employees/{employeeId}/transactions")]
    public async Task<IActionResult> EmployeeTransactions(string employeeId,
        [FromQuery] ExpenseReviewEmployeeTransactionsQuery query, CancellationToken cancellationToken)
    {
        if (!ExpenseReviewEmployeeTransactionsParser.TryParse(employeeId, query, out var request, out var error))
            return BadRequest(error);
        var (cycle, cycleError) = await GetConfirmedCycleAsync(cancellationToken);
        if (cycle == null) return cycleError!;
        var result = await expenseReviewService.GetEmployeeTransactionsAsync(cycle, request, cancellationToken);
        if (!result.BuildAvailable) return Conflict("Auto-associations must be built for the confirmed fiscal period.");
        return result.Response == null
            ? NotFound("The employee has no UCPath summary rows in the current report.")
            : Ok(result.Response);
    }

    [HttpGet("employees/{employeeId}/transactions.csv")]
    public async Task<IActionResult> EmployeeTransactionsCsv(string employeeId,
        [FromQuery] ExpenseReviewEmployeeTransactionsQuery query, CancellationToken cancellationToken)
    {
        if (!ExpenseReviewEmployeeTransactionsParser.TryParse(employeeId, query, out var request, out var error))
            return BadRequest(error);
        var (cycle, cycleError) = await GetConfirmedCycleAsync(cancellationToken);
        if (cycle == null) return cycleError!;
        var result = await expenseReviewService.GetEmployeeTransactionsAsync(cycle,
            request with { Page = 1, PageSize = 1 }, cancellationToken);
        if (!result.BuildAvailable) return Conflict("Auto-associations must be built for the confirmed fiscal period.");
        if (result.Response == null) return NotFound("The employee has no UCPath summary rows in the current report.");
        Response.ContentType = "text/csv; charset=utf-8";
        Response.Headers[HeaderNames.ContentDisposition] = new ContentDispositionHeaderValue("attachment")
        {
            FileNameStar = $"employee-transactions-{cycle.FiscalYear}.csv",
        }.ToString();
        try
        {
            await expenseReviewService.WriteEmployeeTransactionsCsvAsync(cycle, request, result.Response,
                Response.Body, cancellationToken);
        }
        catch (ExpenseReviewEmployeeTransactionsUnavailableException exception)
        {
            // Validation failed before the writer emitted CSV headers or rows.
            Response.ContentType = null;
            Response.Headers.Remove(HeaderNames.ContentDisposition);
            return exception.BuildAvailable
                ? NotFound("The employee has no UCPath summary rows in the current report.")
                : Conflict("Auto-associations must be built for the confirmed fiscal period.");
        }
        return new EmptyResult();
    }

    [HttpGet("groups/{groupId}/transactions")]
    public async Task<IActionResult> GroupTransactions(string groupId,
        [FromQuery] ExpenseReviewGroupTransactionsQuery query, CancellationToken cancellationToken)
    {
        if (!ExpenseReviewGroupTransactionsParser.TryParse(groupId, query, out var request, out var error))
            return BadRequest(error);
        var (cycle, cycleError) = await GetConfirmedCycleAsync(cancellationToken);
        if (cycle is null) return cycleError!;
        var response = await expenseReviewService.GetGroupTransactionsAsync(cycle, request, cancellationToken);
        return response is null ? NotFound("The group does not exist in the supplied context.") : Ok(response);
    }

    [HttpGet("groups/{groupId}/transactions.csv")]
    public async Task<IActionResult> GroupTransactionsCsv(string groupId,
        [FromQuery] ExpenseReviewGroupTransactionsQuery query, CancellationToken cancellationToken)
    {
        if (!ExpenseReviewGroupTransactionsParser.TryParse(groupId, query, out var request, out var error))
            return BadRequest(error);
        var (cycle, cycleError) = await GetConfirmedCycleAsync(cancellationToken);
        if (cycle is null) return cycleError!;
        var response = await expenseReviewService.GetGroupTransactionsAsync(cycle,
            request with { Context = request.Context with { Page = 1, PageSize = 1 } }, cancellationToken);
        if (response is null) return NotFound("The group does not exist in the supplied context.");
        Response.ContentType = "text/csv; charset=utf-8";
        Response.Headers[HeaderNames.ContentDisposition] = new ContentDispositionHeaderValue("attachment")
        {
            FileNameStar = $"expense-review-{cycle.FiscalYear}-{response.Group.Source}-{request.GroupId}.csv",
        }.ToString();
        await expenseReviewService.WriteGroupTransactionsCsvAsync(cycle, request, response.Group,
            Response.Body, cancellationToken);
        return new EmptyResult();
    }

    [HttpGet("transactions")]
    public async Task<IActionResult> Transactions(
        [FromQuery] ExpenseReviewTransactionsQuery query,
        CancellationToken cancellationToken)
    {
        if (!ExpenseReviewRequestParser.TryParse(query, out var request, out var error))
        {
            return BadRequest(error);
        }

        var (cycle, cycleError) = await GetConfirmedCycleAsync(cancellationToken);
        if (cycle is null)
        {
            return cycleError!;
        }

        var response = await expenseReviewService.GetTransactionsAsync(cycle, request, cancellationToken);
        return Ok(response);
    }

    [HttpGet("transactions.csv")]
    public async Task<IActionResult> TransactionsCsv(
        [FromQuery] ExpenseReviewTransactionsQuery query,
        CancellationToken cancellationToken)
    {
        if (!ExpenseReviewRequestParser.TryParse(query, out var request, out var error))
        {
            return BadRequest(error);
        }

        var (cycle, cycleError) = await GetConfirmedCycleAsync(cancellationToken);
        if (cycle is null)
        {
            return cycleError!;
        }

        var filename = $"expense-review-transactions-{cycle.FiscalYear.ToLowerInvariant()}.csv";
        Response.ContentType = "text/csv; charset=utf-8";
        Response.Headers[HeaderNames.ContentDisposition] = new ContentDispositionHeaderValue("attachment")
        {
            FileNameStar = filename,
        }.ToString();

        await expenseReviewService.WriteTransactionsCsvAsync(
            cycle,
            request,
            Response.Body,
            cancellationToken);
        return new EmptyResult();
    }

    [HttpGet("filters")]
    public async Task<IActionResult> Filters(
        [FromQuery] ExpenseReviewFiltersQuery query,
        CancellationToken cancellationToken)
    {
        var (cycle, cycleError) = await GetConfirmedCycleAsync(cancellationToken);
        if (cycle is null)
        {
            return cycleError!;
        }

        var response = await expenseReviewService.GetFilterOptionsAsync(
            cycle,
            ExpenseReviewRequestParser.ParseFilters(query),
            cancellationToken);
        return Ok(response);
    }

    [HttpGet("unmatched-job-codes")]
    public async Task<IActionResult> UnmatchedJobCodes(CancellationToken cancellationToken)
    {
        var (cycle, cycleError) = await GetConfirmedCycleAsync(cancellationToken);
        if (cycle is null)
        {
            return cycleError!;
        }

        var response = await expenseReviewService.GetUnmatchedJobCodesAsync(cycle, cancellationToken);
        return Ok(response);
    }

    private async Task<(FiscalYearCycle? Cycle, IActionResult? Error)> GetConfirmedCycleAsync(
        CancellationToken cancellationToken)
    {
        var cycle = await confirmedCycles.GetAsync(cancellationToken);
        return cycle is null
            ? (null, Conflict("No fiscal period has been confirmed in Project Identification."))
            : (cycle, null);
    }
}
