using FluentAssertions;

namespace Server.Tests.OrgRReview;

public class OrgRSqlTests
{
    [Fact]
    public void OrgR_tables_define_keys_and_foreign_keys()
    {
        ReadDatabaseFile("data/Tables/OrgRs.sql").Should()
            .Contain("CREATE TABLE [data].[OrgRs]")
            .And.Contain("[Code]        NVARCHAR(10)")
            .And.Contain("PRIMARY KEY CLUSTERED ([Code])");

        var fin = ReadDatabaseFile("data/Tables/OrgRFinancialDepartments.sql");
        fin.Should().Contain("CREATE TABLE [data].[OrgRFinancialDepartments]")
            .And.Contain("[FinancialDepartment] NVARCHAR(50)  NOT NULL")
            .And.Contain("[OrgR]                NVARCHAR(10)  NULL")
            .And.Contain("REFERENCES [data].[OrgRs] ([Code])");

        var nifa = ReadDatabaseFile("data/Tables/OrgRNifaDepartments.sql");
        nifa.Should().Contain("CREATE TABLE [data].[OrgRNifaDepartments]")
            .And.Contain("[NifaDepartment] NVARCHAR(3)  NOT NULL")
            .And.Contain("REFERENCES [data].[OrgRs] ([Code])");

        var adds = ReadDatabaseFile("data/Tables/OrgRProjectAdditions.sql");
        adds.Should().Contain("CREATE TABLE [data].[OrgRProjectAdditions]")
            .And.Contain("[AccessionNumber] NVARCHAR(7)  NOT NULL")
            .And.Contain("[OrgR]            NVARCHAR(10) NOT NULL")
            .And.Contain("PRIMARY KEY CLUSTERED ([AccessionNumber], [OrgR])");
    }

    [Fact]
    public void Post_deploy_seeds_the_ADNO_orgr()
    {
        var sql = ReadDatabaseFile("data/Scripts/Script.PostDeployment.sql");
        sql.Should().Contain("MERGE [data].[OrgRs] AS target");
        sql.Should().Contain("(N'ADNO', N'Associate Deans Office')");
    }

    [Fact]
    public void ProjXOrgR_view_unions_default_and_manual_rows()
    {
        var sql = ReadDatabaseFile("data/Views/v_ProjXOrgR.sql");
        sql.Should().Contain("CREATE VIEW [data].[v_ProjXOrgR]");
        sql.Should().Contain("SUBSTRING(p.[NifaProjectNumber], 6, 3)");
        sql.Should().Contain("SELECT DISTINCT");
        sql.Should().Contain("'Default' AS [Source]");
        sql.Should().Contain("'Manual' AS [Source]");
        sql.Should().Contain("[data].[OrgRProjectAdditions]");
        sql.Should().Contain("UNION ALL");
        sql.Should().NotContain("GETDATE()");
    }

    [Fact]
    public void TransactionOrgR_view_forces_title_code_1010_to_ADNO()
    {
        var sql = ReadDatabaseFile("data/Views/v_TransactionOrgR.sql");
        sql.Should().Contain("CREATE VIEW [data].[v_TransactionOrgR]");
        sql.Should().Contain("N'UCPath' AS [Source]");
        sql.Should().Contain("N'AE' AS [Source]");
        sql.Should().Contain("WHEN u.[JobCode] = '1010' THEN N'ADNO'");
        sql.Should().Contain("[data].[OrgRFinancialDepartments]");
        sql.Should().Contain("UNION ALL");
        sql.Should().ContainAll(
            "CAST(u.[LaborTransactionId] AS NVARCHAR(125)) AS [TransactionId]",
            "CAST(a.[Id] AS NVARCHAR(125)) AS [TransactionId]");
    }

    [Fact]
    public void Seed_sproc_inserts_missing_rows_only()
    {
        var sql = ReadDatabaseFile("data/StoredProcedures/SeedOrgRReviewRows.sql");
        sql.Should().Contain("CREATE PROCEDURE [data].[SeedOrgRReviewRows]");
        sql.Should().Contain("[SegmentType] = 'FinancialDepartment'");
        sql.Should().Contain("[IncludeInReport] = 1");
        sql.Should().Contain("SUBSTRING([NifaProjectNumber], 6, 3)");
        sql.Should().Contain("NOT EXISTS");
        sql.Should().NotContain("UPDATE ");
        sql.Should().NotContain("DELETE ");
    }

    internal static string ReadDatabaseFile(string relativePath) =>
        File.ReadAllText(Path.Combine(RepositoryRoot(), "database", relativePath));

    internal static string RepositoryRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "app.sln")))
        {
            directory = directory.Parent;
        }
        return directory?.FullName ?? throw new InvalidOperationException("Repository root not found.");
    }
}
