using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Server.Authorization;
using Server.Core.Data;
using Server.Core.Domain;
using Server.Core.Import;
using Server.Models.ImportRuns;
using System.Security.Claims;
using Server.Workflow;

namespace Server.Controllers;

public interface IImportRunStarter
{
    void Start(int runId);
}

public sealed class ImportRunStarter(IServiceScopeFactory scopeFactory, ILogger<ImportRunStarter> logger)
    : IImportRunStarter
{
    public void Start(int runId)
    {
        _ = Task.Run(async () =>
        {
            try
            {
                using var scope = scopeFactory.CreateScope();
                var orchestrator = scope.ServiceProvider.GetRequiredService<ImportRunOrchestrator>();
                await orchestrator.RunAsync(runId);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Import run {RunId} crashed outside stage handling", runId);
            }
        });
    }
}

public class ImportRunsController : ApiControllerBase
{
    private readonly AppDbContext _appDb;
    private readonly IImportStageProvider _stageProvider;
    private readonly IImportRunStarter _runStarter;
    private readonly IImportReadinessCheck _readinessCheck;
    private readonly IWorkflowService _workflowService;

    public ImportRunsController(
        AppDbContext appDb,
        IImportStageProvider stageProvider,
        IImportRunStarter runStarter,
        IImportReadinessCheck readinessCheck,
        IWorkflowService workflowService)
    {
        _appDb = appDb;
        _stageProvider = stageProvider;
        _runStarter = runStarter;
        _readinessCheck = readinessCheck;
        _workflowService = workflowService;
    }

    // POST api/importruns
    // Cycle dates come from the confirmed fiscal period, never from the client:
    // a stale browser tab must not be able to import the wrong year.
    [HttpPost]
    public async Task<ActionResult<ImportRunDto>> Start(CancellationToken cancellationToken)
    {
        var workflowRun = await _appDb.WorkflowRuns
            .SingleOrDefaultAsync(r => r.IsCurrent, cancellationToken);
        if (workflowRun is null)
        {
            return Conflict("No fiscal period has been confirmed in Project Identification.");
        }

        if (await _appDb.ImportRuns.AnyAsync(r => r.Status == ImportRunStatus.Running, cancellationToken))
        {
            return Conflict("An import run is already in progress.");
        }

        if (await _readinessCheck.GetBlockingIssueAsync(
                workflowRun.CycleStart, workflowRun.CycleEnd, cancellationToken) is { } blockingIssue)
        {
            return Conflict(blockingIssue);
        }

        var run = new ImportRun
        {
            CycleStart = workflowRun.CycleStart,
            CycleEnd = workflowRun.CycleEnd,
            Status = ImportRunStatus.Running,
            TriggeredByEntraId = User.GetEntraId(),
            TriggeredByName = User.FindFirst("name")?.Value ?? User.Identity?.Name,
            TriggeredByEmail = User.FindFirst("preferred_username")?.Value ?? User.FindFirst(ClaimTypes.Email)?.Value,
            StartedAt = DateTimeOffset.UtcNow,
            Stages = _stageProvider.StageNames
                .Select((name, i) => new ImportRunStage { Name = name, Ordinal = i, Status = ImportStageStatus.Pending })
                .ToList(),
        };

        _appDb.ImportRuns.Add(run);
        await _appDb.SaveChangesAsync(cancellationToken);
        await _workflowService.ResetFromStageAsync(
            WorkflowStageIds.DataImport,
            User,
            cancellationToken);

        _runStarter.Start(run.Id);

        return ImportRunDto.From(run);
    }

    // GET api/importruns/current
    [HttpGet("current")]
    public async Task<ActionResult<ImportRunDto>> Current(CancellationToken cancellationToken)
    {
        var workflowRun = await _appDb.WorkflowRuns
            .SingleOrDefaultAsync(r => r.IsCurrent, cancellationToken);

        if (workflowRun is null)
        {
            return NoContent();
        }

        var run = await _appDb.ImportRuns
            .Include(r => r.Stages)
            .Where(r => r.CycleStart == workflowRun.CycleStart && r.CycleEnd == workflowRun.CycleEnd)
            .OrderByDescending(r => r.Id)
            .FirstOrDefaultAsync(cancellationToken);

        return run is null ? NoContent() : ImportRunDto.From(run);
    }
}
