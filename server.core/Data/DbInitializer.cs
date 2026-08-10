using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Server.Core.Data;
using Server.Core.Import;

public interface IDbInitializer
{
    Task InitializeAsync(bool includeDevSeed, CancellationToken cancellationToken = default);
}

public class DbInitializer : IDbInitializer
{
    private readonly AppDbContext _db;
    private readonly DataDbContext _dataDb;
    private readonly ILogger<DbInitializer> _logger;

    public DbInitializer(AppDbContext db, DataDbContext dataDb, ILogger<DbInitializer> logger)
    {
        _db = db;
        _dataDb = dataDb;
        _logger = logger;
    }

    public async Task InitializeAsync(bool includeDevSeed, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Applying database migrations...");
        await _db.Database.MigrateAsync(cancellationToken);
        _logger.LogInformation("Migrations applied.");

        await ImportRunOrchestrator.FailInterruptedRunsAsync(_db, cancellationToken);

        if (includeDevSeed)
        {
            await SeedDevelopmentAsync(cancellationToken);
        }
        else
        {
            await SeedProductionSafeAsync(cancellationToken);
        }
    }

    private async Task SeedDevelopmentAsync(CancellationToken ct)
    {
        // Hierarchy first: chart-string segments are derived from the hierarchy tables.
        await HierarchySeed.EnsureSeededAsync(_dataDb, ct);
        await SegmentClassificationSeed.EnsureSeededAsync(_dataDb, ct);
    }

    // just a placeholder for any production-safe seeding
    private Task SeedProductionSafeAsync(CancellationToken ct)
        => Task.CompletedTask;
}
