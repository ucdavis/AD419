using FluentAssertions;
using Server.Core.Domain;
using Server.ExpenseReview;
using Server.Tests;

namespace Server.Tests.ExpenseReview;

public class ConfirmedCycleProviderTests
{
    [Fact]
    public async Task GetAsync_returns_the_current_run_cycle()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        db.WorkflowRuns.Add(new WorkflowRun
        {
            FiscalYear = "FY25",
            CycleStart = new DateOnly(2024, 10, 1),
            CycleEnd = new DateOnly(2025, 9, 30),
            IsCurrent = true,
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow,
        });
        await db.SaveChangesAsync();

        var cycle = await new ConfirmedCycleProvider(db).GetAsync(CancellationToken.None);

        cycle.Should().NotBeNull();
        cycle!.FiscalYear.Should().Be("FY25");
        cycle.CycleStart.Should().Be(new DateOnly(2024, 10, 1));
        cycle.CycleEnd.Should().Be(new DateOnly(2025, 9, 30));
    }

    [Fact]
    public async Task GetAsync_returns_null_without_a_current_run()
    {
        await using var db = TestDbContextFactory.CreateInMemory();

        var cycle = await new ConfirmedCycleProvider(db).GetAsync(CancellationToken.None);

        cycle.Should().BeNull();
    }

    [Fact]
    public async Task GetAsync_returns_null_when_the_fiscal_year_does_not_parse()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        db.WorkflowRuns.Add(new WorkflowRun
        {
            FiscalYear = "not-a-year",
            CycleStart = new DateOnly(2024, 10, 1),
            CycleEnd = new DateOnly(2025, 9, 30),
            IsCurrent = true,
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow,
        });
        await db.SaveChangesAsync();

        var cycle = await new ConfirmedCycleProvider(db).GetAsync(CancellationToken.None);

        cycle.Should().BeNull();
    }
}
