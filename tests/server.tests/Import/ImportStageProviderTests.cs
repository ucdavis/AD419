using FluentAssertions;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Server.Core.Import;

namespace Server.Tests.Import;

public class ImportStageProviderTests
{
    private static ImportStageProvider CreateProvider()
    {
        var db = TestDbContextFactory.CreateDataInMemory();
        var config = new ConfigurationBuilder().Build();
        var linkedServer = new LinkedServerQueryExecutor();
        var bulkCopy = new SqlBulkCopyWriter();
        return new ImportStageProvider(
            new ChartSegmentsImportService(db, config, NullLogger<ChartSegmentsImportService>.Instance, linkedServer, bulkCopy),
            new AeTransactionsImportService(db, config, NullLogger<AeTransactionsImportService>.Instance, linkedServer, bulkCopy),
            new UcPathTransactionsImportService(db, config, NullLogger<UcPathTransactionsImportService>.Instance, linkedServer, bulkCopy),
            new SprocStageService(db, config));
    }

    [Fact]
    public void Stage_names_match_the_canonical_order()
    {
        CreateProvider().StageNames.Should().Equal(ImportStageNames.All);
    }

    [Fact]
    public void BuildStages_produces_one_stage_per_name_in_order()
    {
        var context = new ImportRunContext(1, new DateOnly(2024, 10, 1), new DateOnly(2025, 9, 30));
        var stages = CreateProvider().BuildStages(context);

        stages.Select(s => s.Name).Should().Equal(ImportStageNames.All);
    }
}
