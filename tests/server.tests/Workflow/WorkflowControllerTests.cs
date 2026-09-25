using FluentAssertions;
using Microsoft.AspNetCore.Mvc;
using Server.AutoAssociations;
using Server.Controllers;
using Server.Core.Domain;
using Server.Models.Workflow;
using Server.Tests.AutoAssociations;
using Server.Tests.OrgRReview;
using Server.Workflow;
using System.Security.Claims;

namespace Server.Tests.Workflow;

public class WorkflowControllerTests
{
    private static readonly ClaimsPrincipal User = new(new ClaimsIdentity(
        [
            new Claim("oid", "22222222-2222-2222-2222-222222222222"),
            new Claim("name", "Shannon Taylor"),
            new Claim("preferred_username", "shannon@example.edu"),
        ],
        "Test"));

    [Fact]
    public async Task Completing_orgr_review_returns_conflict_with_the_build_message_when_the_build_is_rejected()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        await using var dataDb = TestDbContextFactory.CreateDataInMemory();
        var builder = new FakeAutoAssociationBuilder
        {
            BuildFailure = new AutoAssociationBuildException("An included transaction has no OrgR; complete the OrgR Review mappings first.", new InvalidOperationException()),
        };
        var service = new WorkflowService(db, dataDb, new FakeOrgRReviewSeeder(), builder);
        foreach (var stage in WorkflowStages.All.Where(stage => stage.IsRequired && stage.Number < 6))
        {
            await service.SetStageStatusAsync(stage.Id, WorkflowStageStatus.Complete, User, CancellationToken.None);
        }
        var controller = new WorkflowController(service);
        controller.ControllerContext = new ControllerContext { HttpContext = new Microsoft.AspNetCore.Http.DefaultHttpContext { User = User } };

        var result = await controller.SetStageStatus(
            WorkflowStageIds.OrgRReview,
            new UpdateWorkflowStageRequest(WorkflowStageStatus.Complete),
            CancellationToken.None);

        var conflict = result.Result.Should().BeOfType<ConflictObjectResult>().Subject;
        conflict.Value.Should().Be("An included transaction has no OrgR; complete the OrgR Review mappings first.");
    }
}
