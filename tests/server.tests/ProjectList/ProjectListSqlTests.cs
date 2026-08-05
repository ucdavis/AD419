using FluentAssertions;

namespace Server.Tests.ProjectList;

public class ProjectListSqlTests
{
    [Fact]
    public void Nifa_projects_function_uses_cycle_parameters_instead_of_server_date()
    {
        var sql = ReadDatabaseFile("data/Functions/NifaProjectsForCycle.sql");

        sql.Should().Contain("CREATE FUNCTION [data].[NifaProjectsForCycle]");
        sql.Should().Contain("@CycleStart DATE");
        sql.Should().Contain("@CycleEnd DATE");
        sql.Should().Contain("x.ProjectEndDate >= @CycleStart");
        sql.Should().Contain("x.ProjectStartDate <= @CycleEnd");
        sql.Should().Contain("x.ProjectNumber = a.ProjectNumber");
        sql.Should().Contain("x.AccessionNumber = a.AccessionNumber");
        sql.Should().NotContain("ProjectNumberNormalized");
        sql.Should().NotContain("AccessionNumberNormalized");
        sql.Should().NotContain("GETDATE()");
    }

    [Fact]
    public void Project_list_function_reads_parameterized_nifa_projects_and_keeps_status_rules()
    {
        var sql = ReadDatabaseFile("data/Functions/ProjectListForCycle.sql");

        sql.Should().Contain("CREATE FUNCTION [data].[ProjectListForCycle]");
        sql.Should().Contain("FROM [data].[NifaProjectsForCycle](@CycleStart, @CycleEnd) nv");
        CountOccurrences(sql, "FROM [data].[v_PgmProjectSfnBuckets] pc").Should().Be(1);
        sql.Should().Contain("'Not in All Projects'");
        sql.Should().Contain("'No PGM match'");
        sql.Should().Contain("'SFN mismatch'");
        sql.Should().NotContain("[data].[v_NifaProjects]");
        sql.Should().NotContain("GETDATE()");
    }

    [Fact]
    public void Database_sql_files_do_not_use_getdate()
    {
        var databaseRoot = Path.Combine(RepositoryRoot(), "database", "data");
        var files = Directory.EnumerateFiles(databaseRoot, "*.sql", SearchOption.AllDirectories);

        foreach (var file in files)
        {
            var relativePath = Path.GetRelativePath(RepositoryRoot(), file);
            var sql = File.ReadAllText(file);

            sql.Should().NotContain(
                "GETDATE()",
                $"database SQL file {relativePath} should not depend on the server date");
        }
    }

    [Fact]
    public void Get_project_list_procedure_requires_cycle_dates()
    {
        var sql = ReadDatabaseFile("data/StoredProcedures/GetProjectList.sql");

        sql.Should().Contain("@CycleStart DATE");
        sql.Should().Contain("@CycleEnd DATE");
        sql.Should().Contain("FROM [data].[ProjectListForCycle](@CycleStart, @CycleEnd)");
        sql.Should().NotContain("[data].[v_ProjectList]");
    }

    [Fact]
    public void Build_projects_procedure_requires_cycle_dates_and_uses_cycle_functions()
    {
        var sql = ReadDatabaseFile("data/StoredProcedures/BuildProjects.sql");

        sql.Should().Contain("@CycleStart DATE");
        sql.Should().Contain("@CycleEnd DATE");
        sql.Should().Contain("FROM [data].[ProjectListForCycle](@CycleStart, @CycleEnd)");
        sql.Should().Contain("FROM [data].[NifaProjectsForCycle](@CycleStart, @CycleEnd) nv");
        sql.Should().NotContain("[data].[v_ProjectList]");
        sql.Should().NotContain("[data].[v_NifaProjects]");
    }

