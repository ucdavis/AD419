using Server.Models.ProjectList;
using Server.Models;

namespace Server.ProjectList;

public static class ProjectListResponseFactory
{
    private const string CleanStatus = "Clean";

    public static ProjectListResponse Create(
        FiscalYearCycle cycle,
        IReadOnlyList<ProjectListRowDto> rows,
        int activeNifa,
        int allNifa,
        int pgmRecords,
        int alnCodes)
    {
        var issues = rows.Count(row => row.Status != CleanStatus);
        var clean = rows.Count(row => row.Status == CleanStatus);
        var sfnDistribution = rows
            .Where(row => !string.IsNullOrWhiteSpace(row.Sfn))
            .GroupBy(row => row.Sfn!)
            .OrderBy(group => group.Key)
            .Select(group => new SfnDistributionDto(group.Key, group.Count()))
            .ToList();

        return new ProjectListResponse(
            cycle.FiscalYear,
            cycle.CycleStart,
            cycle.CycleEnd,
            new ProjectListCountsDto(issues, clean, rows.Count),
            new ProjectListSummaryDto(
                activeNifa,
                allNifa,
                pgmRecords,
                alnCodes,
                issues,
                sfnDistribution),
            rows);
    }
}
