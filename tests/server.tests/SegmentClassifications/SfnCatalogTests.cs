using FluentAssertions;
using Server.Models.SegmentClassifications;

namespace Server.Tests.SegmentClassifications;

public class SfnCatalogTests
{
    [Fact]
    public void Catalog_contains_the_eleven_sfn_codes_in_order()
    {
        SfnCatalog.Entries.Select(e => e.Code).Should().Equal(
            "201", "202", "203", "204", "205", "209", "219", "220", "221", "222", "223");
    }

    [Fact]
    public void Descriptions_are_trimmed_and_nonempty()
    {
        SfnCatalog.Entries.Should().OnlyContain(e =>
            e.Description == e.Description.Trim() && e.Description.Length > 0);
    }

    [Fact]
    public void FundSfns_validation_is_catalog_backed()
    {
        FundSfns.IsValidForInclusion("204").Should().BeTrue();
        FundSfns.IsValidForInclusion("222").Should().BeTrue();
        FundSfns.IsValidForInclusion("Multiple").Should().BeTrue();
        FundSfns.IsValidForInclusion("999").Should().BeFalse();
        FundSfns.IsValidForInclusion(null).Should().BeFalse();
    }
}
