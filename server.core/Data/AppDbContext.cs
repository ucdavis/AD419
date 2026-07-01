using Microsoft.EntityFrameworkCore;
using Server.Core.Domain;

namespace Server.Core.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public const string AppSchema = "app";
    public const string DataSchema = "data";
    public const string MigrationsHistoryTable = "__EFMigrationsHistory";

    public DbSet<User> Users => Set<User>();

    public DbSet<ChartStringSegment> ChartStringSegments => Set<ChartStringSegment>();

    public DbSet<DepartmentHierarchy> DepartmentHierarchies => Set<DepartmentHierarchy>();
    public DbSet<AccountHierarchy> AccountHierarchies => Set<AccountHierarchy>();
    public DbSet<FundHierarchy> FundHierarchies => Set<FundHierarchy>();
    public DbSet<ActivityHierarchy> ActivityHierarchies => Set<ActivityHierarchy>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.HasDefaultSchema(AppSchema);
        modelBuilder.Entity<User>().ToTable("Users", AppSchema);

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
            entity.ToTable(table, DataSchema, t => t.ExcludeFromMigrations());
            entity.HasKey(e => e.Code);
            entity.Property(e => e.Code).HasMaxLength(20);
            entity.Property(e => e.Description).HasMaxLength(1000);
        });
    }
}
