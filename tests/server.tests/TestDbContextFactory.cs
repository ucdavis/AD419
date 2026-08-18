using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Server.Core.Data;

namespace Server.Tests;

public static class TestDbContextFactory
{
    /// <summary>
    /// Creates a fresh AppDbContext using EFCore InMemory with a unique database name,
    /// so each test starts clean.
    /// </summary>
    public static AppDbContext CreateInMemory()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: $"TestDb_{Guid.NewGuid():N}")
            .ConfigureWarnings(warnings => warnings.Ignore(InMemoryEventId.TransactionIgnoredWarning))
            .EnableSensitiveDataLogging()
            .Options;

        var ctx = new AppDbContext(options);
        ctx.Database.EnsureCreated();
        return ctx;
    }

    /// <summary>
    /// Creates a fresh DataDbContext using EFCore InMemory with a unique database name,
    /// so each test starts clean.
    /// </summary>
    public static DataDbContext CreateDataInMemory()
    {
        var options = new DbContextOptionsBuilder<DataDbContext>()
            .UseInMemoryDatabase(databaseName: $"TestDataDb_{Guid.NewGuid():N}")
            .ConfigureWarnings(warnings => warnings.Ignore(InMemoryEventId.TransactionIgnoredWarning))
            .EnableSensitiveDataLogging()
            .Options;

        var ctx = new DataDbContext(options);
        ctx.Database.EnsureCreated();
        return ctx;
    }
}
