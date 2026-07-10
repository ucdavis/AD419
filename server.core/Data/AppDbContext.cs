using Microsoft.EntityFrameworkCore;
using Server.Core.Domain;

namespace Server.Core.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public const string AppSchema = "app";
    public const string MigrationsHistoryTable = "__EFMigrationsHistory";

    public DbSet<ImportLog> ImportLogs => Set<ImportLog>();
    public DbSet<User> Users => Set<User>();
    public DbSet<WorkflowRun> WorkflowRuns => Set<WorkflowRun>();
    public DbSet<WorkflowChecklistItemState> WorkflowChecklistItemStates => Set<WorkflowChecklistItemState>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.HasDefaultSchema(AppSchema);
        modelBuilder.Entity<ImportLog>().ToTable("ImportLog", AppSchema);
        modelBuilder.Entity<User>().ToTable("Users", AppSchema);
        modelBuilder.Entity<WorkflowRun>().ToTable("WorkflowRun", AppSchema);
        modelBuilder.Entity<WorkflowChecklistItemState>().ToTable("WorkflowChecklistItemState", AppSchema);

        modelBuilder.Entity<WorkflowRun>()
            .HasMany(run => run.ChecklistItemStates)
            .WithOne(state => state.WorkflowRun)
            .HasForeignKey(state => state.WorkflowRunId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
