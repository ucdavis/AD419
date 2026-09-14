using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Net.Http.Headers;
using Server.Core.Data;
using Server.ExpenseReview;
using Server.Models;
using Server.Models.ExpenseReview;

namespace Server.Controllers;

[ApiController]
[Route("api/[controller]")]
public sealed class ExpenseReviewController(
    IExpenseReviewService expenseReviewService,
    AppDbContext appDb) : ApiControllerBase
{
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

    private async Task<(FiscalYearCycle? Cycle, IActionResult? Error)> GetConfirmedCycleAsync(
        CancellationToken cancellationToken)
    {
        var run = await appDb.WorkflowRuns.SingleOrDefaultAsync(r => r.IsCurrent, cancellationToken);
        if (run is null || !FiscalYearCycle.TryParse(run.FiscalYear, out var parsedCycle))
        {
            return (null, Conflict("No fiscal period has been confirmed in Project Identification."));
        }

        return (new FiscalYearCycle(run.FiscalYear, run.CycleStart, run.CycleEnd), null);
    }
}
