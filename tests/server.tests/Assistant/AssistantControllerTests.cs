using System.Net;
using System.Security.Claims;
using FluentAssertions;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Server.Assistant;
using Server.Controllers;
using UCDavis.CaesAi.AppSdk;

namespace Server.Tests.Assistant;

public class AssistantControllerTests
{
    private static readonly Guid EntraId = Guid.NewGuid();

    [Fact]
    public async Task Creates_a_session_for_the_signed_in_user_with_the_expense_review_tools()
    {
        var sessions = new StubSessions();
        var controller = Controller(sessions);

        var result = await controller.CreateSession(CancellationToken.None);

        var ok = result.Should().BeOfType<OkObjectResult>().Subject;
        ok.Value.Should().BeOfType<BrowserAssistantSessionResponse>();
        sessions.LastDefinition!.UserReference.Should().Be(EntraId.ToString());
        sessions.LastDefinition.Instructions.Should().Be(ExpenseReviewAssistant.Instructions);
        sessions.LastDefinition.Tools.Select(tool => tool.Name)
            .Should().BeEquivalentTo(ExpenseReviewToolManifest.Build().Select(tool => tool.Name));
    }

    [Fact]
    public async Task Returns_503_when_caes_ai_rejects_the_request()
    {
        var controller = Controller(new StubSessions
        {
            Throw = new CaesAiApiException(HttpStatusCode.Unauthorized, null),
        });

        var result = await controller.CreateSession(CancellationToken.None);

        var problem = result.Should().BeOfType<ObjectResult>().Subject;
        problem.StatusCode.Should().Be(StatusCodes.Status503ServiceUnavailable);
        problem.Value.Should().BeOfType<ProblemDetails>()
            .Which.Title.Should().Be("The assistant service is unavailable.");
    }

    [Fact]
    public async Task Returns_503_when_caes_ai_is_unreachable()
    {
        var controller = Controller(new StubSessions { Throw = new HttpRequestException("connection refused") });

        var result = await controller.CreateSession(CancellationToken.None);

        result.Should().BeOfType<ObjectResult>().Which.StatusCode.Should().Be(503);
    }

    [Fact]
    public async Task Returns_401_when_the_user_has_no_entra_id()
    {
        var controller = Controller(new StubSessions(), withEntraId: false);

        var result = await controller.CreateSession(CancellationToken.None);

        result.Should().BeOfType<UnauthorizedResult>();
    }

    private static AssistantController Controller(StubSessions sessions, bool withEntraId = true)
    {
        var claims = withEntraId ? new[] { new Claim("oid", EntraId.ToString()) } : [];
        var httpContext = new DefaultHttpContext
        {
            User = new ClaimsPrincipal(new ClaimsIdentity(claims, "test")),
        };
        return new AssistantController(sessions)
        {
            ControllerContext = new ControllerContext { HttpContext = httpContext },
        };
    }

    private sealed class StubSessions : ICaesAiSessionService
    {
        public Exception? Throw { get; init; }
        public CaesAiSessionDefinition? LastDefinition { get; private set; }

        public Task<BrowserAssistantSessionResponse> CreateSessionAsync(
            CaesAiSessionDefinition definition,
            CancellationToken cancellationToken)
        {
            LastDefinition = definition;
            if (Throw is not null)
            {
                throw Throw;
            }

            return Task.FromResult(new BrowserAssistantSessionResponse(
                CaesAiProtocol.CurrentVersion,
                Guid.NewGuid(),
                "browser-session-token-that-is-long-enough",
                DateTimeOffset.UtcNow.AddMinutes(30),
                "https://caes-ai.test/v1/sessions/x/chat",
                new EffectiveModelPolicy("gpt-5.6-luna", "none", "none", ["none"]),
                new string('a', 64),
                definition.Tools));
        }
    }
}
