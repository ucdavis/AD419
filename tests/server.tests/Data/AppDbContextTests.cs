using FluentAssertions;
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
        var primaryKey = entityType?.FindPrimaryKey();

        primaryKey.Should().NotBeNull();
        primaryKey!.Properties.Should().ContainSingle();
        primaryKey.Properties[0].Name.Should().Be(nameof(User.Id));
        primaryKey.Properties[0].ClrType.Should().Be(typeof(int));
        primaryKey.Properties[0].ValueGenerated.Should().Be(ValueGenerated.OnAdd);
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
        entraIdProperty.IsNullable.Should().BeFalse();
    }
}
