using System.Security.Claims;

namespace Server.Authorization;

public static class EntraIdClaims
{
    private const string MappedObjectIdentifierClaim = "http://schemas.microsoft.com/identity/claims/objectidentifier";
    private const string ObjectIdentifierClaim = "oid";

    public static string? GetEntraId(this ClaimsPrincipal principal)
    {
        return principal.FindFirst(MappedObjectIdentifierClaim)?.Value
               ?? principal.FindFirst(ObjectIdentifierClaim)?.Value;
    }
}
