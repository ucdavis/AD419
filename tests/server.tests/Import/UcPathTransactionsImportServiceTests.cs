using FluentAssertions;
using Server.Core.Import;

namespace Server.Tests.Import;

public class UcPathTransactionsImportServiceTests
{
    private static readonly string[] Projects = ["K30V4ALIUR", "SP1A242572"];

    [Fact]
    public void BuildSalaryQuery_applies_the_2025_source_filter_with_204_arm()
    {
        var query = UcPathTransactionsImportService.BuildSalaryQuery(Projects, 2088);

        query.Should().Contain("FROM CAES_HCMODS.PS_UC_LL_SAL_DTL_V");
        query.Should().Contain("BUSINESS_UNIT IN ('DVCMP','UCANR')");
        query.Should().Contain("OPERATING_UNIT IN ('3310','3110')");
        query.Should().Contain("DML_IND <> 'D'");
        query.Should().Contain("FUND_CODE = '13U02' OR CLASS_FLD IN ('44','45','78')");
        query.Should().Contain("PROJECT_ID IN ('K30V4ALIUR','SP1A242572')");
        // pay period end date is the window filter, bound as placeholders
        query.Should().Contain("PAY_END_DT BETWEEN ? AND ?");
    }

    [Fact]
    public void BuildSalaryQuery_computes_fte_payrate_and_salary_marker_in_source_sql()
    {
        var query = UcPathTransactionsImportService.BuildSalaryQuery(Projects, 2096);

        query.Should().Contain("/ 2096");           // CalculatedFte denominator
        query.Should().Contain("'S' AS fringe_benefit_salary_cd");
        query.Should().Contain("NULLIF(TRIM(POSITION_NBR), '') IS NOT NULL");
    }

    [Fact]
    public void BuildFringeQuery_marks_fringe_rows_with_placeholder_ern()
    {
        var query = UcPathTransactionsImportService.BuildFringeQuery(Projects);

        query.Should().Contain("FROM CAES_HCMODS.PS_UC_LL_FRNG_DTL_V");
        query.Should().Contain("'XXX' AS erncd");
        query.Should().Contain("'F' AS fringe_benefit_salary_cd");
        query.Should().Contain("0 AS calculated_fte");
    }

    [Fact]
    public void Queries_omit_the_204_arm_when_no_projects_exist()
    {
        UcPathTransactionsImportService.BuildSalaryQuery([], 2088).Should().NotContain("PROJECT_ID IN");
        UcPathTransactionsImportService.BuildFringeQuery([]).Should().NotContain("PROJECT_ID IN");
    }

    [Fact]
    public void BuildNamesQuery_prefers_the_names_view()
    {
        var query = UcPathTransactionsImportService.BuildNamesQuery();

        query.Should().Contain("CAES_HCMODS.UCD_PS_NAMES_V");
    }

    [Fact]
    public void BuildJobCodeQuery_filters_conversion_rows_and_bounds_effdt()
    {
        var query = UcPathTransactionsImportService.BuildJobCodeQuery();

        query.Should().Contain("CAES_HCMODS.PS_JOB_V");
        query.Should().Contain("JOBCODE <> 'CONV'");
        query.Should().Contain("EFFDT <= ?");
    }
}
