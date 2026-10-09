using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.Logging;
using Server.Core.Data;
using Server.Core.Domain;
using Server.Core.Import;
using Server.ProjectIdentification;
using Server.Tests.Helpers;

namespace Server.Tests.ProjectIdentification;

public partial class ProjectIdentificationServiceTests
{
    [Fact]
    public async Task Finalization_logs_context_and_separate_persistence_milestones()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        await using var dataDb = TestDbContextFactory.CreateDataInMemory();
        var logger = new RecordingLogger<ProjectIdentificationService>();
        var projects = new StubProjectListService { RowsBuilt = 44 };
        var service = CreateService(db, dataDb, projects, logger);
        await PrepareFinalizationAsync(db, service);

        var response = await service.FinalizeProjectsAsync(User, CancellationToken.None);

        response.Should().NotBeNull();
        logger.Entries.Select(e => e.Message).Should().Equal(
            "Projects committed. ProjectsBuilt=44.", "Workflow completion saved.");
        logger.Entries[0].Fields.Should().Contain("ProjectsBuilt", 44);
        foreach (var entry in logger.Entries)
        {
            entry.Fields.Should().Contain("WorkflowRunId", response!.WorkflowRunId).And.Contain("FiscalYear", "FY26")
                .And.Contain("CycleStart", new DateOnly(2025, 10, 1)).And.Contain("CycleEnd", new DateOnly(2026, 9, 30));
        }
        logger.LogInformation("After finalization");
        logger.Entries.Last().Fields.Should().NotContainKey("WorkflowRunId").And.NotContainKey("FiscalYear");
    }

    [Theory]
    [InlineData("Unmet prerequisites")]
    [InlineData("Already completed")]
    [InlineData("Unresolved issues")]
    [InlineData("Invalid fiscal year")]
    public async Task Finalization_rejection_logs_reason_without_build_or_success(string reason)
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        await using var dataDb = TestDbContextFactory.CreateDataInMemory();
        var logger = new RecordingLogger<ProjectIdentificationService>();
        var projects = new StubProjectListService();
        var service = CreateService(db, dataDb, projects, logger);
        if (reason != "Unmet prerequisites") await PrepareFinalizationAsync(db, service);
        if (reason == "Already completed") await service.FinalizeProjectsAsync(User, CancellationToken.None);
        if (reason == "Unresolved issues") projects.IssuesToResolve = 1;
        if (reason == "Invalid fiscal year")
        {
            db.WorkflowRuns.Single().FiscalYear = "invalid";
            await db.SaveChangesAsync();
        }
        var buildsBefore = projects.BuildProjectsCalls;
        logger.Entries.Clear();

        var response = await service.FinalizeProjectsAsync(User, CancellationToken.None);

        response.Should().BeNull();
        projects.BuildProjectsCalls.Should().Be(buildsBefore);
        var skipped = logger.Entries.Should().ContainSingle().Subject;
        skipped.Level.Should().Be(LogLevel.Information);
        skipped.Fields.Should().Contain("Reason", reason);
        skipped.Message.Should().StartWith("Project finalization skipped:");
    }

    [Theory]
    [InlineData("Build projects", false, false, false)]
    [InlineData("Build projects", true, false, false)]
    [InlineData("Save workflow completion", false, true, false)]
    [InlineData("Save workflow completion", true, true, false)]
    [InlineData("Refresh setup", false, true, true)]
    [InlineData("Refresh setup", true, true, true)]
    public async Task Finalization_failure_records_confirmed_persistence_only(
        string phase, bool canceled, bool projectsCommitted, bool workflowSaved)
    {
        var interceptor = new FinalizationFailureInterceptor();
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase($"Finalization_{Guid.NewGuid():N}")
            .ConfigureWarnings(warnings => warnings.Ignore(InMemoryEventId.TransactionIgnoredWarning))
            .AddInterceptors(interceptor).Options;
        await using var db = new AppDbContext(options);
        await using var dataDb = TestDbContextFactory.CreateDataInMemory();
        var logger = new RecordingLogger<ProjectIdentificationService>();
        var projects = new StubProjectListService { RowsBuilt = 44 };
        var service = CreateService(db, dataDb, projects, logger);
        await PrepareFinalizationAsync(db, service);
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();
        Exception expected = canceled ? new OperationCanceledException(cancellation.Token) : new InvalidOperationException("failure");
        if (phase == "Build projects") projects.BuildHandler = _ => Task.FromException<int>(expected);
        if (phase == "Save workflow completion") interceptor.SaveFailure = expected;
        if (phase == "Refresh setup") interceptor.RefreshFailure = expected;

        var actual = await Record.ExceptionAsync(() => service.FinalizeProjectsAsync(User, CancellationToken.None));

        actual.Should().BeSameAs(expected);
        logger.Entries.Should().HaveCount((projectsCommitted ? 1 : 0) + (workflowSaved ? 1 : 0));
        if (projectsCommitted) logger.Entries[0].Fields.Should().Contain("ProjectsBuilt", 44);
        logger.Entries.Any(e => e.Message.StartsWith("Projects committed.")).Should().Be(projectsCommitted);
        logger.Entries.Any(e => e.Message.StartsWith("Workflow completion saved.")).Should().Be(workflowSaved);

        interceptor.SaveFailure = null;
        interceptor.RefreshFailure = null;
        db.ChangeTracker.Clear();
        var persisted = await db.WorkflowChecklistItemStates.AsNoTracking()
            .SingleOrDefaultAsync(s => s.ItemId == "finalize-projects");
        (persisted?.CompletedAt != null).Should().Be(workflowSaved);

        // A subsequent invocation must acquire the gate even after an exception.
        projects.BuildHandler = null;
        await service.FinalizeProjectsAsync(User, CancellationToken.None).WaitAsync(TimeSpan.FromSeconds(10));
    }

    [Fact]
    public async Task Canceled_gate_wait_does_not_release_another_invocations_gate()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        await using var dataDb = TestDbContextFactory.CreateDataInMemory();
        var logger = new RecordingLogger<ProjectIdentificationService>();
        var enteredBuild = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var releaseBuild = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var projects = new StubProjectListService
        {
            BuildHandler = async _ =>
            {
                enteredBuild.TrySetResult();
                await releaseBuild.Task;
                return 44;
            },
        };
        var service = CreateService(db, dataDb, projects, logger);
        await PrepareFinalizationAsync(db, service);
        var holder = service.FinalizeProjectsAsync(User, CancellationToken.None);
        Task? following = null;
        try
        {
            await enteredBuild.Task.WaitAsync(TimeSpan.FromSeconds(10));
            using var cancellation = new CancellationTokenSource();
            var waiting = service.FinalizeProjectsAsync(User, cancellation.Token);
            waiting.IsCompleted.Should().BeFalse();
            cancellation.Cancel();
            var error = await Record.ExceptionAsync(() => waiting.WaitAsync(TimeSpan.FromSeconds(10)));
            error.Should().BeAssignableTo<OperationCanceledException>();
            ((OperationCanceledException)error!).CancellationToken.Should().Be(cancellation.Token);

            following = service.FinalizeProjectsAsync(User, CancellationToken.None);
            following.IsCompleted.Should().BeFalse();
            projects.BuildProjectsCalls.Should().Be(1);
            logger.Entries.Should().BeEmpty();
        }
        finally
        {
            releaseBuild.TrySetResult();
            await holder.WaitAsync(TimeSpan.FromSeconds(10));
            if (following != null) await following.WaitAsync(TimeSpan.FromSeconds(10));
        }
        projects.BuildProjectsCalls.Should().Be(1);
    }

    private static async Task PrepareFinalizationAsync(AppDbContext db, ProjectIdentificationService service)
    {
        var completedAt = DateTimeOffset.Parse("2026-06-01T12:00:00Z");
        AddImport(db, "all-projects", 1, "Succeeded", 100, completedAt);
        AddImport(db, "active-projects", 2, "Succeeded", 50, completedAt);
        AddImport(db, "assistance-listing-numbers", 3, "Succeeded", 200, completedAt);
        await db.SaveChangesAsync();
        await service.ConfirmFiscalPeriodAsync("FY26", User, CancellationToken.None);
        foreach (var item in new[] { "all-projects", "active-projects", "assistance-listing-numbers" })
            await service.SetChecklistItemCompletionAsync(item, true, User, CancellationToken.None);
        await service.RecordPgmImportAsync(new PgmProjectsImportResult(1234, new DateOnly(2026, 9, 30)), User, CancellationToken.None);
        await service.SetChecklistItemCompletionAsync("pgm-master-data", true, User, CancellationToken.None);
        await service.SetChecklistItemCompletionAsync("resolve-project-issues", true, User, CancellationToken.None);
    }

    private sealed class FinalizationFailureInterceptor : SaveChangesInterceptor, IMaterializationInterceptor
    {
        public Exception? SaveFailure { get; set; }
        public Exception? RefreshFailure { get; set; }
        private bool _saved;

        public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
            DbContextEventData eventData, InterceptionResult<int> result, CancellationToken cancellationToken = default)
        {
            if (SaveFailure != null) throw SaveFailure;
            return ValueTask.FromResult(result);
        }

        public override ValueTask<int> SavedChangesAsync(
            SaveChangesCompletedEventData eventData, int result, CancellationToken cancellationToken = default)
        {
            _saved = RefreshFailure != null;
            return ValueTask.FromResult(result);
        }

        public object InitializedInstance(MaterializationInterceptionData materializationData, object entity)
        {
            if (_saved && RefreshFailure != null && entity is ImportLog) throw RefreshFailure;
            return entity;
        }
    }
}
