using FluentAssertions;
using Server.Core.Domain;
using Server.Models.ImportRuns;

namespace Server.Tests.Import;

public sealed class ImportRunDtoTests
{
    [Theory]
    [InlineData("SqlException: secret SQL\n at SomeMethod()", "This import step could not be completed. Contact support if the problem continues.")]
    [InlineData("Interrupted by application restart.", "Interrupted by application restart.")]
    [InlineData("Interrupted by application restart.\nSqlException: secret SQL", "This import step could not be completed. Contact support if the problem continues.")]
    public void Stage_error_mapping_only_returns_known_safe_details(string errorDetail, string expectedErrorDetail)
    {
        var run = new ImportRun
        {
            Stages = [new ImportRunStage { Name = "AE", Status = ImportStageStatus.Failed, ErrorDetail = errorDetail }],
        };
        var dto = ImportRunDto.From(run);
        dto.Stages.Single().ErrorDetail.Should().Be(expectedErrorDetail);
        run.Stages.Single().ErrorDetail.Should().Be(errorDetail);
    }
}
