using FluentAssertions;
using Server.Models;

namespace Server.Tests.Models;

public class FiscalYearCycleTests
{
    [Theory]
    [InlineData("FY25", "FY25", 2024, 10, 1, 2025, 9, 30)]
    [InlineData("fy26", "FY26", 2025, 10, 1, 2026, 9, 30)]
    public void TryParse_maps_fiscal_year_to_cycle_dates(
        string input,
        string expectedFiscalYear,
        int startYear,
        int startMonth,
        int startDay,
        int endYear,
        int endMonth,
        int endDay)
    {
        var parsed = FiscalYearCycle.TryParse(input, out var cycle);

        parsed.Should().BeTrue();
        cycle.Should().NotBeNull();
        cycle!.FiscalYear.Should().Be(expectedFiscalYear);
        cycle.CycleStart.Should().Be(new DateOnly(startYear, startMonth, startDay));
        cycle.CycleEnd.Should().Be(new DateOnly(endYear, endMonth, endDay));
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("FY")]
    [InlineData("2027")]
    [InlineData("fall-2026")]
    public void TryParse_rejects_missing_or_invalid_values(string? input)
    {
        FiscalYearCycle.TryParse(input, out var cycle).Should().BeFalse();
        cycle.Should().BeNull();
    }
}
