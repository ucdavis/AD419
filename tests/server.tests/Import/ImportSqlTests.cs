using FluentAssertions;
using Server.Core.Import;

namespace Server.Tests.Import;

public class ImportSqlTests
{
    [Fact]
    public void PeriodNames_spans_year_boundaries_in_en_us()
    {
        ImportSql.PeriodNames(new DateOnly(2024, 11, 15), new DateOnly(2025, 2, 1))
            .Should().Equal("Nov-24", "Dec-24", "Jan-25", "Feb-25");
    }

    [Fact]
    public void QuoteList_doubles_embedded_quotes()
    {
        ImportSql.QuoteList(["ABC", "O'Neil"]).Should().Be("'ABC','O''Neil'");
    }

    [Fact]
    public void HoursInFederalFiscalYear_handles_leap_cycle()
    {
        ImportSql.HoursInFederalFiscalYear(2024).Should().Be(2096);
        ImportSql.HoursInFederalFiscalYear(2025).Should().Be(2088);
    }

    [Fact]
    public void BufferedWindow_extends_three_months_each_side()
    {
        ImportSql.BufferedWindow(new DateOnly(2024, 10, 1), new DateOnly(2025, 9, 30))
            .Should().Be((new DateOnly(2024, 7, 1), new DateOnly(2025, 12, 30)));
    }
}
