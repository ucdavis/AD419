using Microsoft.EntityFrameworkCore;
using Server.Core.Domain;

namespace Server.Core.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<User> Users => Set<User>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<User>(entity =>
        {
            entity.Property(user => user.Id)
                .ValueGeneratedOnAdd();

            entity.Property(user => user.EntraId)
                .IsRequired();

            entity.HasIndex(user => user.EntraId)
                .IsUnique();
        });
    }
}
