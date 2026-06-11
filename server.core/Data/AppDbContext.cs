using Microsoft.EntityFrameworkCore;
using Server.Core.Domain;

namespace Server.Core.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public const string AppSchema = "app";
    public const string MigrationsHistoryTable = "__EFMigrationsHistory";

    public DbSet<ImportLog> ImportLogs => Set<ImportLog>();
    public DbSet<User> Users => Set<User>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.HasDefaultSchema(AppSchema);
        modelBuilder.Entity<ImportLog>().ToTable("ImportLog", AppSchema);
        modelBuilder.Entity<User>().ToTable("Users", AppSchema);
    }
}
