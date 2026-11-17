using Server.Models;
using Server.Models.JobCodeClassifications;

namespace Server.JobCodeClassifications;

public enum JobCodeAssignResult
{
    Assigned,
    InvalidJobCode,
    InvalidStaffType,
}

public interface IJobCodeClassificationService
{
    /// <summary>Job codes on reported payroll in the cycle, and the staff types they can be assigned to.</summary>
    Task<JobCodeClassificationsResponse> GetAsync(FiscalYearCycle cycle, CancellationToken cancellationToken);

    /// <summary>True while any job code in the cycle is blocking; the Data Classification gate.</summary>
    Task<bool> HasBlockingAsync(FiscalYearCycle cycle, CancellationToken cancellationToken);

    /// <summary>Sets the job code's staff type, creating its title row when there is none.</summary>
    Task<JobCodeAssignResult> AssignAsync(string? jobCode, string? staffTypeCode, CancellationToken cancellationToken);
}
