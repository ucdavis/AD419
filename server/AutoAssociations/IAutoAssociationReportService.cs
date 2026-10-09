using Server.Models.AutoAssociations;

namespace Server.AutoAssociations;

public interface IAutoAssociationReportService
{
    Task<AutoAssociationBuildDto?> GetBuildAsync(CancellationToken cancellationToken);
    Task<Rule204ReportDto> GetRule204Async(CancellationToken cancellationToken);
    Task<Rule20xReportDto> GetRule20xAsync(CancellationToken cancellationToken);
    Task<Rule220ReportDto> GetRule220Async(CancellationToken cancellationToken);
    Task<IReadOnlyList<ExcludedProjectDto>> GetExcludedProjectsAsync(CancellationToken cancellationToken);
    Task<IReadOnlyList<FteOverOneDto>> GetFteOverOneAsync(CancellationToken cancellationToken);
    Task<IReadOnlyList<PreAssociationTotalDto>> GetPreAssociationTotalsAsync(CancellationToken cancellationToken);
}
