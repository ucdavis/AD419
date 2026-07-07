using Microsoft.EntityFrameworkCore;
using Server.Core.Domain;

namespace Server.Core.Data;

public class DataDbContext(DbContextOptions<DataDbContext> options) : DbContext(options)
{
    public const string DataSchema = "data";

    public DbSet<ChartStringSegment> ChartStringSegments => Set<ChartStringSegment>();

    public DbSet<DepartmentHierarchy> DepartmentHierarchies => Set<DepartmentHierarchy>();
    public DbSet<AccountHierarchy> AccountHierarchies => Set<AccountHierarchy>();
    public DbSet<FundHierarchy> FundHierarchies => Set<FundHierarchy>();
    public DbSet<ActivityHierarchy> ActivityHierarchies => Set<ActivityHierarchy>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.HasDefaultSchema(DataSchema);

        modelBuilder.Entity<ChartStringSegment>(entity =>
        {
            entity.ToTable("ChartStringSegments", DataSchema, table => table.ExcludeFromMigrations());
            entity.HasKey(segment => new { segment.SegmentType, segment.Code });
            entity.Property(segment => segment.SegmentType).HasConversion<string>().HasMaxLength(20);
            entity.Property(segment => segment.Code).HasMaxLength(50);
            entity.Property(segment => segment.Description).HasMaxLength(300);
            entity.Property(segment => segment.Sfn).HasMaxLength(10);
        });

        ConfigureHierarchy<DepartmentHierarchy>(modelBuilder, "DepartmentHierarchy");
        ConfigureHierarchy<AccountHierarchy>(modelBuilder, "AccountHierarchy");
        ConfigureHierarchy<FundHierarchy>(modelBuilder, "FundHierarchy");
        ConfigureHierarchy<ActivityHierarchy>(modelBuilder, "ActivityHierarchy");
    }

    private static void ConfigureHierarchy<T>(ModelBuilder modelBuilder, string table)
        where T : class, ISegmentHierarchy
    {
        modelBuilder.Entity<T>(entity =>
        {
            entity.ToTable(table, DataSchema, mapping => mapping.ExcludeFromMigrations());
            entity.HasKey(e => e.Code);

            foreach (var property in entity.Metadata.GetProperties()
                         .Where(p => p.ClrType == typeof(string)))
            {
                var maxLength = property.Name switch
                {
                    // Match ChartStringSegment.Code so joins/lookups on Code stay aligned.
                    nameof(ISegmentHierarchy.Code) => 50,
                    "Description" => 1000,
                    _ when property.Name.EndsWith("Name") => 1000,
                    _ => 20,
                };
                property.SetMaxLength(maxLength);
            }
        });
    }
}
