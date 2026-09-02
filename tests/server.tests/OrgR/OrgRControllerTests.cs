using FluentAssertions;
using Microsoft.AspNetCore.Mvc;
using Server.Controllers;
using Server.Core.Domain;
using Server.Models.OrgR;
using Server.Models.SegmentClassifications;

namespace Server.Tests.OrgRReview;

public class OrgRControllerTests
{
    private static OrgRController CreateController(Server.Core.Data.DataDbContext db, FakeOrgRReviewSeeder? seeder = null) =>
        new(db, seeder ?? new FakeOrgRReviewSeeder());

    [Fact]
    public async Task GetOrgRs_returns_department_project_and_reference_counts()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.OrgRs.AddRange(new OrgR { Code = "AARE" }, new OrgR { Code = "ADNO" }, new OrgR { Code = "APLS" });
        db.OrgRFinancialDepartments.AddRange(
            new OrgRFinancialDepartment { FinancialDepartment = "AARE001", OrgR = "AARE" },
            new OrgRFinancialDepartment { FinancialDepartment = "AARE002", OrgR = "AARE" });
        db.OrgRNifaDepartments.Add(new OrgRNifaDepartment { NifaDepartment = "ARE", OrgR = "AARE" });
        db.Projects.AddRange(
            new Project { AccessionNumber = "1000001", NifaProjectNumber = "CA-D-ARE-2868-H" },
            new Project { AccessionNumber = "1000001", NifaProjectNumber = "CA-D-ARE-2868-H" },
            new Project { AccessionNumber = "1000002", NifaProjectNumber = "CA-D-ARE-2778-CG" },
            new Project { AccessionNumber = "1000003", NifaProjectNumber = "CA-D-ESP-2880-H" });
        db.OrgRProjectAdditions.AddRange(
            new OrgRProjectAddition { AccessionNumber = "1000001", OrgR = "AARE" },
            new OrgRProjectAddition { AccessionNumber = "1000003", OrgR = "APLS" });
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.GetOrgRs(CancellationToken.None);

