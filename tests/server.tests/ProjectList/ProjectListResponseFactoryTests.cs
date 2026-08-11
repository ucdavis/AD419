using FluentAssertions;
using Server.Models;
using Server.Models.ProjectList;
using Server.ProjectList;

namespace Server.Tests.ProjectList;

public class ProjectListResponseFactoryTests
{
    [Fact]
    public void Create_counts_tabs_and_sfn_distribution_from_reportable_rows()
    {
        if (!FiscalYearCycle.TryParse("FY26", out var cycle))
        {
            throw new InvalidOperationException("FY26 should parse.");
        }

        var rows = new[]
        {
            new ProjectListRowDto(
                "CA-A-111-H",
                "1000001",
                "2025-1",
                "K1234",
                false,
                null,
                "Larkspur, S.",
                "larkspur@example.edu",
                "10000001",
                "Larkspur, Sasha",
                "ATM",
                "201",
                "Clean"),
            new ProjectListRowDto(
                "CA-B-222-CG",
                "1000002",
                "2025-2",
                null,
                true,
                null,
                "Okonkwo, Y.",
                "okonkwo@example.edu",
                "10000002",
                "Okonkwo, Yara",
                "ANS",
                "204",
                "SFN mismatch"),
            new ProjectListRowDto(
                "CA-C-333-CG",
                "1000003",
                "2025-3",
                null,
                true,
                null,
                "Naidoo, T.",
                "naidoo@example.edu",
                "10000003",
                "Naidoo, Talia",
                "VEN",
                "204",
                "No PGM match"),
        };
        var excludedRows = new[]
        {
            new ProjectListRowDto(
                "CA-D-444-CG",
                "1000004",
                "2025-4",
                null,
                true,
                "Excluded from associations",
                "Singh, R.",
                "singh@example.edu",
                "10000004",
                "Singh, Riya",
                "PLS",
                "204",
                "Excluded"),
        };

        var response = ProjectListResponseFactory.Create(cycle, rows, excludedRows, 10, 20, 30, 40);

        response.FiscalYear.Should().Be("FY26");
        response.CycleStart.Should().Be(new DateOnly(2025, 10, 1));
        response.CycleEnd.Should().Be(new DateOnly(2026, 9, 30));
        response.Counts.Should().Be(new ProjectListCountsDto(2, 1, 3, 1));
        response.Summary.ActiveNifa.Should().Be(10);
        response.Summary.AllNifa.Should().Be(20);
        response.Summary.PgmRecords.Should().Be(30);
        response.Summary.AlnCodes.Should().Be(40);
        response.Summary.ExcludedNifa.Should().Be(1);
        response.Summary.IssuesToResolve.Should().Be(2);
        response.Summary.SfnDistribution.Should().Equal(
            new SfnDistributionDto("201", 1),
            new SfnDistributionDto("204", 2));
        response.Rows.Should().Equal(rows);
        response.ExcludedRows.Should().Equal(excludedRows);
    }
}
