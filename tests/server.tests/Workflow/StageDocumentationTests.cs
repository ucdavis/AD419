using FluentAssertions;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Options;
using Server.Controllers;
using Server.Tests.Helpers;
using Server.Workflow;
using System.Text.Json;

namespace Server.Tests.Workflow;

public class StageDocumentationTests
{
    [Fact]
    public void Configuration_binds_existing_stage_ids_and_serializes_camel_case_links()
    {
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["StageDocumentation:Stages:expense-review:Url"] = "https://ucdavis.app.box.com/notes/123",
            ["StageDocumentation:Stages:expense-review:EmbedUrl"] = "https://ucdavis.box.com/embed/s/example",
        }).Build();
        var options = configuration.GetSection("StageDocumentation").Get<StageDocumentationOptions>()!;
        var documentation = new StageDocumentationConfiguration(Options.Create(options), new RecordingLogger<StageDocumentationConfiguration>());
        var controller = new WorkflowController(null!);
        var result = controller.Documentation(documentation).Result.Should().BeOfType<OkObjectResult>().Subject;
        var json = JsonSerializer.Serialize(result.Value, new JsonSerializerOptions(JsonSerializerDefaults.Web));
        json.Should().Contain("\"expense-review\":{\"url\":").And.Contain("\"embedUrl\":");
        documentation.Stages.Should().ContainSingle();
    }

    [Theory]
    [InlineData("Url")]
    [InlineData("EmbedUrl")]
    public void Partially_configured_entries_bind_without_breaking_other_stages(string field)
    {
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            [$"StageDocumentation:Stages:expense-review:{field}"] = "https://box.com/notes/123",
            ["StageDocumentation:Stages:data-import:Url"] = "https://box.com/notes/456",
            ["StageDocumentation:Stages:data-import:EmbedUrl"] = "https://box.com/embed/s/example",
        }).Build();
        var options = configuration.GetSection("StageDocumentation").Get<StageDocumentationOptions>()!;
        var logger = new RecordingLogger<StageDocumentationConfiguration>();
        var documentation = new StageDocumentationConfiguration(Options.Create(options), logger);
        documentation.Stages.Keys.Should().Equal("data-import");
        logger.Entries.Should().ContainSingle();
    }

    [Theory]
    [InlineData("http://box.com/note")]
    [InlineData("https://box.com.evil.example/note")]
    [InlineData("https://evilbox.com/note")]
    [InlineData("javascript:alert(1)")]
    [InlineData("not a url")]
    [InlineData("https://user@box.com/note")]
    [InlineData("")]
    public void Malformed_open_or_embed_links_are_omitted_and_warned(string invalid)
    {
        var options = new StageDocumentationOptions
        {
            Stages = new()
            {
                ["expense-review"] = new(invalid, "https://box.com/embed/s/example"),
                ["data-import"] = new("https://app.box.com/notes/123", invalid),
                ["unknown-stage"] = new("https://box.com/notes/123", "https://box.com/embed/s/example"),
                ["orgr-review"] = null,
            },
        };
        var logger = new RecordingLogger<StageDocumentationConfiguration>();
        var documentation = new StageDocumentationConfiguration(Options.Create(options), logger);
        documentation.Stages.Should().BeEmpty();
        logger.Entries.Should().HaveCount(4).And.OnlyContain(entry => entry.Level == Microsoft.Extensions.Logging.LogLevel.Warning);
    }

    [Fact]
    public void Missing_configuration_is_empty_and_endpoint_inherits_user_authorization()
    {
        var logger = new RecordingLogger<StageDocumentationConfiguration>();
        new StageDocumentationConfiguration(Options.Create(new StageDocumentationOptions()), logger).Stages.Should().BeEmpty();
        logger.Entries.Should().BeEmpty();
        typeof(WorkflowController).GetCustomAttributes(typeof(AuthorizeAttribute), true).Should().NotBeEmpty();
        typeof(WorkflowController).GetMethod(nameof(WorkflowController.Documentation))!
            .GetCustomAttributes(typeof(AllowAnonymousAttribute), true).Should().BeEmpty();
    }
}
