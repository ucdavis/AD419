using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Server.Authorization;
using Server.Core.Data;
using Server.Core.Domain;
using Server.Core.Import;
using Server.Models.ImportRuns;
using System.Security.Claims;

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

    public ImportRunsController(
        AppDbContext appDb,
        IImportStageProvider stageProvider,
        IImportRunStarter runStarter)
    {
        _appDb = appDb;
        _stageProvider = stageProvider;
        _runStarter = runStarter;
    }

    // POST api/importruns
    [HttpPost]
    public async Task<ActionResult<ImportRunDto>> Start(
        [FromBody] StartImportRunRequest request,
        CancellationToken cancellationToken)
    {
        if (request.CycleStart is not { } cycleStart || request.CycleEnd is not { } cycleEnd)
        {
            return BadRequest("cycleStart and cycleEnd are required (yyyy-MM-dd).");
        }

        if (cycleStart > cycleEnd)
        {
            return BadRequest("cycleStart must not be after cycleEnd.");
        }

        if (await _appDb.ImportRuns.AnyAsync(r => r.Status == ImportRunStatus.Running, cancellationToken))
        {
            return Conflict("An import run is already in progress.");
        }

        var run = new ImportRun
        {
            CycleStart = cycleStart,
            CycleEnd = cycleEnd,
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

        _runStarter.Start(run.Id);

        return ImportRunDto.From(run);
    }

    // GET api/importruns/current
    [HttpGet("current")]
    public async Task<ActionResult<ImportRunDto>> Current(CancellationToken cancellationToken)
    {
        var run = await _appDb.ImportRuns
            .Include(r => r.Stages)
            .OrderByDescending(r => r.Id)
            .FirstOrDefaultAsync(cancellationToken);

        return run is null ? NoContent() : ImportRunDto.From(run);
    }
}
