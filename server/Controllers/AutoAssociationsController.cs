using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Server.AutoAssociations;
using Server.Core.Data;
using Server.Models;
using Server.Models.AutoAssociations;

namespace Server.Controllers;

// Reports for the Auto-Associations stage over the staging tables, and the
// rebuild that replaces those tables with a fresh run.
public sealed class AutoAssociationsController(
    IAutoAssociationReportService reports,
    IAutoAssociationBuilder builder,
    AppDbContext appDb) : ApiControllerBase
{
    private const string NoCycleMessage = "No fiscal period has been confirmed in Project Identification.";

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

    // Reruns the build for the current cycle so changes made upstream after
    // OrgR Review completed (a job code assigned a line, say) reach the
    // reports without reopening a stage. Stage statuses are not touched. The
    // procedure replaces the staging tables in one transaction, so a rejected
    // build leaves the previous one in place.
    [HttpPost("rebuild")]
    public async Task<IActionResult> Rebuild(CancellationToken cancellationToken)
    {
        var run = await appDb.WorkflowRuns.SingleOrDefaultAsync(r => r.IsCurrent, cancellationToken);
        if (run is null || !FiscalYearCycle.TryParse(run.FiscalYear, out _))
        {
            return Conflict(NoCycleMessage);
        }

        // The first build belongs to completing OrgR Review, which checks
        // that every included row has an OrgR.
        if (!await builder.BuildExistsAsync(cancellationToken))
        {
            return Conflict("Auto-associations have not run yet.");
        }

        try
        {
            await builder.BuildAsync(
                new FiscalYearCycle(run.FiscalYear, run.CycleStart, run.CycleEnd),
                cancellationToken);
        }
        catch (AutoAssociationBuildException ex)
        {
            return Conflict(ex.Message);
        }

        var build = await reports.GetBuildAsync(cancellationToken);
        return Ok(new AutoAssociationReportResponse<AutoAssociationBuildDto?>(run.FiscalYear, run.CycleStart, run.CycleEnd, build));
    }

    private async Task<IActionResult> ReportAsync<T>(
        Func<CancellationToken, Task<T>> load,
        CancellationToken cancellationToken)
    {
        var run = await appDb.WorkflowRuns.SingleOrDefaultAsync(r => r.IsCurrent, cancellationToken);
        if (run is null || !FiscalYearCycle.TryParse(run.FiscalYear, out _))
        {
            return Conflict(NoCycleMessage);
        }

        var data = await load(cancellationToken);
        return Ok(new AutoAssociationReportResponse<T>(run.FiscalYear, run.CycleStart, run.CycleEnd, data));
    }
}
