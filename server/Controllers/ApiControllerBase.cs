using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Server.Authorization;

namespace Server.Controllers;

// base controller for all Api controllers
[Authorize(Policy = AuthorizationPolicies.AuthorizedUser)]
[ApiController]
[Route("api/[controller]")]
public class ApiControllerBase : ControllerBase
{

}
