using FluentAssertions;
using Server.Core.Import;

namespace Server.Tests.Import;

public class ChartSegmentsImportServiceTests
{
    [Fact]
    public void Segments_cover_all_eight_erp_tables_in_stage_order()
    {
        ChartSegmentsImportService.Segments.Select(s => s.SourceTable).Should().Equal(
            "ae_dwh.erp_entity", "ae_dwh.erp_fund", "ae_dwh.erp_fin_dept", "ae_dwh.erp_account",
            "ae_dwh.erp_purpose", "ae_dwh.erp_program", "ae_dwh.erp_project", "ae_dwh.erp_activity");
        ChartSegmentsImportService.Segments.Select(s => s.SegmentName).Should().Equal(
            "Entity", "Fund", "FinancialDepartment", "Account",
            "Purpose", "Program", "Project", "Activity");
    }

    [Fact]
    public void BuildRemoteQuery_selects_a_segment_name_literal_from_the_source_table()
    {
        var query = ChartSegmentsImportService.BuildRemoteQuery("Fund", "ae_dwh.erp_fund");

        query.Should().Contain("CAST('Fund' AS VARCHAR(30)) AS segment_name");
        query.Should().Contain("FROM ae_dwh.erp_fund");
        query.Should().Contain("parent_level_5");
    }

    [Fact]
    public void BuildRemoteQuery_rejects_unknown_segment_names()
    {
        var act = () => ChartSegmentsImportService.BuildRemoteQuery("Robert'); DROP TABLE", "ae_dwh.erp_fund");
        act.Should().Throw<ArgumentException>();
    }
}
