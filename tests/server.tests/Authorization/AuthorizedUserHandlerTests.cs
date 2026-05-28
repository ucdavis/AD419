using System.Security.Claims;
using FluentAssertions;
using Microsoft.AspNetCore.Authorization;
using Server.Authorization;
using Server.Tests;

namespace Server.Tests.Authorization;

public class AuthorizedUserHandlerTests
{
    private const string EntraId = "11111111-1111-1111-1111-111111111111";
    private const string MappedObjectIdentifierClaim = "http://schemas.microsoft.com/identity/claims/objectidentifier";

    [Fact]
    public async Task HandleRequirementAsync_allows_user_with_matching_mapped_entra_id()
    {
        using var db = TestDbContextFactory.CreateInMemory();
        db.Users.Add(new Server.Core.Domain.User { EntraId = EntraId });
        await db.SaveChangesAsync();

        var context = CreateContext(new Claim(MappedObjectIdentifierClaim, EntraId));
        var handler = new AuthorizedUserHandler(db);

        await handler.HandleAsync(context);

        context.HasSucceeded.Should().BeTrue();
    }

    [Fact]
    public async Task HandleRequirementAsync_allows_user_with_matching_raw_oid_claim()
    {
        using var db = TestDbContextFactory.CreateInMemory();
        db.Users.Add(new Server.Core.Domain.User { EntraId = EntraId });
        await db.SaveChangesAsync();

        var context = CreateContext(new Claim("oid", EntraId));
        var handler = new AuthorizedUserHandler(db);

        await handler.HandleAsync(context);

        context.HasSucceeded.Should().BeTrue();
    }

    [Fact]
    public async Task HandleRequirementAsync_denies_user_not_in_users_table()
    {
        using var db = TestDbContextFactory.CreateInMemory();
        var context = CreateContext(new Claim(MappedObjectIdentifierClaim, EntraId));
        var handler = new AuthorizedUserHandler(db);

        await handler.HandleAsync(context);

        context.HasSucceeded.Should().BeFalse();
    }

    [Fact]
    public async Task HandleRequirementAsync_denies_user_without_entra_id_claim()
    {
        using var db = TestDbContextFactory.CreateInMemory();
        db.Users.Add(new Server.Core.Domain.User { EntraId = EntraId });
        await db.SaveChangesAsync();

        var context = CreateContext(new Claim(ClaimTypes.NameIdentifier, EntraId));
        var handler = new AuthorizedUserHandler(db);

        await handler.HandleAsync(context);

        context.HasSucceeded.Should().BeFalse();
    }

    private static AuthorizationHandlerContext CreateContext(params Claim[] claims)
    {
        var requirement = new AuthorizedUserRequirement();
        var identity = new ClaimsIdentity(claims, "TestAuth");
        return new AuthorizationHandlerContext([requirement], new ClaimsPrincipal(identity), null);
    }
}
