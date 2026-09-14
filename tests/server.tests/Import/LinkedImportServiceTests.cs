using System.Data;
using System.Data.Common;
using Dapper;
using FluentAssertions;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Server.Core.Import;
using Server.Tests.SqlIntegration;

namespace Server.Tests.Import;

[Trait("Category", "SqlIntegration")]
[Collection(SqlIntegrationCollection.Name)]
public sealed class LinkedImportServiceTests(SqlServerDataDbFixture fixture)
{
    [Fact]
    public async Task Pgm_import_replaces_destination_with_fake_linked_query_rows()
    {
        await fixture.ClearDataTablesAsync();
        await using var connection = await OpenConnectionAsync();
        await connection.ExecuteAsync("INSERT INTO [data].[PGMProjects] ([ProjectId]) VALUES (1);");

        var linkedServer = new FakeLinkedServerQueryExecutor(
            PgmProjectRows(),
            EmptyRows());
        await using var db = fixture.CreateDataDbContext();
        var service = new PgmProjectsImportService(
            db,
            Configuration(),
            NullLogger<PgmProjectsImportService>.Instance,
            linkedServer,
            new SqlBulkCopyWriter());

        var result = await service.ImportAsync(new DateOnly(2025, 6, 30), CancellationToken.None);

        result.RowsImported.Should().Be(1);
        var stored = await connection.QuerySingleAsync<(long ProjectId, string ProjectNumber, string SponsorAwardKey)>(
            "SELECT [ProjectId], [ProjectNumber], [SponsorAwardKey] FROM [data].[PGMProjects];");
        stored.Should().Be((9001, "AE-9001", "AWARD9001"));
        linkedServer.Calls.Should().HaveCount(2);
        linkedServer.Calls[0].CommandText.Should().Be(PgmProjectsImportService.BuildSourceCommandText());
        linkedServer.Calls[0].Parameters.Should().Contain(parameter =>
            parameter.Name == "@reportDate" &&
            parameter.Value.Equals(new DateOnly(2025, 6, 30)));
    }

    [Fact]
    public async Task Chart_segment_import_replaces_only_the_requested_segment()
    {
        await fixture.ClearDataTablesAsync();
        await using var connection = await OpenConnectionAsync();
        await connection.ExecuteAsync(
            """
            INSERT INTO [data].[ChartSegments] ([SegmentName], [Code], [Description])
            VALUES ('Fund', 'OLD', 'Old fund'), ('Entity', 'ENT1', 'Existing entity');
            """);

        var linkedServer = new FakeLinkedServerQueryExecutor(ChartSegmentRows());
        await using var db = fixture.CreateDataDbContext();
        var service = new ChartSegmentsImportService(
            db,
            Configuration(),
            NullLogger<ChartSegmentsImportService>.Instance,
            linkedServer,
            new SqlBulkCopyWriter());

        var rowsImported = await service.ImportSegmentAsync("Fund", CancellationToken.None);

        rowsImported.Should().Be(1);
        var rows = (await connection.QueryAsync<(string SegmentName, string Code, string? Description)>(
            "SELECT [SegmentName], [Code], [Description] FROM [data].[ChartSegments] ORDER BY [SegmentName], [Code];"))
            .ToList();
        rows.Should().BeEquivalentTo([
            ("Entity", "ENT1", "Existing entity"),
            ("Fund", "F1", "Seeded fund"),
        ]);
        linkedServer.Calls.Should().ContainSingle(call =>
            call.CommandText == $"EXEC (@remoteQuery) AT [{ChartSegmentsImportService.RemoteLinkedServer}];" &&
            call.Parameters.Any(parameter =>
                parameter.Name == "@remoteQuery" &&
                parameter.Value.ToString()!.Contains("FROM ae_dwh.erp_fund", StringComparison.Ordinal)));
    }

    [Fact]
    public async Task Ae_import_builds_remote_query_from_local_lookup_lists_and_bulk_copies_rows()
    {
        await fixture.ClearDataTablesAsync();
        await using var connection = await OpenConnectionAsync();
        await SeedAeImportLookupsAsync(connection);

        var linkedServer = new FakeLinkedServerQueryExecutor(AeTransactionRows());
        await using var db = fixture.CreateDataDbContext();
        var service = new AeTransactionsImportService(
            db,
            Configuration(),
            NullLogger<AeTransactionsImportService>.Instance,
            linkedServer,
            new SqlBulkCopyWriter());

        var rowsImported = await service.ImportAsync(new DateOnly(2024, 10, 1), new DateOnly(2025, 9, 30), CancellationToken.None);

        rowsImported.Should().Be(1);
        var row = await connection.QuerySingleAsync<(string Fund, string Department, string Project, decimal Amount)>(
            "SELECT [Fund], [FinancialDepartment], [Project], [Amount] FROM [data].[AETransactions];");
        row.Should().Be(("13U02", "D-CAES", "PR204", 42m));

        var remoteQuery = linkedServer.Calls.Should().ContainSingle().Subject
            .Parameters.Single(parameter => parameter.Name == "@remoteQuery")
            .Value.ToString();
        remoteQuery.Should().Contain("financial_department IN ('D-CAES')");
        remoteQuery.Should().Contain("(financial_department IN ('D-BCBS') AND fund = '13U02')");
        remoteQuery.Should().Contain("project IN ('PR204')");
    }

