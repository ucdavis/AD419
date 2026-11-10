using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Server.Core.Data;
using Server.Tests.Helpers;

namespace Server.Tests.ProjectIdentification;

public partial class ProjectIdentificationServiceTests
{
    [Fact]
    public async Task Fiscal_confirmation_invalidates_only_an_actual_cycle_change()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        await using var dataDb = TestDbContextFactory.CreateDataInMemory();
        var invalidator = new RecordingExpenseReviewFilterCacheInvalidator();
        var service = CreateService(db, dataDb, invalidator: invalidator);
        var initial = await service.GetSetupAsync(User, CancellationToken.None);

        await service.ConfirmFiscalPeriodAsync(initial.FiscalYear, User, CancellationToken.None);
        await service.ConfirmFiscalPeriodAsync("invalid", User, CancellationToken.None);
        invalidator.Calls.Should().Be(0);

        var nextCycle = initial.FiscalYear == "FY25" ? "FY26" : "FY25";
        await service.ConfirmFiscalPeriodAsync(nextCycle, User, CancellationToken.None);
        invalidator.Calls.Should().Be(1);
        await service.ConfirmFiscalPeriodAsync(nextCycle, User, CancellationToken.None);
        await service.SetChecklistItemCompletionAsync("fiscal-period", false, User, CancellationToken.None);
        invalidator.Calls.Should().Be(1);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Fiscal_change_invalidation_follows_commit_even_when_response_refresh_fails(bool afterCommit)
    {
        var interceptor = new FinalizationFailureInterceptor();
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase($"FiscalCycle_{Guid.NewGuid():N}")
            .ConfigureWarnings(warnings => warnings.Ignore(InMemoryEventId.TransactionIgnoredWarning))
            .AddInterceptors(interceptor).Options;
        await using var db = new AppDbContext(options);
        await using var dataDb = TestDbContextFactory.CreateDataInMemory();
        var invalidator = new RecordingExpenseReviewFilterCacheInvalidator();
        var service = CreateService(db, dataDb, invalidator: invalidator);
        AddImport(db, "all-projects", 1, "Succeeded", 1, DateTimeOffset.UtcNow);
        await db.SaveChangesAsync();
        var setup = await service.GetSetupAsync(User, CancellationToken.None);
        var nextCycle = setup.FiscalYear == "FY25" ? "FY26" : "FY25";
        var expected = new InvalidOperationException("Simulated persistence failure");
        if (afterCommit) interceptor.RefreshFailure = expected;
        else interceptor.SaveFailure = expected;

        var actual = await Record.ExceptionAsync(() => service.ConfirmFiscalPeriodAsync(nextCycle, User, CancellationToken.None));

        actual.Should().BeSameAs(expected);
        invalidator.Calls.Should().Be(afterCommit ? 1 : 0);
    }
}
