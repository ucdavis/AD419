using FluentAssertions;

namespace Server.Tests.ProjectList;

public class ProjectListSqlTests
{
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

    private static string ReadDatabaseFile(string relativePath) =>
        File.ReadAllText(Path.Combine(RepositoryRoot(), "database", relativePath));

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
