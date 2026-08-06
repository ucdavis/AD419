using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Server.Core.Data;
using Server.Core.Domain;

namespace Server.Core.Import;

public sealed class ImportRunOrchestrator
{
    private readonly AppDbContext _appDb;
    private readonly IImportStageProvider _stageProvider;
    private readonly ILogger<ImportRunOrchestrator> _logger;

    public ImportRunOrchestrator(
        AppDbContext appDb,
        IImportStageProvider stageProvider,
        ILogger<ImportRunOrchestrator> logger)
    {
        _appDb = appDb;
        _stageProvider = stageProvider;
        _logger = logger;
    }

    public async Task RunAsync(int runId, CancellationToken cancellationToken = default)
    {
        var run = await _appDb.ImportRuns
            .Include(r => r.Stages)
            .SingleAsync(r => r.Id == runId, cancellationToken);

        var context = new ImportRunContext(run.Id, run.CycleStart, run.CycleEnd);
        var stagesByName = run.Stages.ToDictionary(s => s.Name);

        foreach (var stage in _stageProvider.BuildStages(context))
        {
            var record = stagesByName[stage.Name];
            record.Status = ImportStageStatus.Running;
            record.StartedAt = DateTimeOffset.UtcNow;
            await _appDb.SaveChangesAsync(cancellationToken);

            try
            {
                var result = await stage.ExecuteAsync(cancellationToken);
                record.RowCount = result.RowCount;
                record.Detail = result.Detail;
                record.Status = ImportStageStatus.Succeeded;
                record.CompletedAt = DateTimeOffset.UtcNow;
                await _appDb.SaveChangesAsync(cancellationToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Import stage {Stage} failed for run {RunId}", stage.Name, runId);
                record.Status = ImportStageStatus.Failed;
                record.ErrorDetail = ex.ToString();
                record.CompletedAt = DateTimeOffset.UtcNow;
                run.Status = ImportRunStatus.Failed;
                run.CompletedAt = DateTimeOffset.UtcNow;
                await _appDb.SaveChangesAsync(CancellationToken.None);
                return;
            }
        }

        run.Status = ImportRunStatus.Succeeded;
        run.CompletedAt = DateTimeOffset.UtcNow;
        await _appDb.SaveChangesAsync(cancellationToken);
    }

    public static async Task FailInterruptedRunsAsync(AppDbContext appDb, CancellationToken cancellationToken = default)
    {
        var interrupted = await appDb.ImportRuns
            .Include(r => r.Stages)
            .Where(r => r.Status == ImportRunStatus.Running)
            .ToListAsync(cancellationToken);

        foreach (var run in interrupted)
        {
            run.Status = ImportRunStatus.Failed;
            run.CompletedAt = DateTimeOffset.UtcNow;

            foreach (var stage in run.Stages.Where(s => s.Status == ImportStageStatus.Running))
            {
                stage.Status = ImportStageStatus.Failed;
                stage.ErrorDetail = "Interrupted by application restart.";
                stage.CompletedAt = DateTimeOffset.UtcNow;
            }
        }

        await appDb.SaveChangesAsync(cancellationToken);
    }
}
