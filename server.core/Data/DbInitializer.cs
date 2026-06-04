using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Server.Core.Data;

public interface IDbInitializer
{
    Task InitializeAsync(bool includeDevSeed, CancellationToken cancellationToken = default);

    Task MoveMigrationsHistoryToAppSchemaAsync(CancellationToken cancellationToken = default);
}

public class DbInitializer : IDbInitializer
{
    private readonly AppDbContext _db;
    private readonly ILogger<DbInitializer> _logger;

    public DbInitializer(AppDbContext db, ILogger<DbInitializer> logger)
    {
        _db = db;
        _logger = logger;
    }

    public async Task InitializeAsync(bool includeDevSeed, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Preparing migrations history table...");
        await MoveMigrationsHistoryToAppSchemaAsync(cancellationToken);

        _logger.LogInformation("Applying database migrations...");
        await _db.Database.MigrateAsync(cancellationToken);
        _logger.LogInformation("Migrations applied.");

        if (includeDevSeed)
        {
            await SeedDevelopmentAsync(cancellationToken);
        }
        else
        {
            await SeedProductionSafeAsync(cancellationToken);
        }
    }

    private Task SeedDevelopmentAsync(CancellationToken ct)
        => Task.CompletedTask;

    // just a placeholder for any production-safe seeding
    private Task SeedProductionSafeAsync(CancellationToken ct)
        => Task.CompletedTask;

    public async Task MoveMigrationsHistoryToAppSchemaAsync(CancellationToken cancellationToken = default)
    {
        if (!await _db.Database.CanConnectAsync(cancellationToken))
        {
            return;
        }

        await _db.Database.ExecuteSqlRawAsync(
            """
            IF SCHEMA_ID(N'app') IS NULL
            BEGIN
                EXEC(N'CREATE SCHEMA [app]');
            END;

            IF OBJECT_ID(N'[dbo].[__EFMigrationsHistory]', N'U') IS NOT NULL
                AND OBJECT_ID(N'[app].[__EFMigrationsHistory]', N'U') IS NULL
            BEGIN
                ALTER SCHEMA [app] TRANSFER [dbo].[__EFMigrationsHistory];
            END;
            """,
            cancellationToken);
    }
}
