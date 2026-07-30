namespace Server.Core.Import;

public sealed class ImportStageProvider : IImportStageProvider
{
    private readonly ChartSegmentsImportService _chartSegments;
    private readonly AeTransactionsImportService _aeTransactions;
    private readonly UcPathTransactionsImportService _ucPathTransactions;
    private readonly ErnDescriptionBackfillService _ernDescriptions;
    private readonly SprocStageService _sprocs;

    public ImportStageProvider(
        ChartSegmentsImportService chartSegments,
        AeTransactionsImportService aeTransactions,
        UcPathTransactionsImportService ucPathTransactions,
        ErnDescriptionBackfillService ernDescriptions,
        SprocStageService sprocs)
    {
        _chartSegments = chartSegments;
        _aeTransactions = aeTransactions;
        _ucPathTransactions = ucPathTransactions;
        _ernDescriptions = ernDescriptions;
        _sprocs = sprocs;
    }

    public IReadOnlyList<string> StageNames => ImportStageNames.All;

    public IReadOnlyList<ImportStage> BuildStages(ImportRunContext context)
    {
        var stages = new List<ImportStage>();

        // Stage display names split FinancialDepartment into words; the service
        // keys stay the stored SegmentName form.
        var displayNames = new Dictionary<string, string> { ["FinancialDepartment"] = "Financial Department" };
        foreach (var (segmentName, _) in ChartSegmentsImportService.Segments)
        {
            var display = displayNames.GetValueOrDefault(segmentName, segmentName);
            stages.Add(ImportStage.FromRowCount(
                ImportStageNames.ChartSegmentsPrefix + display,
                ct => _chartSegments.ImportSegmentAsync(segmentName, ct)));
        }

        stages.Add(new ImportStage(ImportStageNames.BuildProjects, ct => _sprocs.BuildProjectsAsync(ct)));
        stages.Add(ImportStage.FromRowCount(ImportStageNames.AeTransactions,
            ct => _aeTransactions.ImportAsync(context.CycleStart, context.CycleEnd, ct)));
        stages.Add(ImportStage.FromRowCount(ImportStageNames.UcPathTransactions,
            ct => _ucPathTransactions.ImportAsync(context.CycleStart, context.CycleEnd, ct)));
        stages.Add(ImportStage.FromRowCount(ImportStageNames.SeedSegmentClassifications, SeedAsync));
        stages.Add(ImportStage.FromRowCount(ImportStageNames.ClassifyTransactions,
            ct => _sprocs.ClassifyTransactionsAsync(context.CycleStart, context.CycleEnd, ct)));

        return stages;

        async Task<int> SeedAsync(CancellationToken ct)
        {
            var seeded = await _sprocs.SeedSegmentClassificationsAsync(ct);
            await _ernDescriptions.BackfillAsync(ct);
            return seeded;
        }
    }
}
