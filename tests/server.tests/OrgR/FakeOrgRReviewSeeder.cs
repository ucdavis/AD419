using Server.OrgRReview;

namespace Server.Tests.OrgRReview;

internal sealed class FakeOrgRReviewSeeder : IOrgRReviewSeeder
{
    public int Calls { get; private set; }

    public Task SeedReviewRowsAsync(CancellationToken cancellationToken)
    {
        Calls++;
        return Task.CompletedTask;
    }
}
