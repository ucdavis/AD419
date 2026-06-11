using FluentAssertions;
using Server.Core.Import;

namespace Server.Tests.Import;

public class PgmProjectsImportServiceTests
{
    [Fact]
    public void BuildSourceQuery_splices_report_date_as_redshift_date_literal()
    {
        var query = PgmProjectsImportService.BuildSourceQuery(new DateOnly(2026, 6, 30));

        query.Should().Contain("DATE ''2026-06-30''");
    }

    [Fact]
    public void BuildSourceQuery_targets_the_redshift_linked_server()
    {
        var query = PgmProjectsImportService.BuildSourceQuery(new DateOnly(2026, 6, 30));

        query.Should().Contain("OPENQUERY(AE_Redshift_PROD,");
        query.Should().Contain("ae_dwh.pgm_master_data");
    }

    [Fact]
    public void BuildSourceQuery_avoids_redshift_openquery_pitfalls()
    {
        var query = PgmProjectsImportService.BuildSourceQuery(new DateOnly(2026, 6, 30));

        // Redshift rejects differing LISTAGG WITHIN GROUP orderings in one select
        query.Should().NotContain("WITHIN GROUP");

        // a statement terminator inside the OPENQUERY string breaks the ODBC pass-through
        query.Should().NotContain("1;");
        query.Should().Contain("WHERE r.rn = 1");
    }

    [Fact]
    public void BuildSourceQuery_adds_loaded_at_outside_the_pass_through_query()
    {
        var query = PgmProjectsImportService.BuildSourceQuery(new DateOnly(2026, 6, 30));

        query.Should().Contain("SYSUTCDATETIME() AS LoadedAt");
        query.IndexOf("SYSUTCDATETIME", StringComparison.Ordinal)
            .Should().BeLessThan(query.IndexOf("OPENQUERY", StringComparison.Ordinal));
    }
}
