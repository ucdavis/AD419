using FluentAssertions;
using Server.Core.Import;

namespace Server.Tests.Import;

public class UcPathTransactionsImportServiceTests
{
    private static readonly string[] Projects = ["K30V4ALIUR", "SP1A242572"];
    private static readonly string[] Bcbs = ["BEVE003", "BGEN003"];

    [Fact]
    public void BuildSalaryQuery_applies_the_2025_source_filter_with_204_arm()
    {
        var query = UcPathTransactionsImportService.BuildSalaryQuery(Projects, Bcbs, 2088);

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
    public void Queries_limit_accounting_period_to_1_through_13()
    {
        // a few source rows carry a year (e.g. 2025) in ACCOUNTING_PERIOD
        UcPathTransactionsImportService.BuildSalaryQuery(Projects, Bcbs, 2088)
            .Should().Contain("ACCOUNTING_PERIOD BETWEEN 1 AND 13");
        UcPathTransactionsImportService.BuildFringeQuery(Projects, Bcbs)
            .Should().Contain("ACCOUNTING_PERIOD BETWEEN 1 AND 13");
    }

    [Fact]
    public void BuildSalaryQuery_computes_fte_payrate_and_salary_marker_in_source_sql()
    {
        var query = UcPathTransactionsImportService.BuildSalaryQuery(Projects, Bcbs, 2096);

        query.Should().Contain("HOURS1 / 2096");    // CalculatedFte denominator
        query.Should().Contain("'S' AS fringe_benefit_salary_cd");
        query.Should().Contain("NULLIF(TRIM(POSITION_NBR), '') IS NOT NULL");
    }

    [Fact]
    public void BuildSalaryQuery_uses_the_verified_view_column_names()
    {
        var query = UcPathTransactionsImportService.BuildSalaryQuery(Projects, Bcbs, 2088);

        query.Should().Contain("JOURNAL_ID || '_' || JOURNAL_LINE || '_' || UC_ADDL_SEQ");
        query.Should().Contain("HOURS1 AS hours");
        query.Should().Contain("MONETARY_AMOUNT AS amount");
        // JOBCODE holds 6-char values like '003252'; the title code is the last 4
        query.Should().Contain("SUBSTR(JOBCODE, -4)");
        query.Should().Contain("UC_EARNCD_DESCR), '') AS ern_description");
        query.Should().Contain("UC_PCT_TOT_PAY AS paid_percent");
        query.Should().Contain("UC_DRV_EFT_PCT AS ern_derived_percent");
        query.Should().Contain("TO_CHAR(ACCOUNTING_PERIOD) AS period");
        // absent from both labor views
        query.Should().NotContain("FINANCE_DOC_TYPE_CD");
        query.Should().NotContain("RATE_TYPE_CD");
    }

    [Fact]
    public void BuildFringeQuery_marks_fringe_rows_with_placeholder_ern()
    {
        var query = UcPathTransactionsImportService.BuildFringeQuery(Projects, Bcbs);

        query.Should().Contain("FROM CAES_HCMODS.PS_UC_LL_FRNG_DTL_V");
        query.Should().Contain("'XXX' AS erncd");
        query.Should().Contain("'F' AS fringe_benefit_salary_cd");
        query.Should().Contain("0 AS calculated_fte");
    }

    [Fact]
    public void BuildFringeQuery_uses_the_verified_view_column_names()
    {
        var query = UcPathTransactionsImportService.BuildFringeQuery(Projects, Bcbs);

        query.Should().Contain("JOURNAL_ID || '_' || JOURNAL_LINE || '_' || UC_ADDL_SEQ");
        query.Should().Contain("MONETARY_AMOUNT AS amount");
        // the fringe view has no JOBCODE; enrichment backfills it
        query.Should().Contain("CAST(NULL AS VARCHAR2(24)) AS job_code");
        query.Should().Contain("CAST(NULL AS VARCHAR2(120)) AS ern_description");
        query.Should().NotContain("FINANCE_DOC_TYPE_CD");
        query.Should().NotContain("RATE_TYPE_CD");
    }

    [Fact]
    public void Queries_omit_the_204_arm_when_no_projects_exist()
    {
        UcPathTransactionsImportService.BuildSalaryQuery([], [], 2088).Should().NotContain("PROJECT_ID IN");
        UcPathTransactionsImportService.BuildFringeQuery([], []).Should().NotContain("PROJECT_ID IN");
    }

    [Fact]
    public void Queries_keep_bcbs_rows_only_on_13u02_or_204_projects()
    {
        // Matches the AE import and last year's step 7: BCBS department rows
        // are dropped unless the fund is 13U02 or the project is a 204 project.
        const string clause =
            "AND (TRIM(DEPTID_CF) NOT IN ('BEVE003','BGEN003') OR DEPTID_CF IS NULL OR FUND_CODE = '13U02' OR PROJECT_ID IN ('K30V4ALIUR','SP1A242572'))";

        UcPathTransactionsImportService.BuildSalaryQuery(Projects, Bcbs, 2088).Should().Contain(clause);
        UcPathTransactionsImportService.BuildFringeQuery(Projects, Bcbs).Should().Contain(clause);
    }

    [Fact]
    public void Queries_omit_the_bcbs_filter_when_no_bcbs_departments_exist()
    {
        UcPathTransactionsImportService.BuildSalaryQuery(Projects, [], 2088).Should().NotContain("DEPTID_CF) NOT IN");
        UcPathTransactionsImportService.BuildFringeQuery(Projects, []).Should().NotContain("DEPTID_CF) NOT IN");
    }

    [Fact]
    public void Bcbs_filter_has_no_204_arm_when_no_projects_exist()
    {
        UcPathTransactionsImportService.BuildSalaryQuery([], Bcbs, 2088)
            .Should().Contain("AND (TRIM(DEPTID_CF) NOT IN ('BEVE003','BGEN003') OR DEPTID_CF IS NULL OR FUND_CODE = '13U02')")
            .And.NotContain("PROJECT_ID IN");
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
