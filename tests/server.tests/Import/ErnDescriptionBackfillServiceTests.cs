using FluentAssertions;
using Server.Core.Import;

namespace Server.Tests.Import;

public class ErnDescriptionBackfillServiceTests
{
    [Fact]
    public void BuildDescriptionQuery_looks_up_the_given_codes_in_the_salary_view()
    {
        var query = ErnDescriptionBackfillService.BuildDescriptionQuery(["9PP", "P18"]);

        query.Should().Contain("SELECT DISTINCT ERNCD, UC_EARNCD_DESCR");
        query.Should().Contain("FROM CAES_HCMODS.PS_UC_LL_SAL_DTL_V");
        query.Should().Contain("ERNCD IN ('9PP','P18')");
    }
}
