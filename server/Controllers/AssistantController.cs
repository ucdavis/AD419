using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.DependencyInjection;
using Server.Assistant;
using Server.Authorization;
using UCDavis.CaesAi.AppSdk;

namespace Server.Controllers;

public sealed class AssistantController(IServiceProvider services) : ApiControllerBase
{
    [HttpPost("session")]
    public async Task<IActionResult> CreateSession(CancellationToken cancellationToken)
    {
        if (services.GetService<ICaesAiSessionService>() is not { } sessions)
        {
            return Problem(
                statusCode: StatusCodes.Status503ServiceUnavailable,
                title: "The assistant service is not configured.");
        }

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
        // CaesAiApiException derives from HttpRequestException, so one catch covers both.
        catch (HttpRequestException)
        {
            return Problem(
                statusCode: StatusCodes.Status503ServiceUnavailable,
                title: "The assistant service is unavailable.");
        }
    }
}
