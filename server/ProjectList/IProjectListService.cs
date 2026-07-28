using Server.Models.ProjectList;
using Server.Models;

namespace Server.ProjectList;

public interface IProjectListService
{
    Task<ProjectListResponse> GetAsync(FiscalYearCycle cycle, CancellationToken cancellationToken);
}