        var dtos = result.Result.Should().BeOfType<OkObjectResult>().Subject.Value
            .Should().BeAssignableTo<IEnumerable<OrgRDto>>().Subject.ToList();
        dtos.Should().HaveCount(3);
        var aare = dtos.Single(d => d.Code == "AARE");
        aare.FinancialDepartmentCount.Should().Be(2);
        aare.NifaProjectCount.Should().Be(2, "1000001 and 1000002 map through ARE; the manual addition of 1000001 does not double count");
        aare.ReferenceCount.Should().Be(4, "two departments, one NIFA department, one addition");
        var apls = dtos.Single(d => d.Code == "APLS");
        apls.FinancialDepartmentCount.Should().Be(0);
        apls.NifaProjectCount.Should().Be(1);
        apls.ReferenceCount.Should().Be(1);
        dtos.Single(d => d.Code == "ADNO").ReferenceCount.Should().Be(0);
    }

    [Fact]
    public async Task CreateOrgR_normalizes_code_and_is_idempotent()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        var controller = CreateController(db);

        var created = await controller.CreateOrgR(" aare ", CancellationToken.None);
        var again = await controller.CreateOrgR("AARE", CancellationToken.None);

        created.Should().BeOfType<NoContentResult>();
        again.Should().BeOfType<NoContentResult>();
        db.OrgRs.Single().Code.Should().Be("AARE");
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("ELEVENCHARS")]
    [InlineData("BAD CODE")]
    public async Task CreateOrgR_rejects_invalid_codes(string code)
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        var controller = CreateController(db);

        var result = await controller.CreateOrgR(code, CancellationToken.None);

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
    public async Task DeleteOrgR_refuses_to_delete_ADNO()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.OrgRs.Add(new OrgR { Code = "ADNO" });
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.DeleteOrgR("ADNO", CancellationToken.None);

        var conflict = result.Should().BeOfType<ConflictObjectResult>().Subject;
        conflict.Value.Should().BeOfType<string>().Which.Should()
            .Be("ADNO is required by the title code 1010 rule and cannot be deleted.");
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

    [Fact]
    public async Task GetFinancialDepartments_seeds_then_returns_in_cycle_rows_with_chart_segment_hierarchy()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.OrgRFinancialDepartments.AddRange(
            new OrgRFinancialDepartment { FinancialDepartment = "AARE001", OrgR = "AARE" },
            new OrgRFinancialDepartment { FinancialDepartment = "OLD0001", OrgR = null });
        db.SegmentClassifications.Add(new SegmentClassification { SegmentType = SegmentType.FinancialDepartment, Code = "AARE001", IncludeInReport = true });
        db.ChartSegments.AddRange(
            new ChartSegment { SegmentName = "FinancialDepartment", Code = "AARE001", Description = "AARE Ag and Resource Economics", ParentLevel0Code = "100000A", ParentLevel1Code = "100000B", ParentLevel2Code = "AAES00C" },
            new ChartSegment { SegmentName = "FinancialDepartment", Code = "100000A", Description = "UC Davis" },
            new ChartSegment { SegmentName = "FinancialDepartment", Code = "100000B", Description = "UC Davis Campus" },
            new ChartSegment { SegmentName = "FinancialDepartment", Code = "AAES00C", Description = "College of Agricultural and Environmental Sciences" },
            new ChartSegment { SegmentName = "Fund", Code = "AARE001", Description = "not a department" });
        await db.SaveChangesAsync();
        var seeder = new FakeOrgRReviewSeeder();
        var controller = CreateController(db, seeder);

        var result = await controller.GetFinancialDepartments(CancellationToken.None);

        seeder.Calls.Should().Be(1);
        var dtos = result.Result.Should().BeOfType<OkObjectResult>().Subject.Value
            .Should().BeAssignableTo<IEnumerable<OrgRFinancialDepartmentDto>>().Subject.ToList();
        var aare = dtos.Should().ContainSingle().Subject;
        aare.FinancialDepartment.Should().Be("AARE001");
        aare.OrgR.Should().Be("AARE");
        aare.Description.Should().Be("AARE Ag and Resource Economics");
        aare.Hierarchy.Should().Equal(
            new HierarchyLevelDto("A", "100000A", "UC Davis"),
            new HierarchyLevelDto("B", "100000B", "UC Davis Campus"),
            new HierarchyLevelDto("C", "AAES00C", "College of Agricultural and Environmental Sciences"));
    }

    [Fact]
    public async Task SetFinancialDepartmentOrgR_updates_and_clears()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.OrgRs.Add(new OrgR { Code = "AARE" });
        db.OrgRFinancialDepartments.Add(new OrgRFinancialDepartment { FinancialDepartment = "AARE001" });
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var set = await controller.SetFinancialDepartmentOrgR("AARE001", new SetOrgRRequest("aare"), CancellationToken.None);
        set.Should().BeOfType<NoContentResult>();
        db.OrgRFinancialDepartments.Single().OrgR.Should().Be("AARE");

        var cleared = await controller.SetFinancialDepartmentOrgR("AARE001", new SetOrgRRequest(null), CancellationToken.None);
        cleared.Should().BeOfType<NoContentResult>();
        db.OrgRFinancialDepartments.Single().OrgR.Should().BeNull();
    }

    [Fact]
    public async Task SetFinancialDepartmentOrgR_rejects_unknown_orgr_and_department()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.OrgRFinancialDepartments.Add(new OrgRFinancialDepartment { FinancialDepartment = "AARE001" });
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        (await controller.SetFinancialDepartmentOrgR("AARE001", new SetOrgRRequest("ZZZZ"), CancellationToken.None))
            .Should().BeOfType<BadRequestObjectResult>();
        (await controller.SetFinancialDepartmentOrgR("NOPE", new SetOrgRRequest(null), CancellationToken.None))
            .Should().BeOfType<NotFoundResult>();
    }

    [Fact]
    public async Task GetNifaDepartments_returns_project_counts()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.OrgRNifaDepartments.AddRange(
            new OrgRNifaDepartment { NifaDepartment = "ARE", OrgR = "AARE" },
            new OrgRNifaDepartment { NifaDepartment = "ESP", OrgR = null });
        db.Projects.AddRange(
            new Project { AccessionNumber = "1000001", NifaProjectNumber = "CA-D-ARE-2868-H" },
            // Projects is at NIFA x AE grain: a second row for the same
            // accession (e.g. a second AE project) must not double-count.
            new Project { AccessionNumber = "1000001", NifaProjectNumber = "CA-D-ARE-2868-H" },
            new Project { AccessionNumber = "1000002", NifaProjectNumber = "CA-D-ARE-2778-CG" },
            new Project { AccessionNumber = "1000003", NifaProjectNumber = "CA-D-ESP-2880-H" });
        await db.SaveChangesAsync();
        var seeder = new FakeOrgRReviewSeeder();
        var controller = CreateController(db, seeder);

        var result = await controller.GetNifaDepartments(CancellationToken.None);

        seeder.Calls.Should().Be(1);
        var dtos = result.Result.Should().BeOfType<OkObjectResult>().Subject.Value
            .Should().BeAssignableTo<IEnumerable<OrgRNifaDepartmentDto>>().Subject.ToList();
        dtos.Single(d => d.NifaDepartment == "ARE").ProjectCount.Should().Be(2);
        dtos.Single(d => d.NifaDepartment == "ESP").ProjectCount.Should().Be(1);
    }

    [Fact]
    public async Task SetNifaDepartmentOrgR_updates_mapping()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.OrgRs.Add(new OrgR { Code = "AARE" });
        db.OrgRNifaDepartments.Add(new OrgRNifaDepartment { NifaDepartment = "ARE" });
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.SetNifaDepartmentOrgR("ARE", new SetOrgRRequest("AARE"), CancellationToken.None);

        result.Should().BeOfType<NoContentResult>();
        db.OrgRNifaDepartments.Single().OrgR.Should().Be("AARE");
    }

    [Fact]
    public async Task GetProjects_returns_default_rows_from_nifa_mapping_plus_manual_rows()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.OrgRs.AddRange(new OrgR { Code = "AARE" }, new OrgR { Code = "APLS" });
        db.OrgRNifaDepartments.AddRange(
            new OrgRNifaDepartment { NifaDepartment = "ARE", OrgR = "AARE" },
            new OrgRNifaDepartment { NifaDepartment = "ESP", OrgR = null });
        db.Projects.AddRange(
            new Project { AccessionNumber = "1000001", NifaProjectNumber = "CA-D-ARE-2868-H", Title = "Water", ProjectDirector = "Doe" },
            new Project { AccessionNumber = "1000003", NifaProjectNumber = "CA-D-ESP-2880-H", Title = "Soil" });
        db.OrgRProjectAdditions.Add(new OrgRProjectAddition { AccessionNumber = "1000001", OrgR = "APLS" });
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.GetProjects(CancellationToken.None);

        var dtos = result.Result.Should().BeOfType<OkObjectResult>().Subject.Value
            .Should().BeAssignableTo<IEnumerable<ProjectOrgRDto>>().Subject.ToList();
        dtos.Should().HaveCount(2);
        dtos.Should().ContainSingle(d => d.AccessionNumber == "1000001" && d.OrgR == "AARE" && d.Source == "Default" && d.Title == "Water");
        dtos.Should().ContainSingle(d => d.AccessionNumber == "1000001" && d.OrgR == "APLS" && d.Source == "Manual");
    }

    [Fact]
    public async Task GetProjects_dedupes_default_rows_for_projects_at_nifa_x_ae_grain()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.OrgRNifaDepartments.Add(new OrgRNifaDepartment { NifaDepartment = "ARE", OrgR = "AARE" });
        // Projects is at NIFA x AE grain: this accession has two rows for the
        // same NifaProjectNumber (e.g. two AE projects). The Default rows
        // must still yield exactly one row for this OrgR.
        db.Projects.AddRange(
            new Project { AccessionNumber = "1000001", NifaProjectNumber = "CA-D-ARE-2868-H", Title = "Water" },
            new Project { AccessionNumber = "1000001", NifaProjectNumber = "CA-D-ARE-2868-H", Title = "Water AE" });
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.GetProjects(CancellationToken.None);

        var dtos = result.Result.Should().BeOfType<OkObjectResult>().Subject.Value
            .Should().BeAssignableTo<IEnumerable<ProjectOrgRDto>>().Subject.ToList();
        dtos.Should().ContainSingle(d => d.AccessionNumber == "1000001" && d.Source == "Default");
    }

    [Fact]
    public async Task AddProject_validates_and_rejects_duplicates()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.OrgRs.Add(new OrgR { Code = "APLS" });
        db.Projects.Add(new Project { AccessionNumber = "1000001", NifaProjectNumber = "CA-D-ARE-2868-H" });
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        (await controller.AddProject(new AddProjectOrgRRequest("1000001", "apls"), CancellationToken.None))
            .Should().BeOfType<NoContentResult>();
        db.OrgRProjectAdditions.Single().OrgR.Should().Be("APLS");

        (await controller.AddProject(new AddProjectOrgRRequest("1000001", "APLS"), CancellationToken.None))
            .Should().BeOfType<ConflictObjectResult>();
        (await controller.AddProject(new AddProjectOrgRRequest("9999999", "APLS"), CancellationToken.None))
            .Should().BeOfType<BadRequestObjectResult>();
        (await controller.AddProject(new AddProjectOrgRRequest("1000001", "ZZZZ"), CancellationToken.None))
            .Should().BeOfType<BadRequestObjectResult>();
    }

    [Fact]
    public async Task RemoveProject_deletes_manual_row_only()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.OrgRProjectAdditions.Add(new OrgRProjectAddition { AccessionNumber = "1000001", OrgR = "APLS" });
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        (await controller.RemoveProject("1000001", "APLS", CancellationToken.None)).Should().BeOfType<NoContentResult>();
        db.OrgRProjectAdditions.Should().BeEmpty();
        (await controller.RemoveProject("1000001", "APLS", CancellationToken.None)).Should().BeOfType<NotFoundResult>();
    }
}
