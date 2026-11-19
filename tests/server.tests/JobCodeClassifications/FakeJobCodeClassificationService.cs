using Server.JobCodeClassifications;
using Server.Models;
using Server.Models.JobCodeClassifications;

namespace Server.Tests.JobCodeClassifications;

// Stands in for the job code gate in workflow tests; nothing blocks unless a test says so.
internal sealed class FakeJobCodeClassificationService : IJobCodeClassificationService
{
    public bool HasBlocking { get; set; }

    public FiscalYearCycle? ReceivedCycle { get; private set; }

    public Task<bool> HasBlockingAsync(FiscalYearCycle cycle, CancellationToken cancellationToken)
    {
        ReceivedCycle = cycle;
        return Task.FromResult(HasBlocking);
    }

    public Task<JobCodeClassificationsResponse> GetAsync(FiscalYearCycle cycle, CancellationToken cancellationToken) =>
        throw new NotSupportedException();

    public Task<JobCodeAssignResult> AssignAsync(string? jobCode, string? staffTypeCode, CancellationToken cancellationToken) =>
        throw new NotSupportedException();
}
