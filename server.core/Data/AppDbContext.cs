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
            entity.Property(segment => segment.Sfn).HasMaxLength(3);
        });
    }
}
