using Microsoft.AspNetCore.Authorization;
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
        if (context.User.GetEntraId() is not { } entraId)
        {
            return;
        }

        if (await AuthorizedUsers.IsAuthorizedAsync(_dbContext, entraId, CancellationToken.None))
        {
            context.Succeed(requirement);
        }
    }
}
