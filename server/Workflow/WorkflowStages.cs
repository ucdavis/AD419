namespace Server.Workflow;

public static class WorkflowStageIds
{
    public const string ProjectIdentification = "project-identification";
    public const string DataImport = "data-import";
    public const string DataClassification = "data-classification";
    public const string ExpenseReview = "expense-review";
    public const string AutoAssociations = "auto-associations";
    public const string ManualAssociations = "manual-associations";
    public const string PostAssociationReview = "post-association-review";
    public const string FinalReports = "final-reports";
}

public sealed record WorkflowStageDefinition(
    string Id,
    int Number,
    string Title,
    string Description);

public static class WorkflowStages
{
    public static readonly IReadOnlyList<WorkflowStageDefinition> All =
    [
        new(
            WorkflowStageIds.ProjectIdentification,
            1,
            "Project Identification",
            "Load the NIFA project list and resolve any data issues before pulling expenses."),
        new(
            WorkflowStageIds.DataImport,
            2,
            "Data Import",
            "Pull AE and UCPath transactions for the cycle and seed new chart-string segments for classification."),
        new(
            WorkflowStageIds.DataClassification,
            3,
            "Data Classification",
            "Classify new chart-string segments before they can be included in the AD419 report."),
        new(
            WorkflowStageIds.ExpenseReview,
            4,
            "Expense Review",
            "Confirm the right transactions are included before triggering auto-associations."),
        new(
            WorkflowStageIds.AutoAssociations,
            5,
            "Auto-Associations",
            "Run the rules engine to associate as many expenses as possible before manual review."),
        new(
            WorkflowStageIds.ManualAssociations,
            6,
            "Manual Associations",
            "Complete any associations that require manual review in AD419 Next."),
        new(
            WorkflowStageIds.PostAssociationReview,
            7,
            "Post-Association Review",
            "Resolve flagged items after manual associations are complete."),
        new(
            WorkflowStageIds.FinalReports,
            8,
            "Final Reports",
            "Generate the final files for ANR submission and cycle signoff."),
    ];

    public static WorkflowStageDefinition? Find(string stageId) =>
        All.SingleOrDefault(stage => string.Equals(stage.Id, stageId, StringComparison.OrdinalIgnoreCase));
}
