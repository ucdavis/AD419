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
        sql.Should().NotContain("GETDATE()");
    }

    [Fact]
    public void Project_list_function_reads_parameterized_nifa_projects_and_keeps_status_rules()
    {
        var sql = ReadDatabaseFile("data/Functions/ProjectListForCycle.sql");

        sql.Should().Contain("CREATE FUNCTION [data].[ProjectListForCycle]");
        sql.Should().Contain("FROM [data].[NifaProjectsForCycle](@CycleStart, @CycleEnd) nv");
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
    public void Project_list_service_uses_cycle_functions_for_validation_and_candidates()
    {
        var sql = File.ReadAllText(Path.Combine(
            RepositoryRoot(),
            "server",
            "ProjectList",
            "ProjectListService.cs"));

        sql.Should().Contain("[data].[GetProjectList]");
        sql.Should().Contain("CycleParameters(cycle)");
        sql.Should().Contain("FROM [data].[ProjectListForCycle](@cycleStart, @cycleEnd)");
        sql.Should().Contain("FROM [data].[NifaProjectsForCycle](@cycleStart, @cycleEnd) nv");
        sql.Should().NotContain("FROM [data].[v_ProjectList]");
        sql.Should().NotContain("FROM [data].[v_NifaProjects]");
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
