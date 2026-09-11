using Microsoft.AspNetCore.Mvc;
using Server.Assistant;
using Server.Authorization;
using UCDavis.CaesAi.AppSdk;

namespace Server.Controllers;

public sealed class AssistantController(ICaesAiSessionService sessions) : ApiControllerBase
{
    [HttpPost("session")]
    public async Task<IActionResult> CreateSession(CancellationToken cancellationToken)
    {
        if (User.GetEntraId() is not { } entraId)
        {
            return Unauthorized();
        }

        var definition = new CaesAiSessionDefinition(
            entraId.ToString(),
            ExpenseReviewAssistant.Instructions,
            ExpenseReviewToolManifest.Build());

        try
        {
            return Ok(await sessions.CreateSessionAsync(definition, cancellationToken));
        }
        catch (HttpRequestException)
        {
            return Problem(
                statusCode: StatusCodes.Status503ServiceUnavailable,
                title: "The assistant service is unavailable.");
        }
    }
}
