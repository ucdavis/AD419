using System.Security.Claims;
using System.Text.Json;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Server.Authorization;
using Server.Core.Data;
using Server.Core.Domain;
using Server.Core.Import;
using Server.Import;
using Server.Models;
using Server.Models.Imports;
using Server.Models.ProjectIdentification;
using Server.ProjectList;

namespace Server.ProjectIdentification;

public sealed class ProjectIdentificationService(
    AppDbContext dbContext,
    IFlatFileImportRegistry importRegistry,
    IProjectListService projectListService) : IProjectIdentificationService
{
    private const string FiscalPeriodItemId = "fiscal-period";
    private const string PgmItemId = "pgm-master-data";
    private const string ResolveIssuesItemId = "resolve-project-issues";
    private const string FinalizeProjectsItemId = "finalize-projects";

    private static readonly ChecklistItemDefinition[] ChecklistItems =
    [
        new(FiscalPeriodItemId, 1, "Confirm Fiscal Period", "Set the reporting cycle", "select"),
        new("all-projects", 2, "Upload All Projects List", "ANR - all NIFA projects across UC campuses", "upload"),
        new("active-projects", 3, "Upload Active Project List", "ANR - CAES projects required to report", "upload"),
        new("assistance-listing-numbers", 4, "Upload CFDA / ALN Data", "assistancelisting.usaspending.gov - updated weekly", "upload"),
        new(PgmItemId, 5, "Import PGM Master Data", "AE Redshift - ae_dwh.pgm_master_data", "import"),
        new(ResolveIssuesItemId, 6, "Resolve Project Issues", "Review flagged projects below", "review"),
        new(FinalizeProjectsItemId, 7, "Finalize Projects", "Locks project data, triggers full expense pull", "action"),
    ];

    private static readonly Dictionary<string, string> DatasetByItemId = new(StringComparer.OrdinalIgnoreCase)
    {
        ["all-projects"] = "all-projects",
        ["active-projects"] = "active-projects",
        ["assistance-listing-numbers"] = "assistance-listing-numbers",
    };

    public async Task<ProjectIdentificationSetupResponse> GetSetupAsync(
        ClaimsPrincipal user,
        CancellationToken cancellationToken)
    {
        var run = await GetOrCreateCurrentRunAsync(user, cancellationToken);
        var latestImports = await GetLatestImportsAsync(cancellationToken);

        return CreateSetupResponse(run, latestImports);
    }

    public async Task<ProjectIdentificationSetupResponse?> ConfirmFiscalPeriodAsync(
        string? fiscalYear,
        ClaimsPrincipal user,
        CancellationToken cancellationToken)
    {
        if (!FiscalYearCycle.TryParse(fiscalYear, out var cycle))
        {
            return null;
        }

        var run = await GetOrCreateCurrentRunAsync(user, cancellationToken);
        var now = DateTimeOffset.UtcNow;
        var changed = !string.Equals(run.FiscalYear, cycle.FiscalYear, StringComparison.OrdinalIgnoreCase);

        if (changed)
        {
            run.FiscalYear = cycle.FiscalYear;
            run.CycleStart = cycle.CycleStart;
            run.CycleEnd = cycle.CycleEnd;
            run.ChecklistItemStates.Clear();
        }

        Touch(run, user, now);
        var fiscalState = GetOrCreateState(run, FiscalPeriodItemId);
        CompleteState(fiscalState, user, now);

        await dbContext.SaveChangesAsync(cancellationToken);

        var latestImports = await GetLatestImportsAsync(cancellationToken);
        return CreateSetupResponse(run, latestImports);
    }

    public async Task<ProjectIdentificationSetupResponse?> SetChecklistItemCompletionAsync(
        string itemId,
        bool completed,
        ClaimsPrincipal user,
        CancellationToken cancellationToken)
    {
        var definition = FindDefinition(itemId);
        if (definition is null || definition.Id == FinalizeProjectsItemId)
        {
            return null;
        }

        var run = await GetOrCreateCurrentRunAsync(user, cancellationToken);
        var latestImports = await GetLatestImportsAsync(cancellationToken);
        var items = CreateChecklistItems(run, latestImports);
        var requestedItem = items.Single(item => item.Id == definition.Id);

        if (!completed)
        {
            ClearFrom(run, definition.Number);
            Touch(run, user, DateTimeOffset.UtcNow);
            await dbContext.SaveChangesAsync(cancellationToken);

            return CreateSetupResponse(run, latestImports);
        }

        var previousComplete = items
            .Where(item => item.Number < definition.Number)
            .All(item => item.Completed);

        if (!previousComplete || !requestedItem.Ready)
        {
            return null;
        }

        if (definition.Id == ResolveIssuesItemId
            && !await ProjectIssuesResolvedAsync(run, cancellationToken))
        {
            return null;
        }

        var now = DateTimeOffset.UtcNow;
        var state = GetOrCreateState(run, definition.Id);
        CompleteState(state, user, now);

        if (DatasetByItemId.TryGetValue(definition.Id, out var datasetId))
        {
            var latestImport = latestImports.GetValueOrDefault(datasetId);
            if (latestImport is null || !IsSucceeded(latestImport))
            {
                return null;
            }

            state.SourceImportLogId = latestImport.Id;
            state.SourceRows = latestImport.RowsImported;
            state.SourceCompletedAt = latestImport.ImportedAt;
            state.SourceKey = null;
        }
        else if (definition.Id == PgmItemId)
        {
            if (state.SourceRows is null || state.SourceCompletedAt is null)
            {
                return null;
            }
        }
        else
        {
            state.SourceImportLogId = null;
            state.SourceRows = null;
            state.SourceCompletedAt = null;
            state.SourceKey = null;
        }

        Touch(run, user, now);
        await dbContext.SaveChangesAsync(cancellationToken);

        latestImports = await GetLatestImportsAsync(cancellationToken);
        return CreateSetupResponse(run, latestImports);
    }

    public async Task<ProjectIdentificationSetupResponse?> FinalizeProjectsAsync(
        ClaimsPrincipal user,
        CancellationToken cancellationToken)
    {
        var run = await GetOrCreateCurrentRunAsync(user, cancellationToken);
        var latestImports = await GetLatestImportsAsync(cancellationToken);
        var items = CreateChecklistItems(run, latestImports);
        var finalizeItem = items.Single(item => item.Id == FinalizeProjectsItemId);

        var previousComplete = items
            .Where(item => item.Number < finalizeItem.Number)
            .All(item => item.Completed);

        if (!previousComplete || !finalizeItem.Ready)
        {
            return null;
        }

        if (!await ProjectIssuesResolvedAsync(run, cancellationToken))
        {
            return null;
        }

        var rowsBuilt = await projectListService.BuildProjectsAsync(cancellationToken);
        var now = DateTimeOffset.UtcNow;
        var state = GetOrCreateState(run, FinalizeProjectsItemId);
        CompleteState(state, user, now);
        state.SourceImportLogId = null;
        state.SourceKey = $"build-projects:{now:O}";
        state.SourceRows = rowsBuilt;
        state.SourceCompletedAt = now;

        Touch(run, user, now);
        await dbContext.SaveChangesAsync(cancellationToken);

        latestImports = await GetLatestImportsAsync(cancellationToken);
        return CreateSetupResponse(run, latestImports);
    }

    private async Task<bool> ProjectIssuesResolvedAsync(
        WorkflowRun run,
        CancellationToken cancellationToken)
    {
        if (!FiscalYearCycle.TryParse(run.FiscalYear, out var cycle))
        {
            return false;
        }

        var projectList = await projectListService.GetAsync(cycle, cancellationToken);
        return projectList.Summary.IssuesToResolve == 0;
    }

    public async Task RecordPgmImportAsync(
        PgmProjectsImportResult result,
        ClaimsPrincipal user,
        CancellationToken cancellationToken)
    {
        var run = await GetOrCreateCurrentRunAsync(user, cancellationToken);
        var now = DateTimeOffset.UtcNow;
        var state = GetOrCreateState(run, PgmItemId);

        state.CompletedAt = null;
        state.CompletedByEntraId = null;
        state.CompletedByName = null;
        state.CompletedByEmail = null;
        state.SourceImportLogId = null;
        state.SourceKey = $"pgm:{result.ReportDate:yyyy-MM-dd}:{now:O}";
        state.SourceRows = result.RowsImported;
        state.SourceCompletedAt = now;

        ClearAfter(run, ChecklistItems.Single(item => item.Id == PgmItemId).Number);
        Touch(run, user, now);
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private async Task<WorkflowRun> GetOrCreateCurrentRunAsync(
        ClaimsPrincipal user,
        CancellationToken cancellationToken)
    {
        var run = await GetCurrentRunAsync(cancellationToken);

        if (run is not null)
        {
            return run;
        }

        var cycle = CurrentFiscalYearCycle();
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
        catch (DbUpdateException ex) when (IsCurrentRunUniquenessViolation(ex))
        {
            dbContext.Entry(run).State = EntityState.Detached;
            return await GetCurrentRunAsync(cancellationToken)
                ?? throw new InvalidOperationException("A current workflow run already exists but could not be loaded.", ex);
        }
    }

    private Task<WorkflowRun?> GetCurrentRunAsync(CancellationToken cancellationToken) =>
        dbContext.WorkflowRuns
            .Include(item => item.ChecklistItemStates)
            .Where(item => item.IsCurrent)
            .OrderByDescending(item => item.CreatedAt)
            .FirstOrDefaultAsync(cancellationToken);

    private ProjectIdentificationSetupResponse CreateSetupResponse(
        WorkflowRun run,
        IReadOnlyDictionary<string, RecentImportResponse> latestImports)
    {
        var items = CreateChecklistItems(run, latestImports);
        var completedCount = items.Count(item => item.Completed);

        return new ProjectIdentificationSetupResponse(
            run.Id,
            run.FiscalYear,
            run.CycleStart,
            run.CycleEnd,
            CreateFiscalPeriodOptions(run.FiscalYear),
            completedCount,
            items.Count,
            items);
    }

    private static IReadOnlyList<FiscalPeriodOptionDto> CreateFiscalPeriodOptions(string selectedFiscalYear)
    {
        var current = CurrentFiscalYearCycle();
        var currentYear = ParseFiscalYearNumber(current.FiscalYear)
            ?? throw new InvalidOperationException($"Current fiscal year '{current.FiscalYear}' could not be parsed.");
        var selectedYear = ParseFiscalYearNumber(selectedFiscalYear) ?? currentYear;
        var years = new[] { currentYear - 1, currentYear, currentYear + 1, selectedYear }
            .Distinct()
            .Order()
            .ToList();

        return years
            .Select(year =>
            {
                var fiscalYear = $"FY{year % 100:00}";
                if (!FiscalYearCycle.TryParse(fiscalYear, out var cycle))
                {
                    throw new InvalidOperationException($"Fiscal year option '{fiscalYear}' could not be parsed.");
                }

                return new FiscalPeriodOptionDto(
                    cycle.FiscalYear,
                    cycle.CycleStart,
                    cycle.CycleEnd,
                    $"{cycle.FiscalYear.Replace("FY", "FY:")} - {FormatPeriod(cycle)}");
            })
            .ToList();
    }

    private List<ProjectChecklistItemDto> CreateChecklistItems(
        WorkflowRun run,
        IReadOnlyDictionary<string, RecentImportResponse> latestImports)
    {
        var states = run.ChecklistItemStates
            .ToDictionary(state => state.ItemId, StringComparer.OrdinalIgnoreCase);
        var completedByItemId = new Dictionary<string, bool>(StringComparer.OrdinalIgnoreCase);
        var response = new List<ProjectChecklistItemDto>();

        foreach (var definition in ChecklistItems)
        {
            states.TryGetValue(definition.Id, out var state);
            var previousComplete = ChecklistItems
                .Where(item => item.Number < definition.Number)
                .All(item => completedByItemId.GetValueOrDefault(item.Id));
            var ready = IsReady(definition, state, latestImports);
            var completed = IsEffectivelyComplete(definition, state, latestImports);
            var stale = IsStale(definition, state, latestImports, out var staleReason);
            var status = GetStatus(definition, previousComplete, ready, completed, stale);
            var latestImport = DatasetByItemId.TryGetValue(definition.Id, out var datasetId)
                ? latestImports.GetValueOrDefault(datasetId)
                : null;

            completedByItemId[definition.Id] = completed;
            response.Add(new ProjectChecklistItemDto(
                definition.Id,
                definition.Number,
                definition.Label,
                definition.Hint,
                definition.Kind,
                status,
                completed,
                ready,
                stale,
                staleReason,
                latestImport,
                state is null
                    ? null
                    : new ProjectChecklistSourceDto(
                        state.SourceImportLogId,
                        state.SourceKey,
                        state.SourceRows,
                        state.SourceCompletedAt)));
        }

        return response;
    }

    private static string GetStatus(
        ChecklistItemDefinition definition,
        bool previousComplete,
        bool ready,
        bool completed,
        bool stale)
    {
        if (completed)
        {
            return "done";
        }

        if (stale)
        {
            return "stale";
        }

        if (!previousComplete)
        {
            return "locked";
        }

        if (!ready || definition.Id == FiscalPeriodItemId)
        {
            return "active";
        }

        return "ready";
    }

    private static bool IsReady(
        ChecklistItemDefinition definition,
        WorkflowChecklistItemState? state,
        IReadOnlyDictionary<string, RecentImportResponse> latestImports)
    {
        if (definition.Id == FiscalPeriodItemId || definition.Id == ResolveIssuesItemId)
        {
            return true;
        }

        if (DatasetByItemId.TryGetValue(definition.Id, out var datasetId))
        {
            var latestImport = latestImports.GetValueOrDefault(datasetId);
            return latestImport is not null && IsSucceeded(latestImport);
        }

        return definition.Id switch
        {
            PgmItemId => state?.SourceRows is not null && state.SourceCompletedAt is not null,
            FinalizeProjectsItemId => true,
            _ => false,
        };
    }

    private static bool IsEffectivelyComplete(
        ChecklistItemDefinition definition,
        WorkflowChecklistItemState? state,
        IReadOnlyDictionary<string, RecentImportResponse> latestImports)
    {
        if (state?.CompletedAt is null)
        {
            return false;
        }

        if (DatasetByItemId.TryGetValue(definition.Id, out var datasetId))
        {
            var latestImport = latestImports.GetValueOrDefault(datasetId);
            return latestImport is not null
                && IsSucceeded(latestImport)
                && state.SourceImportLogId == latestImport.Id;
        }

        if (definition.Id == PgmItemId)
        {
            return state.SourceRows is not null && state.SourceCompletedAt is not null;
        }

        return true;
    }

    private static bool IsStale(
        ChecklistItemDefinition definition,
        WorkflowChecklistItemState? state,
        IReadOnlyDictionary<string, RecentImportResponse> latestImports,
        out string? reason)
    {
        reason = null;

        if (state?.CompletedAt is null || !DatasetByItemId.TryGetValue(definition.Id, out var datasetId))
        {
            return false;
        }

        var latestImport = latestImports.GetValueOrDefault(datasetId);
        if (latestImport is null)
        {
            reason = "The import used to complete this item is no longer available.";
            return true;
        }

        if (!IsSucceeded(latestImport))
        {
            reason = "The latest import attempt did not succeed.";
            return true;
        }

        if (state.SourceImportLogId != latestImport.Id)
        {
            reason = "A newer import has been uploaded since this item was marked done.";
            return true;
        }

        return false;
    }

    private async Task<IReadOnlyDictionary<string, RecentImportResponse>> GetLatestImportsAsync(
        CancellationToken cancellationToken)
    {
        var datasetIds = importRegistry.Datasets.Select(dataset => dataset.Id).ToList();
        var recentLogs = new List<ImportLog>();
        foreach (var datasetId in datasetIds)
        {
            var recentLog = await dbContext.ImportLogs
                .AsNoTracking()
                .Where(log => log.Dataset == datasetId)
                .OrderByDescending(log => log.CompletedAt)
                .ThenByDescending(log => log.Id)
                .FirstOrDefaultAsync(cancellationToken);

            if (recentLog is not null)
            {
                recentLogs.Add(recentLog);
            }
        }

        return recentLogs
            .ToDictionary(
                log => log.Dataset,
                log => new RecentImportResponse(
                    log.Id,
                    log.Dataset,
                    log.Filename,
                    log.Status,
                    log.AttemptedRows,
                    log.RowsImported,
                    log.CompletedAt,
                    log.UploadedByName,
                    log.UploadedByEmail,
                    DeserializeValidationStats(log.ErrorPayload)),
                StringComparer.OrdinalIgnoreCase);
    }

    private static ImportValidationStatsResponse? DeserializeValidationStats(string? errorPayload)
    {
        if (string.IsNullOrWhiteSpace(errorPayload))
        {
            return null;
        }

        try
        {
            var payload = JsonSerializer.Deserialize<ImportValidationHistoryReadModel>(errorPayload);
            if (payload is null)
            {
                return null;
            }

            return new ImportValidationStatsResponse(
                payload.RowCount,
                payload.RowsWithErrors,
                payload.ErrorCount,
                payload.FileErrors.Count);
        }
        catch (JsonException)
        {
            return null;
        }
    }

    private static WorkflowChecklistItemState GetOrCreateState(WorkflowRun run, string itemId)
    {
        var state = run.ChecklistItemStates.SingleOrDefault(item =>
            string.Equals(item.ItemId, itemId, StringComparison.OrdinalIgnoreCase));

        if (state is not null)
        {
            return state;
        }

        state = new WorkflowChecklistItemState
        {
            ItemId = itemId,
            WorkflowRun = run,
            WorkflowRunId = run.Id,
        };
        run.ChecklistItemStates.Add(state);
        return state;
    }

    private static void CompleteState(
        WorkflowChecklistItemState state,
        ClaimsPrincipal user,
        DateTimeOffset completedAt)
    {
        state.CompletedAt = completedAt;
        state.CompletedByEntraId = user.GetEntraId();
        state.CompletedByName = Truncate(user.FindFirst("name")?.Value ?? user.Identity?.Name, 200);
        state.CompletedByEmail = Truncate(
            user.FindFirst("preferred_username")?.Value ?? user.FindFirst(ClaimTypes.Email)?.Value,
            320);
    }

    private static void ClearFrom(WorkflowRun run, int number)
    {
        var itemIds = ChecklistItems
            .Where(item => item.Number >= number)
            .Select(item => item.Id)
            .ToHashSet(StringComparer.OrdinalIgnoreCase);

        run.ChecklistItemStates.RemoveAll(state => itemIds.Contains(state.ItemId));
    }

    private static void ClearAfter(WorkflowRun run, int number)
    {
        var itemIds = ChecklistItems
            .Where(item => item.Number > number)
            .Select(item => item.Id)
            .ToHashSet(StringComparer.OrdinalIgnoreCase);

        run.ChecklistItemStates.RemoveAll(state => itemIds.Contains(state.ItemId));
    }

    private static ChecklistItemDefinition? FindDefinition(string itemId) =>
        ChecklistItems.SingleOrDefault(item =>
            string.Equals(item.Id, itemId, StringComparison.OrdinalIgnoreCase));

    private static bool IsSucceeded(RecentImportResponse import) =>
        string.Equals(import.Status, "Succeeded", StringComparison.OrdinalIgnoreCase);

    private static FiscalYearCycle CurrentFiscalYearCycle()
    {
        var now = DateTimeOffset.Now;
        var calendarYear = now.Year;
        var fiscalYear = now.Month >= 10 ? calendarYear + 1 : calendarYear;
        var fiscalYearText = $"FY{fiscalYear % 100:00}";
        if (!FiscalYearCycle.TryParse(fiscalYearText, out var cycle))
        {
            throw new InvalidOperationException($"Current fiscal year '{fiscalYearText}' could not be parsed.");
        }

        return cycle;
    }

    private static bool IsCurrentRunUniquenessViolation(DbUpdateException exception) =>
        exception.GetBaseException() is SqlException sqlException
        && sqlException.Errors.Cast<SqlError>().Any(error => error.Number is 2601 or 2627);

    private static int? ParseFiscalYearNumber(string fiscalYear)
    {
        var normalized = fiscalYear.Replace("FY:", "FY", StringComparison.OrdinalIgnoreCase);
        if (normalized.StartsWith("FY", StringComparison.OrdinalIgnoreCase)
            && int.TryParse(normalized[2..], out var year))
        {
            return 2000 + year;
        }

        return null;
    }

    private static string FormatPeriod(FiscalYearCycle cycle) =>
        $"{cycle.CycleStart:MMM yyyy} - {cycle.CycleEnd:MMM yyyy}";

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

    private sealed record ChecklistItemDefinition(
        string Id,
        int Number,
        string Label,
        string Hint,
        string Kind);

    private sealed class ImportValidationHistoryReadModel
    {
        public int RowCount { get; set; }
        public int RowsWithErrors { get; set; }
        public int ErrorCount { get; set; }
        public List<ImportFileError> FileErrors { get; set; } = [];
    }
}
