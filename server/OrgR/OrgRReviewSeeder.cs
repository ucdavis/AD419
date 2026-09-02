using Microsoft.EntityFrameworkCore;
using Server.Core.Data;

namespace Server.OrgRReview;

public sealed class OrgRReviewSeeder(DataDbContext db) : IOrgRReviewSeeder
{
    public Task SeedReviewRowsAsync(CancellationToken cancellationToken) =>
        db.Database.ExecuteSqlRawAsync("EXEC [data].[SeedOrgRReviewRows]", cancellationToken);
}
