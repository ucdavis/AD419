using Server.OrgR;

namespace Server.Tests.OrgR;

internal sealed class FakeOrgRReviewSeeder : IOrgRReviewSeeder
{
    public int Calls { get; private set; }

    public Task SeedReviewRowsAsync(CancellationToken cancellationToken)
    {
        Calls++;
        return Task.CompletedTask;
    }
}
