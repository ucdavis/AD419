using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Metadata;
using Server.Core.Data;
using Server.Core.Domain;

namespace Server.Tests.Data;

public class AppDbContextTests
{
    [Fact]
    public void User_uses_integer_id_as_primary_key()
    {
        using var db = TestDbContextFactory.CreateInMemory();

        var entityType = db.Model.FindEntityType(typeof(User));
        if (entityType is null)
        {
            throw new InvalidOperationException("User entity type should be configured.");
        }

        var primaryKey = entityType.FindPrimaryKey();
        if (primaryKey is null)
        {
            throw new InvalidOperationException("User should have a primary key.");
        }

        primaryKey.Properties.Should().ContainSingle();
        primaryKey.Properties[0].Name.Should().Be(nameof(User.Id));
        primaryKey.Properties[0].ClrType.Should().Be(typeof(int));
        primaryKey.Properties[0].ValueGenerated.Should().Be(ValueGenerated.OnAdd);
    }

    [Fact]
    public void User_maps_to_app_schema()
    {
        using var db = TestDbContextFactory.CreateInMemory();

        var entityType = db.Model.FindEntityType(typeof(User));

        entityType.Should().NotBeNull();
        entityType!.GetSchema().Should().Be(AppDbContext.AppSchema);
        entityType.GetTableName().Should().Be("Users");
    }

    [Fact]
    public void ImportLog_maps_to_app_schema()
    {
        using var db = TestDbContextFactory.CreateInMemory();

        var entityType = db.Model.FindEntityType(typeof(ImportLog));

        entityType.Should().NotBeNull();
        entityType!.GetSchema().Should().Be(AppDbContext.AppSchema);
        entityType.GetTableName().Should().Be("ImportLog");
    }

    [Fact]
    public void ImportLog_has_index_for_latest_log_by_dataset()
    {
        using var db = TestDbContextFactory.CreateInMemory();

        var entityType = db.GetService<IDesignTimeModel>().Model.FindEntityType(typeof(ImportLog));
        var latestByDatasetIndex = entityType?.GetIndexes()
            .SingleOrDefault(index => index.Properties.Select(property => property.Name)
                .SequenceEqual([
                    nameof(ImportLog.Dataset),
                    nameof(ImportLog.CompletedAt),
                    nameof(ImportLog.Id),
                ]));

        latestByDatasetIndex.Should().NotBeNull();
        latestByDatasetIndex!.IsDescending.Should().Equal([false, true, true]);
    }

    [Fact]
    public void User_has_unique_index_on_entra_id()
    {
        using var db = TestDbContextFactory.CreateInMemory();

        var entityType = db.Model.FindEntityType(typeof(User));
        var entraIdIndex = entityType?.GetIndexes()
            .SingleOrDefault(index => index.Properties.Count == 1
                && index.Properties[0].Name == nameof(User.EntraId));

        entraIdIndex.Should().NotBeNull();
        entraIdIndex!.IsUnique.Should().BeTrue();
    }

    [Fact]
    public void User_entra_id_is_required_guid()
    {
        using var db = TestDbContextFactory.CreateInMemory();

        var entityType = db.Model.FindEntityType(typeof(User));
        var entraIdProperty = entityType?.FindProperty(nameof(User.EntraId));

        entraIdProperty.Should().NotBeNull();
        entraIdProperty!.ClrType.Should().Be(typeof(Guid));
        entraIdProperty!.IsNullable.Should().BeFalse();
    }
}
