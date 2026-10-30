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
    public async Task<IActionResult> Filters(CancellationToken cancellationToken)
    {
        var (cycle, cycleError) = await GetConfirmedCycleAsync(cancellationToken);
        if (cycle is null)
        {
            return cycleError!;
        }

        var response = await expenseReviewService.GetFilterOptionsAsync(cycle, cancellationToken);
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
