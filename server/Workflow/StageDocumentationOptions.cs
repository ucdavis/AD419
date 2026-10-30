namespace Server.Workflow;

public sealed class StageDocumentationOptions
{
    public Dictionary<string, StageDocumentationLink?> Stages { get; set; } = [];
}

public sealed record StageDocumentationLink(string Url = "", string EmbedUrl = "");

public sealed class StageDocumentationConfiguration
{
    public IReadOnlyDictionary<string, StageDocumentationLink> Stages { get; }

    public StageDocumentationConfiguration(
        Microsoft.Extensions.Options.IOptions<StageDocumentationOptions> options,
        ILogger<StageDocumentationConfiguration> logger)
    {
        var stages = new Dictionary<string, StageDocumentationLink>();
        foreach (var (stageId, link) in options.Value.Stages)
        {
            if (WorkflowStages.Find(stageId) == null || link == null ||
                !IsBoxUrl(link.Url) || !IsBoxUrl(link.EmbedUrl))
            {
                logger.LogWarning("Stage documentation for {StageId} is invalid and will be unavailable. Use HTTPS Box URLs for both Url and EmbedUrl.", stageId);
                continue;
            }
            stages[WorkflowStages.Find(stageId)!.Id] = link;
        }
        Stages = stages;
    }

    private static bool IsBoxUrl(string? value) =>
        Uri.TryCreate(value, UriKind.Absolute, out var uri) &&
        uri.Scheme == Uri.UriSchemeHttps &&
        string.IsNullOrEmpty(uri.UserInfo) &&
        (uri.Host.Equals("box.com", StringComparison.OrdinalIgnoreCase) ||
         uri.Host.EndsWith(".box.com", StringComparison.OrdinalIgnoreCase));
}
