using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Server.Core.Domain;

namespace Server.Tests.Import;

public class ImportRunEntityTests
{
    [Fact]
    public async Task ImportRun_round_trips_with_stages()
    {
        await using var db = TestDbContextFactory.CreateInMemory();

        var run = new ImportRun
        {
            CycleStart = new DateOnly(2024, 10, 1),
            CycleEnd = new DateOnly(2025, 9, 30),
            Status = ImportRunStatus.Running,
            StartedAt = DateTimeOffset.UtcNow,
            Stages =
            {
                new ImportRunStage { Name = "ChartSegments: Fund", Ordinal = 2, Status = ImportStageStatus.Pending },
            },
        };

        db.ImportRuns.Add(run);
        await db.SaveChangesAsync();

        var loaded = await db.ImportRuns.Include(r => r.Stages).SingleAsync();
        loaded.Stages.Should().ContainSingle(s => s.Name == "ChartSegments: Fund" && s.Status == "Pending");
        loaded.Status.Should().Be("Running");
    }
}
