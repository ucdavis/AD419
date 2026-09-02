using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Metadata;
using Server.Core.Data;
using Server.Core.Domain;

namespace Server.Tests.OrgR;

using OrgR = Server.Core.Domain.OrgR;

public class OrgRMappingTests
{
    [Fact]
    public async Task OrgR_entities_round_trip_through_data_context()
    {
        await using var db = TestDbContextFactory.CreateDataInMemory();
        db.OrgRs.Add(new OrgR { Code = "AARE", Description = "Ag and Resource Economics" });
        db.OrgRFinancialDepartments.Add(new OrgRFinancialDepartment { FinancialDepartment = "AARE001", OrgR = "AARE" });
        db.OrgRNifaDepartments.Add(new OrgRNifaDepartment { NifaDepartment = "ARE", OrgR = "AARE" });
        db.OrgRProjectAdditions.Add(new OrgRProjectAddition { AccessionNumber = "1000001", OrgR = "AARE" });
        db.Projects.Add(new Project { AccessionNumber = "1000001", NifaProjectNumber = "CA-D-ARE-2868-H", Title = "T", ProjectDirector = "D" });
        await db.SaveChangesAsync();

        (await db.OrgRs.SingleAsync()).Code.Should().Be("AARE");
        (await db.OrgRFinancialDepartments.SingleAsync()).OrgR.Should().Be("AARE");
        (await db.OrgRNifaDepartments.SingleAsync()).NifaDepartment.Should().Be("ARE");
        (await db.OrgRProjectAdditions.SingleAsync()).AccessionNumber.Should().Be("1000001");
        (await db.Projects.SingleAsync()).Id.Should().BePositive();
    }

    [Fact]
    public void Data_tables_are_excluded_from_migrations()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        var designTimeModel = db.GetService<IDesignTimeModel>();
        foreach (var name in new[] { "OrgRs", "OrgRFinancialDepartments", "OrgRNifaDepartments", "OrgRProjectAdditions", "Projects" })
        {
            var entity = designTimeModel.Model.GetEntityTypes().Single(e => e.GetTableName() == name);
            entity.GetSchema().Should().Be("data");
            entity.IsTableExcludedFromMigrations().Should().BeTrue();
        }
    }
}
