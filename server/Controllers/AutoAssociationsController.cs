using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Server.AutoAssociations;
using Server.Core.Data;
using Server.Models;
using Server.Models.AutoAssociations;

namespace Server.Controllers;

// Read-only reports for the Auto-Associations stage over the staging tables.
public sealed class AutoAssociationsController(
    IAutoAssociationReportService reports,
    AppDbContext appDb) : ApiControllerBase
{
    [HttpGet("build")]
    public Task<IActionResult> Build(CancellationToken cancellationToken) =>
        ReportAsync(reports.GetBuildAsync, cancellationToken);

    [HttpGet("rule-204")]
    public Task<IActionResult> Rule204(CancellationToken cancellationToken) =>
        ReportAsync(reports.GetRule204Async, cancellationToken);

    [HttpGet("rule-20x")]
    public Task<IActionResult> Rule20x(CancellationToken cancellationToken) =>
        ReportAsync(reports.GetRule20xAsync, cancellationToken);

    [HttpGet("rule-220")]
    public Task<IActionResult> Rule220(CancellationToken cancellationToken) =>
        ReportAsync(reports.GetRule220Async, cancellationToken);

    [HttpGet("excluded-projects")]
    public Task<IActionResult> ExcludedProjects(CancellationToken cancellationToken) =>
        ReportAsync(reports.GetExcludedProjectsAsync, cancellationToken);

    [HttpGet("fte-over-one")]
    public Task<IActionResult> FteOverOne(CancellationToken cancellationToken) =>
        ReportAsync(reports.GetFteOverOneAsync, cancellationToken);

    [HttpGet("pre-association-totals")]
    public Task<IActionResult> PreAssociationTotals(CancellationToken cancellationToken) =>
        ReportAsync(reports.GetPreAssociationTotalsAsync, cancellationToken);

    private async Task<IActionResult> ReportAsync<T>(
        Func<CancellationToken, Task<T>> load,
        CancellationToken cancellationToken)
    {
        var run = await appDb.WorkflowRuns.SingleOrDefaultAsync(r => r.IsCurrent, cancellationToken);
        if (run is null || !FiscalYearCycle.TryParse(run.FiscalYear, out _))
        {
            return Conflict("No fiscal period has been confirmed in Project Identification.");
        }

        var data = await load(cancellationToken);
        return Ok(new AutoAssociationReportResponse<T>(run.FiscalYear, run.CycleStart, run.CycleEnd, data));
    }
}
