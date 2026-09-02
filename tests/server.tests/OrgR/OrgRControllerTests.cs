using FluentAssertions;
using Microsoft.AspNetCore.Mvc;
using Server.Controllers;
using Server.Core.Domain;
using Server.Models.OrgR;

namespace Server.Tests.OrgRReview;

public class OrgRControllerTests
{
    private static OrgRController CreateController(Server.Core.Data.DataDbContext db, FakeOrgRReviewSeeder? seeder = null) =>
        new(db, seeder ?? new FakeOrgRReviewSeeder());

    [Fact]
    public async Task GetOrgRs_returns_codes_with_reference_counts()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.OrgRs.AddRange(new OrgR { Code = "AARE", Description = "ARE" }, new OrgR { Code = "ADNO" });
        db.OrgRFinancialDepartments.Add(new OrgRFinancialDepartment { FinancialDepartment = "AARE001", OrgR = "AARE" });
        db.OrgRNifaDepartments.Add(new OrgRNifaDepartment { NifaDepartment = "ARE", OrgR = "AARE" });
        db.OrgRProjectAdditions.Add(new OrgRProjectAddition { AccessionNumber = "1000001", OrgR = "AARE" });
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.GetOrgRs(CancellationToken.None);

        var dtos = result.Result.Should().BeOfType<OkObjectResult>().Subject.Value
            .Should().BeAssignableTo<IEnumerable<OrgRDto>>().Subject.ToList();
        dtos.Should().HaveCount(2);
        dtos.Single(d => d.Code == "AARE").ReferenceCount.Should().Be(3);
        dtos.Single(d => d.Code == "ADNO").ReferenceCount.Should().Be(0);
    }

    [Fact]
    public async Task UpsertOrgR_creates_then_updates_and_normalizes_code()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        var controller = CreateController(db);

        var created = await controller.UpsertOrgR(" aare ", new UpsertOrgRRequest("Ag Econ"), CancellationToken.None);
        var updated = await controller.UpsertOrgR("AARE", new UpsertOrgRRequest("Ag and Resource Economics"), CancellationToken.None);

        created.Should().BeOfType<NoContentResult>();
        updated.Should().BeOfType<NoContentResult>();
        var row = db.OrgRs.Single();
        row.Code.Should().Be("AARE");
        row.Description.Should().Be("Ag and Resource Economics");
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("ELEVENCHARS")]
    [InlineData("BAD CODE")]
    public async Task UpsertOrgR_rejects_invalid_codes(string code)
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        var controller = CreateController(db);

        var result = await controller.UpsertOrgR(code, new UpsertOrgRRequest(null), CancellationToken.None);

        result.Should().BeOfType<BadRequestObjectResult>();
    }

    [Fact]
    public async Task DeleteOrgR_refuses_when_referenced()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.OrgRs.Add(new OrgR { Code = "AARE" });
        db.OrgRFinancialDepartments.Add(new OrgRFinancialDepartment { FinancialDepartment = "AARE001", OrgR = "AARE" });
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.DeleteOrgR("AARE", CancellationToken.None);

        var conflict = result.Should().BeOfType<ConflictObjectResult>().Subject;
        conflict.Value.Should().BeOfType<string>().Which.Should().Contain("1 mapping");
        db.OrgRs.Should().HaveCount(1);
    }

    [Fact]
    public async Task DeleteOrgR_removes_unreferenced_code()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.OrgRs.Add(new OrgR { Code = "AARE" });
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.DeleteOrgR("AARE", CancellationToken.None);

        result.Should().BeOfType<NoContentResult>();
        db.OrgRs.Should().BeEmpty();
    }

    [Fact]
    public async Task DeleteOrgR_returns_not_found_for_unknown_code()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        var controller = CreateController(db);

        var result = await controller.DeleteOrgR("NOPE", CancellationToken.None);

        result.Should().BeOfType<NotFoundResult>();
    }
}
