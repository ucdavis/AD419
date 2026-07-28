using FluentAssertions;
using Server.Core.Import;

namespace Server.Tests.Import;

public class PgmProjectsImportServiceTests
{
    [Fact]
    public void BuildSourceCommandText_runs_a_parameterized_exec_at_against_redshift()
    {
        var command = PgmProjectsImportService.BuildSourceCommandText();

        command.Should().Contain("EXEC (@remoteQuery, @reportDate) AT [AE_Redshift_PROD]");
    }

    [Fact]
    public void BuildRemoteQuery_binds_the_report_date_as_a_placeholder_not_a_literal()
    {
        var query = PgmProjectsImportService.BuildRemoteQuery();

        // the date is a bound parameter (?), never concatenated in
        query.Should().Contain("CASE WHEN ? BETWEEN budget_start_date AND budget_end_date");
    }

    [Fact]
    public void BuildRemoteQuery_targets_the_warehouse_table()
    {
        var query = PgmProjectsImportService.BuildRemoteQuery();

        query.Should().Contain("ae_dwh.pgm_master_data");
    }

    [Fact]
    public void BuildRemoteQuery_excludes_null_project_ids()
    {
        var query = PgmProjectsImportService.BuildRemoteQuery();

        // null project_id otherwise collapses every unkeyed row into one junk bucket
        query.Should().Contain("project_id IS NOT NULL");
    }

    [Fact]
    public void BuildRemoteQuery_bounds_aggregates_so_msdasql_binds_them_inline()
    {
        var query = PgmProjectsImportService.BuildRemoteQuery();

        // unbounded LISTAGG is reported as a LOB, which EXEC ... AT cannot stream
        query.Should().Contain("CAST(LISTAGG(DISTINCT piperson, '; ') AS VARCHAR(255))");
        query.Should().NotContain("WITHIN GROUP");
    }

    [Fact]
    public void BuildAggregateLengthCheckCommandText_runs_a_parameterized_exec_at_against_redshift()
    {
        var command = PgmProjectsImportService.BuildAggregateLengthCheckCommandText();

        command.Should().Contain("EXEC (@remoteQuery) AT [AE_Redshift_PROD]");
    }

    [Fact]
    public void BuildAggregateLengthCheckQuery_returns_numeric_aggregate_length_telemetry()
    {
        var query = PgmProjectsImportService.BuildAggregateLengthCheckQuery();

        query.Should().Contain("SELECT project_id,");
        query.Should().Contain("LENGTH(LISTAGG(DISTINCT piperson, '; ')) AS pi_persons_length");
        query.Should().Contain("COALESCE(pi_persons_length, 0) AS pi_persons_length");
        query.Should().Contain("WHERE principal_investigator_names_length > 255");
        query.Should().Contain("OR pi_persons_length > 255");
        query.Should().NotContain("VARCHAR(8000)");
        query.Should().NotContain("WITHIN GROUP");
    }

    [Fact]
    public void BuildStoredAggregateLengthQuery_returns_destination_lengths_by_project()
    {
        var query = PgmProjectsImportService.BuildStoredAggregateLengthQuery();

        query.Should().Contain("SELECT ProjectId,");
        query.Should().Contain("COALESCE(DATALENGTH(PiPersons) / 2, 0) AS PiPersonsLength");
        query.Should().Contain("FROM [data].[PGMProjects]");
    }

    [Fact]
    public void BuildRemoteQuery_avoids_a_trailing_terminator_and_keeps_the_rn_filter()
    {
        var query = PgmProjectsImportService.BuildRemoteQuery();

        // a trailing statement terminator inside the pass-through breaks the ODBC call
        // (the ; inside the '; ' LISTAGG delimiters is fine; only a terminating ; is not)
        query.TrimEnd().Should().EndWith("WHERE r.rn = 1");
    }

    [Fact]
    public void BuildRemoteQuery_leaves_loaded_at_to_the_destination_default()
    {
        var query = PgmProjectsImportService.BuildRemoteQuery();

        // LoadedAt is a column default (SYSUTCDATETIME), not part of the remote result
        query.Should().NotContain("LoadedAt");
        query.Should().NotContain("SYSUTCDATETIME");
    }
}
