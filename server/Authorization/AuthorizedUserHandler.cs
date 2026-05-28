using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;
using Server.Core.Data;

namespace Server.Authorization;

public class AuthorizedUserHandler : AuthorizationHandler<AuthorizedUserRequirement>
{
    private readonly AppDbContext _dbContext;

    public AuthorizedUserHandler(AppDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    protected override async Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        AuthorizedUserRequirement requirement)
    {
        var entraId = context.User.GetEntraId();

        if (string.IsNullOrWhiteSpace(entraId))
        {
            return;
        }

        if (await _dbContext.Users.AnyAsync(user => user.EntraId == entraId))
        {
            context.Succeed(requirement);
        }
    }
}
