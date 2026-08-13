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
    public DbSet<WorkflowStageState> WorkflowStageStates => Set<WorkflowStageState>();
    public DbSet<ImportRun> ImportRuns => Set<ImportRun>();
    public DbSet<ImportRunStage> ImportRunStages => Set<ImportRunStage>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.HasDefaultSchema(AppSchema);
        modelBuilder.Entity<ImportLog>().ToTable("ImportLog", AppSchema);
        modelBuilder.Entity<User>().ToTable("Users", AppSchema);
        modelBuilder.Entity<WorkflowRun>().ToTable("WorkflowRun", AppSchema);
        modelBuilder.Entity<WorkflowChecklistItemState>().ToTable("WorkflowChecklistItemState", AppSchema);
        modelBuilder.Entity<WorkflowStageState>().ToTable("WorkflowStageState", AppSchema);
        modelBuilder.Entity<ImportRun>().ToTable("ImportRun", AppSchema);
        modelBuilder.Entity<ImportRunStage>().ToTable("ImportRunStage", AppSchema);

        modelBuilder.Entity<WorkflowRun>()
            .HasIndex(run => run.IsCurrent)
            .IsUnique()
            .HasFilter("[IsCurrent] = 1");

        modelBuilder.Entity<WorkflowRun>()
            .HasMany(run => run.ChecklistItemStates)
            .WithOne(state => state.WorkflowRun)
            .HasForeignKey(state => state.WorkflowRunId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<WorkflowRun>()
            .HasMany(run => run.StageStates)
            .WithOne(state => state.WorkflowRun)
            .HasForeignKey(state => state.WorkflowRunId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<WorkflowChecklistItemState>()
            .HasOne(state => state.SourceImportLog)
            .WithMany()
            .HasForeignKey(state => state.SourceImportLogId)
            .OnDelete(DeleteBehavior.SetNull);

        modelBuilder.Entity<ImportRun>()
            .HasMany(run => run.Stages)
            .WithOne(stage => stage.ImportRun)
            .HasForeignKey(stage => stage.ImportRunId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<ImportRun>()
            .HasIndex(run => run.Status);
    }
}
