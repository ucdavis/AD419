using System.Text.Json;
using FluentAssertions;
using Server.Assistant;
using UCDavis.CaesAi.AppSdk;

namespace Server.Tests.Assistant;

public class ExpenseReviewToolManifestTests
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    [Fact]
    public void Every_manifest_validates_against_protocol_v1()
    {
        foreach (var tool in ExpenseReviewToolManifest.Build())
        {
            var element = JsonSerializer.SerializeToElement(tool, Json);
            CaesAiProtocolJson.IsValid("applicationToolManifest", element)
                .Should().BeTrue($"{tool.Name} must be a valid manifest");
        }
    }

    [Fact]
    public void Tool_names_are_unique_and_read_only()
    {
        var tools = ExpenseReviewToolManifest.Build();

        tools.Select(tool => tool.Name).Should().OnlyHaveUniqueItems();
        tools.Should().OnlyContain(tool => tool.Risk == CaesAiToolRisk.Read && !tool.NeedsApproval);
        tools.Where(tool => tool.Execution == CaesAiToolExecution.Client)
            .Select(tool => tool.Name)
            .Should().BeEquivalentTo(ExpenseReviewToolManifest.GetView, ExpenseReviewToolManifest.SetFilters);
    }

    [Fact]
    public void Query_transactions_caps_page_size_at_100()
    {
        var tool = ExpenseReviewToolManifest.Build().Single(t => t.Name == ExpenseReviewToolManifest.QueryTransactions);

        tool.InputSchema["properties"]!["pageSize"]!["maximum"]!.GetValue<int>().Should().Be(100);
    }

    [Fact]
    public void Summarize_only_accepts_known_dimensions()
    {
        var tool = ExpenseReviewToolManifest.Build().Single(t => t.Name == ExpenseReviewToolManifest.Summarize);

        var allowed = tool.InputSchema["properties"]!["groupBy"]!["enum"]!.AsArray().Select(node => node!.GetValue<string>());
        allowed.Should().BeEquivalentTo(Server.Models.ExpenseReview.ExpenseReviewSummaryDimensions.All);
        tool.InputSchema["required"]!.AsArray().Select(node => node!.GetValue<string>()).Should().Contain("groupBy");
    }

    [Fact]
    public void Filter_options_is_hidden_from_the_conversation()
    {
        var tool = ExpenseReviewToolManifest.Build().Single(t => t.Name == ExpenseReviewToolManifest.FilterOptions);

        tool.Presentation.Should().NotBeNull();
        tool.Presentation!.Kind.Should().Be("expense-review-filter-options");
    }

    [Fact]
    public void Filter_options_splits_every_filter_into_listed_or_search_only()
    {
        ExpenseReviewToolManifest.ListedFilterNames
            .Concat(ExpenseReviewToolManifest.SearchOnlyFilterNames)
            .Should().BeEquivalentTo(ExpenseReviewToolManifest.FilterNames);
        ExpenseReviewToolManifest.ListedFilterNames
            .Should().NotIntersectWith(ExpenseReviewToolManifest.SearchOnlyFilterNames);
    }

    [Fact]
    public void Filter_options_lookup_accepts_any_filter_and_caps_limit_at_200()
    {
        var tool = ExpenseReviewToolManifest.Build().Single(t => t.Name == ExpenseReviewToolManifest.FilterOptions);

        var allowed = tool.InputSchema["properties"]!["filter"]!["enum"]!.AsArray().Select(node => node!.GetValue<string>());
        allowed.Should().BeEquivalentTo(ExpenseReviewToolManifest.FilterNames);
        tool.InputSchema["properties"]!["limit"]!["maximum"]!.GetValue<int>().Should().Be(200);
    }
}
