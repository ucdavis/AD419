using FluentAssertions;

namespace Server.Tests.OrgR;

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
