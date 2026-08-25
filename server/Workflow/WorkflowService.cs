using System.Security.Claims;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Server.Authorization;
using Server.Core.Data;
using Server.Core.Domain;
using Server.Models;
using Server.Models.Workflow;

namespace Server.Workflow;

public sealed class WorkflowService(AppDbContext dbContext) : IWorkflowService
{
    public async Task<WorkflowRun> GetOrCreateCurrentRunAsync(
        ClaimsPrincipal user,
        CancellationToken cancellationToken)
    {
        var run = await GetCurrentRunAsync(cancellationToken);

        if (run is not null)
        {
            return run;
        }

        var cycle = FiscalYearCycle.Current();
        var now = DateTimeOffset.UtcNow;
        run = new WorkflowRun
        {
            FiscalYear = cycle.FiscalYear,
            CycleStart = cycle.CycleStart,
            CycleEnd = cycle.CycleEnd,
            CreatedAt = now,
            IsCurrent = true,
            UpdatedAt = now,
        };

        SetCreatedBy(run, user);
        SetUpdatedBy(run, user);
        dbContext.WorkflowRuns.Add(run);

        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
            return run;
        }
        catch (DbUpdateException ex) when (IsSqlServerUniquenessViolation(ex))
        {
            dbContext.Entry(run).State = EntityState.Detached;
            return await GetCurrentRunAsync(cancellationToken)
                ?? throw new InvalidOperationException("A current workflow run already exists but could not be loaded.", ex);
        }
    }

    public async Task<WorkflowSnapshotResponse> GetSnapshotAsync(
        ClaimsPrincipal user,
        CancellationToken cancellationToken)
    {
        var run = await GetOrCreateCurrentRunAsync(user, cancellationToken);
        EnsureStageStates(run, user, DateTimeOffset.UtcNow);
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
            return CreateSnapshot(run);
        }
        catch (DbUpdateException ex) when (IsSqlServerUniquenessViolation(ex))
        {
            return await ReloadSnapshotAfterStageStateUniquenessViolationAsync(ex, cancellationToken);
        }
    }

    public async Task<WorkflowSnapshotResponse?> SetStageStatusAsync(
        string stageId,
        string status,
        ClaimsPrincipal user,
        CancellationToken cancellationToken)
    {
        var definition = WorkflowStages.Find(stageId);
        if (definition is null || !IsValidTransitionStatus(status))
        {
            return null;
        }

        var run = await GetOrCreateCurrentRunAsync(user, cancellationToken);
        var now = DateTimeOffset.UtcNow;
        EnsureStageStates(run, user, now);

        var states = StatesByStageId(run);
        var state = states[definition.Id];
        var previousComplete = PreviousStagesComplete(states, definition.Number);
        var canAccess = state.Status == WorkflowStageStatus.Complete || previousComplete;

        if (!canAccess)
        {
            return null;
        }

        if (status == WorkflowStageStatus.Complete)
        {
            if (!previousComplete)
            {
                return null;
            }

            CompleteStage(state, user, now);
            var next = WorkflowStages.All.FirstOrDefault(stage => stage.Number == definition.Number + 1);
            if (next is not null && states[next.Id].Status == WorkflowStageStatus.NotStarted)
            {
                StartStage(states[next.Id], user, now);
            }
        }
        else
        {
            StartStageIfNeeded(state, user, now);
            ClearCompleted(state);
            ClearDownstream(states, definition.Number);
        }

        Touch(run, user, now);
        await dbContext.SaveChangesAsync(cancellationToken);
        return CreateSnapshot(run);
    }

    public async Task ResetFromStageAsync(
        string stageId,
        ClaimsPrincipal user,
        CancellationToken cancellationToken)
    {
        var definition = WorkflowStages.Find(stageId)
            ?? throw new ArgumentException($"Unknown workflow stage '{stageId}'.", nameof(stageId));
        var run = await GetOrCreateCurrentRunAsync(user, cancellationToken);
        var now = DateTimeOffset.UtcNow;
        EnsureStageStates(run, user, now);

        var states = StatesByStageId(run);
        var state = states[definition.Id];
        StartStageIfNeeded(state, user, now);
        ClearCompleted(state);
        ClearDownstream(states, definition.Number);

        Touch(run, user, now);
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private Task<WorkflowRun?> GetCurrentRunAsync(CancellationToken cancellationToken) =>
        dbContext.WorkflowRuns
            .Include(run => run.ChecklistItemStates)
            .Include(run => run.StageStates)
            .Where(run => run.IsCurrent)
            .OrderByDescending(run => run.CreatedAt)
            .FirstOrDefaultAsync(cancellationToken);

    private async Task<WorkflowSnapshotResponse> ReloadSnapshotAfterStageStateUniquenessViolationAsync(
        DbUpdateException exception,
        CancellationToken cancellationToken)
    {
        foreach (var entry in dbContext.ChangeTracker.Entries<WorkflowStageState>()
            .Where(entry => entry.State == EntityState.Added)
            .ToList())
        {
            entry.State = EntityState.Detached;
        }

        var run = await dbContext.WorkflowRuns
            .AsNoTracking()
            .Include(item => item.ChecklistItemStates)
            .Include(item => item.StageStates)
            .Where(item => item.IsCurrent)
            .OrderByDescending(item => item.CreatedAt)
            .FirstOrDefaultAsync(cancellationToken);

        return run is not null
            ? CreateSnapshot(run)
            : throw new InvalidOperationException(
                "Workflow stage states were initialized concurrently but the current workflow run could not be loaded.",
                exception);
    }

    private static void EnsureStageStates(
        WorkflowRun run,
        ClaimsPrincipal user,
        DateTimeOffset now)
    {
        var states = run.StageStates
            .ToDictionary(state => state.StageId, StringComparer.OrdinalIgnoreCase);

        foreach (var definition in WorkflowStages.All)
        {
            if (states.ContainsKey(definition.Id))
            {
                continue;
            }

            var state = new WorkflowStageState
            {
                StageId = definition.Id,
                WorkflowRun = run,
                WorkflowRunId = run.Id,
            };
            run.StageStates.Add(state);
            states[definition.Id] = state;
        }

        var anyStarted = run.StageStates.Any(state => state.Status != WorkflowStageStatus.NotStarted);
        if (!anyStarted)
        {
            StartStage(states[WorkflowStageIds.ProjectIdentification], user, now);
        }
    }

    private static WorkflowSnapshotResponse CreateSnapshot(WorkflowRun run)
    {
        var states = StatesByStageId(run);
        var stages = WorkflowStages.All
            .Select(definition =>
            {
                var state = states[definition.Id];
                var canAccess = state.Status == WorkflowStageStatus.Complete
                    || PreviousStagesComplete(states, definition.Number);

                return new WorkflowStageDto(
                    definition.Id,
                    definition.Number,
                    definition.Title,
                    definition.Description,
                    state.Status,
                    canAccess,
                    state.CompletedAt,
                    state.CompletedByName,
                    state.CompletedByEmail);
            })
            .ToList();

        var currentStageId = stages.FirstOrDefault(stage => stage.Status != WorkflowStageStatus.Complete)?.Id
            ?? WorkflowStageIds.FinalReports;

        return new WorkflowSnapshotResponse(
            run.Id,
            run.FiscalYear,
            run.CycleStart,
            run.CycleEnd,
            currentStageId,
            stages);
    }

    private static Dictionary<string, WorkflowStageState> StatesByStageId(WorkflowRun run) =>
        run.StageStates.ToDictionary(state => state.StageId, StringComparer.OrdinalIgnoreCase);

    private static bool PreviousStagesComplete(
        IReadOnlyDictionary<string, WorkflowStageState> states,
        int stageNumber) =>
        WorkflowStages.All
            .Where(stage => stage.Number < stageNumber)
            .All(stage => states[stage.Id].Status == WorkflowStageStatus.Complete);

    private static bool IsValidTransitionStatus(string status) =>
        status is WorkflowStageStatus.InProgress or WorkflowStageStatus.Complete;

    private static void StartStageIfNeeded(
        WorkflowStageState state,
        ClaimsPrincipal user,
        DateTimeOffset startedAt)
    {
        if (state.Status != WorkflowStageStatus.InProgress)
        {
            StartStage(state, user, startedAt);
        }
    }

    private static void StartStage(
        WorkflowStageState state,
        ClaimsPrincipal user,
        DateTimeOffset startedAt)
    {
        state.Status = WorkflowStageStatus.InProgress;
        state.StartedAt = startedAt;
        state.StartedByEntraId = user.GetEntraId();
        state.StartedByName = Truncate(user.FindFirst("name")?.Value ?? user.Identity?.Name, 200);
        state.StartedByEmail = Truncate(
            user.FindFirst("preferred_username")?.Value ?? user.FindFirst(ClaimTypes.Email)?.Value,
            320);
    }

    private static void CompleteStage(
        WorkflowStageState state,
        ClaimsPrincipal user,
        DateTimeOffset completedAt)
    {
        if (state.StartedAt is null)
        {
            StartStage(state, user, completedAt);
        }

        state.Status = WorkflowStageStatus.Complete;
        state.CompletedAt = completedAt;
        state.CompletedByEntraId = user.GetEntraId();
        state.CompletedByName = Truncate(user.FindFirst("name")?.Value ?? user.Identity?.Name, 200);
        state.CompletedByEmail = Truncate(
            user.FindFirst("preferred_username")?.Value ?? user.FindFirst(ClaimTypes.Email)?.Value,
            320);
    }

    private static void ClearDownstream(
        IReadOnlyDictionary<string, WorkflowStageState> states,
        int stageNumber)
    {
        foreach (var definition in WorkflowStages.All.Where(stage => stage.Number > stageNumber))
        {
            ClearStage(states[definition.Id]);
        }
    }

    private static void ClearStage(WorkflowStageState state)
    {
        state.Status = WorkflowStageStatus.NotStarted;
        state.StartedAt = null;
        state.StartedByEntraId = null;
        state.StartedByName = null;
        state.StartedByEmail = null;
        ClearCompleted(state);
    }

    private static void ClearCompleted(WorkflowStageState state)
    {
        state.CompletedAt = null;
        state.CompletedByEntraId = null;
        state.CompletedByName = null;
        state.CompletedByEmail = null;
    }

    private static void Touch(WorkflowRun run, ClaimsPrincipal user, DateTimeOffset updatedAt)
    {
        run.UpdatedAt = updatedAt;
        SetUpdatedBy(run, user);
    }

    private static void SetCreatedBy(WorkflowRun run, ClaimsPrincipal user)
    {
        run.CreatedByEntraId = user.GetEntraId();
        run.CreatedByName = Truncate(user.FindFirst("name")?.Value ?? user.Identity?.Name, 200);
        run.CreatedByEmail = Truncate(
            user.FindFirst("preferred_username")?.Value ?? user.FindFirst(ClaimTypes.Email)?.Value,
            320);
    }

    private static void SetUpdatedBy(WorkflowRun run, ClaimsPrincipal user)
    {
        run.UpdatedByEntraId = user.GetEntraId();
        run.UpdatedByName = Truncate(user.FindFirst("name")?.Value ?? user.Identity?.Name, 200);
        run.UpdatedByEmail = Truncate(
            user.FindFirst("preferred_username")?.Value ?? user.FindFirst(ClaimTypes.Email)?.Value,
            320);
    }

    private static string? Truncate(string? value, int maxLength)
    {
        if (string.IsNullOrEmpty(value) || value.Length <= maxLength)
        {
            return value;
        }

        return value[..maxLength];
    }

    private static bool IsSqlServerUniquenessViolation(DbUpdateException exception) =>
        exception.GetBaseException() is SqlException sqlException
        && sqlException.Errors.Cast<SqlError>().Any(error => error.Number is 2601 or 2627);
}