    [Fact]
    public void Project_list_tables_store_imported_lookup_keys_without_computed_cleanup()
    {
        var activeProjectsSql = ReadDatabaseFile("data/Tables/ActiveProjects.sql");
        var allProjectsSql = ReadDatabaseFile("data/Tables/AllProjects.sql");
        var pgmProjectsSql = ReadDatabaseFile("data/Tables/PGMProjects.sql");
        var pgmBucketSql = ReadDatabaseFile("data/Views/v_PgmProjectSfnBuckets.sql");
        var sfnSql = ReadDatabaseFile("data/Tables/Sfns.sql");

        activeProjectsSql.Should().Contain("[FK_ActiveProjects_Sfns_SfnOverride]");
        activeProjectsSql.Should().Contain("[CK_ActiveProjects_PgmAwardKeyOverride_NotBlank]");
        activeProjectsSql.Should().NotContain("LTRIM");
        activeProjectsSql.Should().NotContain("RTRIM");
        activeProjectsSql.Should().NotContain("PgmAwardKeyOverrideNormalized");
        allProjectsSql.Should().Contain("[AwardKey] NVARCHAR(16) NULL");
        allProjectsSql.Should().NotContain(" AS CONVERT");
        allProjectsSql.Should().NotContain("ProjectNumberNormalized");
        allProjectsSql.Should().NotContain("AccessionNumberNormalized");
        pgmProjectsSql.Should().Contain("[SponsorAwardKey] NVARCHAR(100) NULL");
        pgmProjectsSql.Should().Contain("[CfdaProgramNumber] NVARCHAR(200) NULL");
        pgmProjectsSql.Should().NotContain(" AS (");
        pgmProjectsSql.Should().NotContain("LTRIM");
        pgmBucketSql.Should().Contain("pgm.SponsorAwardKey AS AwardKey");
        pgmBucketSql.Should().Contain("pgm.CfdaProgramNumber");
        pgmBucketSql.Should().NotContain("REPLACE(pgm.SponsorAwardNumber");
        sfnSql.Should().Contain("CREATE TABLE [data].[Sfns]");
        sfnSql.Should().Contain("[Sfn] NVARCHAR(10) NOT NULL");
        sfnSql.Should().Contain("[Label] NVARCHAR(100) NOT NULL");
    }

    [Fact]
    public void Project_list_matching_columns_have_supporting_indexes()
    {
        var allProjectsIndexSql = ReadDatabaseFile("data/Indexes/IX_AllProjects_ProjectAccession_Cycle.sql");
        var pgmProjectsIndexSql = ReadDatabaseFile("data/Indexes/IX_PGMProjects_SponsorAwardKey.sql");

        allProjectsIndexSql.Should().Contain("([ProjectNumber], [AccessionNumber], [ProjectEndDate], [ProjectStartDate])");
        allProjectsIndexSql.Should().NotContain("Normalized");
        pgmProjectsIndexSql.Should().Contain("ON [data].[PGMProjects] ([SponsorAwardKey])");
    }

    [Fact]
    public void Project_list_service_uses_cycle_functions_for_validation_and_candidates()
    {
        var source = ReadServerFile("ProjectList/ProjectListService.cs");

        source.Should().Contain("[data].[GetProjectList]");
        source.Should().Contain("CycleParameters(cycle)");
        source.Should().Contain("FROM [data].[ProjectListForCycle](@cycleStart, @cycleEnd)");
        source.Should().Contain("FROM [data].[NifaProjectsForCycle](@cycleStart, @cycleEnd) nv");
        source.Should().NotContain("FROM [data].[v_ProjectList]");
        source.Should().NotContain("FROM [data].[v_NifaProjects]");
    }

    [Fact]
    public void Pgm_award_candidates_materialize_query_only_sort_rank_in_private_row()
    {
        var source = ReadServerFile("ProjectList/ProjectListService.cs");

        source.Should().Contain("AS [SortRank]");
        source.Should().Contain("QueryAsync<PgmAwardCandidateRow>");
        source.Should().Contain("int SortRank");
        source.Should().NotContain("QueryAsync<PgmAwardCandidateDto>");
    }

    private static string ReadDatabaseFile(string relativePath) =>
        File.ReadAllText(Path.Combine(RepositoryRoot(), "database", relativePath));

    private static string ReadServerFile(string relativePath) =>
        File.ReadAllText(Path.Combine(RepositoryRoot(), "server", relativePath));

    private static int CountOccurrences(string value, string expected)
    {
        var count = 0;
        var index = 0;

        while ((index = value.IndexOf(expected, index, StringComparison.Ordinal)) >= 0)
        {
            count++;
            index += expected.Length;
        }

        return count;
    }

    private static string RepositoryRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "app.sln")))
        {
            directory = directory.Parent;
        }

        directory.Should().NotBeNull("the test run should be inside the AD419 repository");
        return directory!.FullName;
    }
}
