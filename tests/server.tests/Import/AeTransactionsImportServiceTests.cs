using FluentAssertions;
using Server.Core.Import;

namespace Server.Tests.Import;

public class AeTransactionsImportServiceTests
{
    private static readonly string[] Periods = ["Jul-24", "Aug-24"];
    private static readonly string[] Depts = ["APLS001", "AANS001"];
    private static readonly string[] Bcbs = ["BCBS001"];
    private static readonly string[] Projects = ["K30V4ALIUR"];

    [Fact]
    public void BuildRemoteQuery_filters_to_actuals_and_periods()
    {
        var query = AeTransactionsImportService.BuildRemoteQuery(Periods, Depts, Bcbs, Projects);

        query.Should().Contain("FROM ae_dwh.transactional_listing_report");
        query.Should().Contain("actual_flag = 'A'");
        query.Should().Contain("period_name IN ('Jul-24','Aug-24')");
    }

    [Fact]
    public void BuildRemoteQuery_casts_the_wide_net_with_dept_204_and_bcbs_arms()
    {
        var query = AeTransactionsImportService.BuildRemoteQuery(Periods, Depts, Bcbs, Projects);

        query.Should().Contain("financial_department IN ('APLS001','AANS001')");
        query.Should().Contain("project IN ('K30V4ALIUR')");
        query.Should().Contain("financial_department IN ('BCBS001') AND fund = '13U02'");
        // the wide net has no purpose, account, or activity filters (the segment
        // columns themselves appear in the select list, so assert on filter shapes)
        query.Should().NotContain("purpose NOT IN");
        query.Should().NotContain("account NOT LIKE");
        query.Should().NotContain("activity NOT IN");
    }

    [Fact]
    public void BuildRemoteQuery_omits_empty_optional_arms()
    {
        var query = AeTransactionsImportService.BuildRemoteQuery(Periods, Depts, [], []);

        query.Should().NotContain("13U02");
        query.Should().NotContain("project IN");
    }

    [Fact]
    public void BuildRemoteQuery_requires_departments()
    {
        var act = () => AeTransactionsImportService.BuildRemoteQuery(Periods, [], Bcbs, Projects);
        act.Should().Throw<InvalidOperationException>().WithMessage("*CAES/ANR department list is empty*");
    }
}
