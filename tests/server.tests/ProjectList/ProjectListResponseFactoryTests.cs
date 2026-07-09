using FluentAssertions;
using Server.Models;
using Server.Models.ProjectList;
using Server.ProjectList;

namespace Server.Tests.ProjectList;

public class ProjectListResponseFactoryTests
{
    [Fact]
    public void Create_counts_tabs_and_sfn_distribution_from_rows()
    {
        FiscalYearCycle.TryParse("FY26", out var cycle).Should().BeTrue();
        var rows = new[]
        {
            new ProjectListRowDto("CA-A-111-H", "1000001", "2025-1", "K1234", "Larkspur, S.", "ATM", "201", "Clean"),
            new ProjectListRowDto("CA-B-222-CG", "1000002", "2025-2", null, "Okonkwo, Y.", "ANS", "204", "SFN mismatch"),
            new ProjectListRowDto("CA-C-333-CG", "1000003", "2025-3", null, "Naidoo, T.", "VEN", "204", "No PGM match"),
        };

        var response = ProjectListResponseFactory.Create(cycle!, rows, 10, 20, 30, 40);

        response.FiscalYear.Should().Be("FY26");
        response.CycleStart.Should().Be(new DateOnly(2025, 10, 1));
        response.CycleEnd.Should().Be(new DateOnly(2026, 9, 30));
        response.Counts.Should().Be(new ProjectListCountsDto(2, 1, 3));
        response.Summary.ActiveNifa.Should().Be(10);
        response.Summary.AllNifa.Should().Be(20);
        response.Summary.PgmRecords.Should().Be(30);
        response.Summary.AlnCodes.Should().Be(40);
        response.Summary.IssuesToResolve.Should().Be(2);
        response.Summary.SfnDistribution.Should().Equal(
            new SfnDistributionDto("201", 1),
            new SfnDistributionDto("204", 2));
        response.Rows.Should().Equal(rows);
    }
}
