using Microsoft.EntityFrameworkCore;
using Server.Core.Data;

namespace Server.OrgR;

public sealed class OrgRReviewSeeder(DataDbContext db) : IOrgRReviewSeeder
{
    public Task SeedReviewRowsAsync(CancellationToken cancellationToken) =>
        db.Database.ExecuteSqlRawAsync("EXEC [data].[SeedOrgRReviewRows]", cancellationToken);
}
