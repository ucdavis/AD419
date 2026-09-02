namespace Server.OrgR;

/// <summary>Runs [data].[SeedOrgRReviewRows], inserting mapping rows that need an OrgR decision.</summary>
public interface IOrgRReviewSeeder
{
    Task SeedReviewRowsAsync(CancellationToken cancellationToken);
}
