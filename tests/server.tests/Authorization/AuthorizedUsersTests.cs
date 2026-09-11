using FluentAssertions;
using Server.Authorization;
using Server.Core.Domain;
using Server.Tests;

namespace Server.Tests.Authorization;

public class AuthorizedUsersTests
{
    [Fact]
    public async Task IsAuthorizedAsync_returns_true_for_a_known_entra_id()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        var entraId = Guid.NewGuid();
        db.Users.Add(new User { EntraId = entraId, Name = "Shannon", Email = "shannon@example.edu" });
        await db.SaveChangesAsync();

        var result = await AuthorizedUsers.IsAuthorizedAsync(db, entraId, CancellationToken.None);

        result.Should().BeTrue();
    }

    [Fact]
    public async Task IsAuthorizedAsync_returns_false_for_an_unknown_entra_id()
    {
        await using var db = TestDbContextFactory.CreateInMemory();

        var result = await AuthorizedUsers.IsAuthorizedAsync(db, Guid.NewGuid(), CancellationToken.None);

        result.Should().BeFalse();
    }
}