    [Fact]
    public async Task UcPath_import_bulk_copies_salary_and_fringe_rows_then_applies_name_and_job_enrichment()
    {
        await fixture.ClearDataTablesAsync();
        await using var connection = await OpenConnectionAsync();
        await connection.ExecuteAsync(
            """
            INSERT INTO [data].[Projects] ([AccessionNumber], [NifaProjectNumber], [Is204], [Sfn], [AEProjectNumber])
            VALUES ('A000001', 'NIFA-CG', 1, '204', 'PR204');
            """);

        var linkedServer = new FakeLinkedServerQueryExecutor(
            UcPathTransactionRows("SALARY-1", "E01", "1234"),
            UcPathTransactionRows("FRINGE-1", "XXX", DBNull.Value),
            EmployeeNameRows(),
            JobCodeRows());
        await using var db = fixture.CreateDataDbContext();
        var service = new UcPathTransactionsImportService(
            db,
            Configuration(),
            NullLogger<UcPathTransactionsImportService>.Instance,
            linkedServer,
            new SqlBulkCopyWriter());

        var rowsImported = await service.ImportAsync(new DateOnly(2024, 10, 1), new DateOnly(2025, 9, 30), CancellationToken.None);

        rowsImported.Should().Be(2);
        var rows = (await connection.QueryAsync<(string Id, string? EmployeeName, string? JobCode)>(
            "SELECT [LaborTransactionId], [EmployeeName], [JobCode] FROM [data].[UcPathTransactions] ORDER BY [LaborTransactionId];"))
            .ToList();
        rows.Should().BeEquivalentTo([
            ("FRINGE-1", "Example Employee", "5678"),
            ("SALARY-1", "Example Employee", "1234"),
        ]);
        linkedServer.Calls.Should().HaveCount(4);
        linkedServer.Calls.Select(call => call.CommandText).Should().ContainInOrder(
            $"EXEC (@remoteQuery, @windowStart, @windowEnd) AT [{UcPathTransactionsImportService.HcmLinkedServer}];",
            $"EXEC (@remoteQuery, @windowStart, @windowEnd) AT [{UcPathTransactionsImportService.HcmLinkedServer}];",
            $"EXEC (@remoteQuery) AT [{UcPathTransactionsImportService.HcmLinkedServer}];",
            $"EXEC (@remoteQuery, @effDtCeiling) AT [{UcPathTransactionsImportService.HcmLinkedServer}];");
    }

    private async Task<SqlConnection> OpenConnectionAsync()
    {
        var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();
        return connection;
    }

    private async Task SeedAeImportLookupsAsync(SqlConnection connection)
    {
        await connection.ExecuteAsync(
            """
            INSERT INTO [data].[ChartSegments] ([SegmentName], [Code], [ParentLevel2Code], [ParentLevel3Code])
            VALUES
                ('FinancialDepartment', 'D-CAES', 'AAES00C', NULL),
                ('FinancialDepartment', 'D-BCBS', 'BCBS00C', NULL);

            INSERT INTO [data].[Projects] ([AccessionNumber], [NifaProjectNumber], [Is204], [Sfn], [AEProjectNumber])
            VALUES ('A000001', 'NIFA-CG', 1, '204', 'PR204');
            """);
    }

