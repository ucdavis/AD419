using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;
using Server.Authorization;

namespace Server.Controllers;

public class UserController : ApiControllerBase
{
    [HttpGet("me")]
    public IActionResult Me()
    {
        var userId = User.GetEntraId();
        var userName = User.FindFirst("name")?.Value;
        var userEmail = User.FindFirst("preferred_username")?.Value;

        var userRoles = User.FindAll(ClaimTypes.Role).Select(c => c.Value).ToList();

        if (userId is null)
        {
            return Unauthorized();
        }

        var userInfo = new
        {
            Id = userId.Value,
            Name = userName,
            Email = userEmail,
            Roles = userRoles,
        };

        return Ok(userInfo);
    }
}
