using System.Security.Claims;

namespace Server.Authorization;

public static class EntraIdClaims
{
    private const string MappedObjectIdentifierClaim = "http://schemas.microsoft.com/identity/claims/objectidentifier";
    private const string ObjectIdentifierClaim = "oid";

    public static Guid? GetEntraId(this ClaimsPrincipal principal)
    {
        var entraId = principal.FindFirst(MappedObjectIdentifierClaim)?.Value
            ?? principal.FindFirst(ObjectIdentifierClaim)?.Value;

        return Guid.TryParse(entraId, out var parsedEntraId)
            ? parsedEntraId
            : null;
    }
}