    private IConfiguration Configuration() =>
        new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:DataConnection"] = fixture.ConnectionString,
                ["ConnectionStrings:Datamart"] = "Server=fake-datamart;Database=fake;Encrypt=False;",
            })
            .Build();

    private static DataTable EmptyRows() => new();

    private static DataTable PgmProjectRows()
    {
        var table = Table(
            ("project_id", typeof(long)),
            ("project_number", typeof(string)),
            ("project_name", typeof(string)),
            ("project_start_date", typeof(DateTime)),
            ("project_end_date", typeof(DateTime)),
            ("project_legal_entity", typeof(string)),
            ("project_burden_schedule_base", typeof(string)),
            ("project_burden_cost_rate", typeof(decimal)),
            ("award_number", typeof(string)),
            ("award_name", typeof(string)),
            ("award_status", typeof(string)),
            ("award_type", typeof(string)),
            ("award_purpose", typeof(string)),
            ("award_start_date", typeof(DateTime)),
            ("award_end_date", typeof(DateTime)),
            ("cfda", typeof(string)),
            ("sponsor_award_number", typeof(string)),
            ("sponsor_award_key", typeof(string)),
            ("cfda_program_number", typeof(string)),
            ("primary_sponsor", typeof(string)),
            ("primary_sponsor_name", typeof(string)),
            ("funding_source_name", typeof(string)),
            ("funding_source_number", typeof(string)),
            ("awardfundcode", typeof(string)),
            ("fund", typeof(string)),
            ("owning_org_name", typeof(string)),
            ("financial_dept_code", typeof(string)),
            ("financial_dept_name", typeof(string)),
            ("budget_period", typeof(string)),
            ("budget_start_date", typeof(DateTime)),
            ("budget_end_date", typeof(DateTime)),
            ("principal_investigator_names", typeof(string)),
            ("pi_persons", typeof(string)),
            ("award_copi_names", typeof(string)),
            ("project_manager_names", typeof(string)),
            ("grant_administrators", typeof(string)),
            ("contract_admins", typeof(string)));

        table.Rows.Add(
            9001L,
            "AE-9001",
            "PGM project",
            new DateTime(2024, 10, 1),
            new DateTime(2025, 9, 30),
            "UC Davis",
            "Base",
            1.23m,
            "AWD-9001",
            "Award 9001",
            "Active",
            "Grant",
            "Research",
            new DateTime(2024, 10, 1),
            new DateTime(2025, 9, 30),
            "10.203",
            "AWARD-9001",
            "AWARD9001",
            "10.203",
            "NIFA",
            "NIFA",
            "Federal",
            "1000",
            "AF1",
            "F1",
            "CAES",
            "D1",
            "Dept One",
            "FY25",
            new DateTime(2024, 10, 1),
            new DateTime(2025, 9, 30),
            "PI One",
            "PI Person One",
            "Co PI",
            "Manager",
            "Grant Admin",
            "Contract Admin");
        return table;
    }

    private static DataTable ChartSegmentRows()
    {
        var table = Table(
            ("segment_name", typeof(string)),
            ("code", typeof(string)),
            ("value_id", typeof(long)),
            ("description", typeof(string)),
            ("value_desc", typeof(string)),
            ("hierarchy_depth", typeof(int)),
            ("summary_flag", typeof(string)),
            ("enabled_flag", typeof(string)),
            ("start_date_active", typeof(DateTime)),
            ("end_date_active", typeof(DateTime)),
            ("parent_level_0_code", typeof(string)),
            ("parent_level_1_code", typeof(string)),
            ("parent_level_2_code", typeof(string)),
            ("parent_level_3_code", typeof(string)),
            ("parent_level_4_code", typeof(string)),
            ("parent_level_5_code", typeof(string)));

        table.Rows.Add(
            "Fund",
            "F1",
            10L,
            "Seeded fund",
            "Fund One",
            1,
            "N",
            "Y",
            new DateTime(2024, 1, 1),
            DBNull.Value,
            DBNull.Value,
            DBNull.Value,
            DBNull.Value,
            DBNull.Value,
            DBNull.Value,
            DBNull.Value);
        return table;
    }

    private static DataTable AeTransactionRows()
    {
        var table = Table(
            ("entity", typeof(string)),
            ("fund", typeof(string)),
            ("financial_department", typeof(string)),
            ("account", typeof(string)),
            ("purpose", typeof(string)),
            ("program", typeof(string)),
            ("project", typeof(string)),
            ("activity", typeof(string)),
            ("entity_description", typeof(string)),
            ("fund_description", typeof(string)),
            ("financial_department_description", typeof(string)),
            ("account_description", typeof(string)),
            ("purpose_description", typeof(string)),
            ("program_description", typeof(string)),
            ("project_description", typeof(string)),
            ("activity_description", typeof(string)),
            ("document_type", typeof(string)),
            ("accounting_sequence_number", typeof(long)),
            ("tracking_no", typeof(string)),
            ("reference", typeof(string)),
            ("journal_line_description", typeof(string)),
            ("journal_acct_date", typeof(DateTime)),
            ("journal_name", typeof(string)),
            ("journal_reference", typeof(string)),
            ("period_name", typeof(string)),
            ("journal_batch_name", typeof(string)),
            ("journal_source", typeof(string)),
            ("journal_category", typeof(string)),
            ("batch_status", typeof(string)),
            ("actual_amount", typeof(decimal)),
            ("commitment_amount", typeof(decimal)),
            ("obligation_amount", typeof(decimal)),
            ("etl_load_dt", typeof(DateTime)));

        table.Rows.Add(
            "3310",
            "13U02",
            "D-CAES",
            "A1",
            "P1",
            DBNull.Value,
            "PR204",
            "AC1",
            "Entity",
            "Fund",
            "Department",
            "Account",
            "Purpose",
            DBNull.Value,
            "Project",
            "Activity",
            "JE",
            123L,
            "TRK",
            "REF",
            "Line",
            new DateTime(2024, 10, 1),
            "Journal",
            "JournalRef",
            "Oct-24",
            "Batch",
            "Manual",
            "Category",
            "P",
            42m,
            0m,
            0m,
            new DateTime(2024, 10, 2));
        return table;
    }

    private static DataTable UcPathTransactionRows(string id, string ernCode, object jobCode)
    {
        var table = Table(
            ("labor_transaction_id", typeof(string)),
            ("entity", typeof(string)),
            ("fund", typeof(string)),
            ("financial_department", typeof(string)),
            ("parent_department", typeof(string)),
            ("account", typeof(string)),
            ("purpose", typeof(string)),
            ("program", typeof(string)),
            ("project", typeof(string)),
            ("activity", typeof(string)),
            ("erncd", typeof(string)),
            ("ern_description", typeof(string)),
            ("employee_id", typeof(string)),
            ("position_number", typeof(string)),
            ("eff_dt", typeof(DateTime)),
            ("job_code", typeof(string)),
            ("hours", typeof(decimal)),
            ("amount", typeof(decimal)),
            ("pay_rate", typeof(decimal)),
            ("calculated_fte", typeof(decimal)),
            ("pay_period_end_date", typeof(DateTime)),
            ("fringe_benefit_salary_cd", typeof(string)),
            ("paid_percent", typeof(decimal)),
            ("ern_derived_percent", typeof(decimal)),
            ("fiscal_year", typeof(int)),
            ("period", typeof(string)),
            ("emp_rcd", typeof(short)),
            ("eff_seq", typeof(short)));

        table.Rows.Add(
            id,
            "3310",
            "13U02",
            "D1",
            "D1",
            "A1",
            "P1",
            DBNull.Value,
            "PR204",
            "AC1",
            ernCode,
            "Regular",
            "20000001",
            "POS00001",
            new DateTime(2024, 10, 1),
            jobCode,
            80m,
            100m,
            1.25m,
            0.5m,
            new DateTime(2024, 10, 31),
            "S",
            100m,
            100m,
            2024,
            "4",
            (short)0,
            (short)0);
        return table;
    }

    private static DataTable EmployeeNameRows()
    {
        var table = Table(("employee_id", typeof(string)), ("employee_name", typeof(string)));
        table.Rows.Add("20000001", "Example Employee");
        return table;
    }

    private static DataTable JobCodeRows()
    {
        var table = Table(
            ("employee_id", typeof(string)),
            ("emp_rcd", typeof(short)),
            ("eff_dt", typeof(DateTime)),
            ("eff_seq", typeof(short)),
            ("position_number", typeof(string)),
            ("title_code", typeof(string)));
        table.Rows.Add("20000001", (short)0, new DateTime(2024, 10, 1), (short)0, "POS00001", "5678");
        return table;
    }

    private static DataTable Table(params (string Name, Type Type)[] columns)
    {
        var table = new DataTable();
        foreach (var (name, type) in columns)
        {
            table.Columns.Add(name, type);
        }

        return table;
    }

    private sealed class FakeLinkedServerQueryExecutor(params DataTable[] responses) : ILinkedServerQueryExecutor
    {
        private readonly Queue<DataTable> _responses = new(responses);

        public List<LinkedQueryCall> Calls { get; } = [];

        public async Task<TResult> ExecuteReaderAsync<TResult>(
            string connectionString,
            string commandText,
            IReadOnlyList<SqlParameter> parameters,
            Func<DbDataReader, CancellationToken, Task<TResult>> readAsync,
            CancellationToken cancellationToken)
        {
            Calls.Add(new LinkedQueryCall(
                commandText,
                parameters.Select(parameter => new LinkedQueryParameter(parameter.ParameterName, parameter.Value)).ToList()));

            using var reader = _responses.Dequeue().CreateDataReader();
            return await readAsync(reader, cancellationToken);
        }
    }

    private sealed record LinkedQueryCall(string CommandText, IReadOnlyList<LinkedQueryParameter> Parameters);

    private sealed record LinkedQueryParameter(string Name, object Value);
}
