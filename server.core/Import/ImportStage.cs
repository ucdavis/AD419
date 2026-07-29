namespace Server.Core.Import;

public sealed record ImportRunContext(int RunId, DateOnly CycleStart, DateOnly CycleEnd);

public sealed record ImportStage(string Name, Func<CancellationToken, Task<int>> ExecuteAsync);

public interface IImportStageProvider
{
    IReadOnlyList<string> StageNames { get; }

    IReadOnlyList<ImportStage> BuildStages(ImportRunContext context);
}

public static class ImportStageNames
{
    public const string ChartSegmentsPrefix = "ChartSegments: ";
    public const string BuildProjects = "Build projects";
    public const string AeTransactions = "AE transactions";
    public const string UcPathTransactions = "UCPath transactions";
    public const string SeedSegmentClassifications = "Seed segment classifications";
    public const string ClassifyTransactions = "Classify transactions";

    public static readonly IReadOnlyList<string> All =
    [
        ChartSegmentsPrefix + "Entity",
        ChartSegmentsPrefix + "Fund",
        ChartSegmentsPrefix + "Financial Department",
        ChartSegmentsPrefix + "Account",
        ChartSegmentsPrefix + "Purpose",
        ChartSegmentsPrefix + "Program",
        ChartSegmentsPrefix + "Project",
        ChartSegmentsPrefix + "Activity",
        BuildProjects,
        AeTransactions,
        UcPathTransactions,
        SeedSegmentClassifications,
        ClassifyTransactions,
    ];
}
