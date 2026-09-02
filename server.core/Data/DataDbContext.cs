using Microsoft.EntityFrameworkCore;
using Server.Core.Domain;

namespace Server.Core.Data;

public class DataDbContext(DbContextOptions<DataDbContext> options) : DbContext(options)
{
    public const string DataSchema = "data";

    public DbSet<SegmentClassification> SegmentClassifications => Set<SegmentClassification>();

    public DbSet<OrgR> OrgRs => Set<OrgR>();
    public DbSet<OrgRFinancialDepartment> OrgRFinancialDepartments => Set<OrgRFinancialDepartment>();
    public DbSet<OrgRNifaDepartment> OrgRNifaDepartments => Set<OrgRNifaDepartment>();
    public DbSet<OrgRProjectAddition> OrgRProjectAdditions => Set<OrgRProjectAddition>();
    public DbSet<Project> Projects => Set<Project>();

    public DbSet<DepartmentHierarchy> DepartmentHierarchies => Set<DepartmentHierarchy>();
    public DbSet<AccountHierarchy> AccountHierarchies => Set<AccountHierarchy>();
    public DbSet<FundHierarchy> FundHierarchies => Set<FundHierarchy>();
    public DbSet<ActivityHierarchy> ActivityHierarchies => Set<ActivityHierarchy>();
    public DbSet<PurposeHierarchy> PurposeHierarchies => Set<PurposeHierarchy>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.HasDefaultSchema(DataSchema);

        modelBuilder.Entity<SegmentClassification>(entity =>
        {
            entity.ToTable("SegmentClassifications", DataSchema, table => table.ExcludeFromMigrations());
            entity.HasKey(segment => new { segment.SegmentType, segment.Code });
            entity.Property(segment => segment.SegmentType).HasConversion<string>().HasMaxLength(20);
            entity.Property(segment => segment.Code).HasMaxLength(50);
            entity.Property(segment => segment.Description).HasMaxLength(300);
            entity.Property(segment => segment.Sfn).HasMaxLength(10);
        });

        modelBuilder.Entity<OrgR>(entity =>
        {
            entity.ToTable("OrgRs", DataSchema, table => table.ExcludeFromMigrations());
            entity.HasKey(o => o.Code);
            entity.Property(o => o.Code).HasMaxLength(10);
        });

        modelBuilder.Entity<OrgRFinancialDepartment>(entity =>
        {
            entity.ToTable("OrgRFinancialDepartments", DataSchema, table => table.ExcludeFromMigrations());
            entity.HasKey(m => m.FinancialDepartment);
            entity.Property(m => m.FinancialDepartment).HasMaxLength(50);
            entity.Property(m => m.OrgR).HasMaxLength(10);
        });

        modelBuilder.Entity<OrgRNifaDepartment>(entity =>
        {
            entity.ToTable("OrgRNifaDepartments", DataSchema, table => table.ExcludeFromMigrations());
            entity.HasKey(m => m.NifaDepartment);
            entity.Property(m => m.NifaDepartment).HasMaxLength(3);
            entity.Property(m => m.OrgR).HasMaxLength(10);
        });

        modelBuilder.Entity<OrgRProjectAddition>(entity =>
        {
            entity.ToTable("OrgRProjectAdditions", DataSchema, table => table.ExcludeFromMigrations());
            entity.HasKey(a => new { a.AccessionNumber, a.OrgR });
            entity.Property(a => a.AccessionNumber).HasMaxLength(7);
            entity.Property(a => a.OrgR).HasMaxLength(10);
        });

        modelBuilder.Entity<Project>(entity =>
        {
            entity.ToTable("Projects", DataSchema, table => table.ExcludeFromMigrations());
            entity.HasKey(p => p.Id);
            entity.Property(p => p.AccessionNumber).HasMaxLength(7);
            entity.Property(p => p.NifaProjectNumber).HasMaxLength(20);
            entity.Property(p => p.ProjectDirector).HasMaxLength(200);
        });

        ConfigureHierarchy<DepartmentHierarchy>(modelBuilder, "DepartmentHierarchy");
        ConfigureHierarchy<AccountHierarchy>(modelBuilder, "AccountHierarchy");
        ConfigureHierarchy<FundHierarchy>(modelBuilder, "FundHierarchy");
        ConfigureHierarchy<ActivityHierarchy>(modelBuilder, "ActivityHierarchy");
        ConfigureHierarchy<PurposeHierarchy>(modelBuilder, "PurposeHierarchy");
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
                    // Match SegmentClassification.Code so joins/lookups on Code stay aligned.
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
