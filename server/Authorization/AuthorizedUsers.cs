using Microsoft.EntityFrameworkCore;
using Server.Core.Data;

namespace Server.Authorization;

public static class AuthorizedUsers
{
    public static Task<bool> IsAuthorizedAsync(
        AppDbContext db,
        Guid entraId,
        CancellationToken cancellationToken) =>
        db.Users.AnyAsync(user => user.EntraId == entraId, cancellationToken);
}
