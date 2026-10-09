using System.Diagnostics;
using System.Net;
using System.Security.Claims;
using System.Text.Encodings.Web;
using FluentAssertions;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Server.Helpers;

namespace Server.Tests.Helpers;

public sealed class ApiFailureLoggingMiddlewareTests
{
    [Theory]
    [InlineData("POST", LogLevel.Warning)]
    [InlineData("PUT", LogLevel.Warning)]
    [InlineData("PATCH", LogLevel.Warning)]
    [InlineData("DELETE", LogLevel.Warning)]
    [InlineData("GET", LogLevel.Information)]
    [InlineData("HEAD", LogLevel.Information)]
    public async Task Cancellation_preserves_exception_and_logs_context(string method, LogLevel level)
    {
        using var activity = new Activity("request").SetIdFormat(ActivityIdFormat.W3C).Start();
        var context = Context(method);
        var logger = new RecordingLogger<ApiFailureLoggingMiddleware>();
        using var cancellation = new CancellationTokenSource();
        context.RequestAborted = cancellation.Token;
        var exception = new OperationCanceledException(cancellation.Token);
        await using var app = CreatePipeline(logger, ctx =>
        {
            using var inner = logger.BeginScope(new Dictionary<string, object?> { ["InnerScope"] = true });
            cancellation.Cancel();
            return Task.FromException(exception);
        });
        context.RequestServices = app.Services;
        context.Request.Headers["X-Test-User"] = "test-user";
        context.Request.Headers["X-Test-Allowed"] = "true";
        var pipeline = ((IApplicationBuilder)app).Build();

        var act = () => pipeline(context);
        (await act.Should().ThrowAsync<OperationCanceledException>()).Which.Should().BeSameAs(exception);
        var entry = logger.Entries.Should().ContainSingle(e => e.Message.StartsWith("API request")).Subject;
        entry.Level.Should().Be(level);
        entry.Fields["RequestAborted"].Should().Be(true);
        entry.Message.Should().Contain("API request aborted before completion").And.NotContain("by the client");
        entry.Fields["ElapsedMs"].Should().BeOfType<long>().Which.Should().BeGreaterThanOrEqualTo(0);
        entry.Fields["request.id"].Should().Be("request-123");
        entry.Fields["trace.id"].Should().Be(activity.TraceId.ToString());
        entry.Fields["span.id"].Should().Be(activity.SpanId.ToString());
        entry.Fields.Should().NotContainKey("SupportReference");
        context.Response.Headers.Should().NotContainKey("X-Request-ID");
        entry.Fields["user.name"].Should().Be("test-user");
        entry.Fields.Should().NotContainKey("InnerScope");
        context.Response.Body.Length.Should().Be(0);
    }

    [Theory]
    [InlineData(false, false, false, 401)]
    [InlineData(true, false, false, 403)]
    [InlineData(true, true, false, 400)]
    [InlineData(true, true, true, 200)]
    public async Task Pipeline_logs_request_and_route_context_including_authorization_failures(
        bool authenticated, bool allowed, bool throws, int statusCode)
    {
        using var activity = new Activity("request").SetIdFormat(ActivityIdFormat.W3C).Start();
        var logger = new RecordingLogger<ApiFailureLoggingMiddleware>();
        var reachedEndpoint = false;
        var expected = new InvalidOperationException("Endpoint failed");
        await using var app = CreatePipeline(logger, ctx =>
        {
            reachedEndpoint = true;
            ctx.RequestServices.GetRequiredService<ILogger<ApiFailureLoggingMiddleware>>()
                .LogInformation("Inside endpoint");
            if (throws) throw expected;
            ctx.Response.StatusCode = 400;
            return Task.CompletedTask;
        });
        var context = Context("PUT");
        context.RequestServices = app.Services;
        context.Connection.RemoteIpAddress = IPAddress.Loopback;
        context.Request.Headers.UserAgent = "Logging test";
        if (authenticated) context.Request.Headers["X-Test-User"] = "test-user";
        if (allowed) context.Request.Headers["X-Test-Allowed"] = "true";
        context.SetEndpoint(new Endpoint(_ => Task.CompletedTask,
            new EndpointMetadataCollection(new AuthorizeAttribute("Allowed")), "Protected action"));
        context.Request.RouteValues["controller"] = "OrgR";
        context.Request.RouteValues["action"] = "CreateOrgR";
        context.Request.RouteValues["code"] = "AARE";

        var pipeline = ((IApplicationBuilder)app).Build();
        var error = await Record.ExceptionAsync(() => pipeline(context));

        error.Should().BeSameAs(throws ? expected : null);
        reachedEndpoint.Should().Be(allowed);
        context.Response.StatusCode.Should().Be(statusCode);
        var entry = logger.Entries.Should().ContainSingle(e => e.Message.StartsWith("API request")).Subject;
        entry.Level.Should().Be(throws ? LogLevel.Error : LogLevel.Warning);
        entry.Fields.Should().Contain("user.name", authenticated ? "test-user" : "anonymous")
            .And.Contain("request.id", "request-123")
            .And.Contain("trace.id", activity.TraceId.ToString())
            .And.Contain("span.id", activity.SpanId.ToString())
            .And.Contain("client.ip", "127.0.0.1").And.Contain("user_agent.original", "Logging test")
            .And.Contain("controller", "OrgR").And.Contain("action", "CreateOrgR").And.Contain("code", "AARE");
        if (reachedEndpoint)
        {
            var downstream = logger.Entries.Should().ContainSingle(e => e.Message == "Inside endpoint").Subject;
            foreach (var field in new[] { "user.name", "request.id", "trace.id", "span.id", "client.ip", "user_agent.original" })
            {
                downstream.Fields[field].Should().Be(entry.Fields[field]);
            }
        }
        app.Logger.LogInformation("Outside request");
        logger.Entries.Last().Fields.Should().NotContainKey("user.name").And.NotContainKey("code");
    }

    [Fact]
    public async Task Cookie_unprotect_exception_is_logged_before_request_context_middleware_runs()
    {
        using var activity = new Activity("request").SetIdFormat(ActivityIdFormat.W3C).Start();
        var logger = new RecordingLogger<ApiFailureLoggingMiddleware>();
        var expected = new InvalidOperationException("Ticket unprotect failed");
        var ticketFormat = new ThrowingTicketFormat(expected);
        var reachedEndpoint = false;
        await using var app = CreatePipeline(logger, _ =>
        {
            reachedEndpoint = true;
            return Task.CompletedTask;
        }, ticketFormat);
        var context = Context("GET");
        context.RequestServices = app.Services;
        context.Request.Headers.Cookie = "test-auth=nonempty-ticket";
        context.Request.Headers.UserAgent = "Cookie regression test";
        context.Connection.RemoteIpAddress = IPAddress.Loopback;
        context.Response.StatusCode = 202;
        context.Response.Headers["X-Existing"] = "preserved";
        await context.Response.WriteAsync("existing body");
        var originalHeaders = context.Response.Headers.ToDictionary(header => header.Key, header => header.Value);
        var pipeline = ((IApplicationBuilder)app).Build();

        var actual = await Record.ExceptionAsync(() => pipeline(context));

        actual.Should().BeSameAs(expected);
        ticketFormat.UnprotectCalls.Should().Be(1);
        reachedEndpoint.Should().BeFalse();
        var entry = logger.Entries.Should().ContainSingle(e => e.Message.StartsWith("API request")).Subject;
        entry.Level.Should().Be(LogLevel.Error);
        entry.Exception.Should().BeSameAs(expected);
        entry.Fields.Should().Contain("user.name", "anonymous").And.Contain("request.id", "request-123")
            .And.Contain("trace.id", activity.TraceId.ToString()).And.Contain("span.id", activity.SpanId.ToString())
            .And.Contain("client.ip", "127.0.0.1").And.Contain("user_agent.original", "Cookie regression test");
        context.Response.StatusCode.Should().Be(202);
        context.Response.Headers.Should().BeEquivalentTo(originalHeaders);
        context.Response.Body.Position = 0;
        (await new StreamReader(context.Response.Body).ReadToEndAsync()).Should().Be("existing body");
        app.Logger.LogInformation("Outside authentication failure");
        logger.Entries.Last().Fields.Should().NotContainKey("user.name").And.NotContainKey("request.id");
    }

    [Theory]
    [InlineData(false, "anonymous")]
    [InlineData(true, "authenticated")]
    public async Task Request_context_preserves_fallbacks_when_optional_values_are_absent(bool authenticated, string userName)
    {
        var previousActivity = Activity.Current;
        Activity.Current = null;
        try
        {
            var context = Context("GET");
            if (authenticated) context.User = new ClaimsPrincipal(new ClaimsIdentity([], "Test"));
            var logger = new RecordingLogger<ApiFailureLoggingMiddleware>();
            var middleware = new ApiFailureLoggingMiddleware(ctx =>
            {
                ctx.Response.StatusCode = 400;
                return Task.CompletedTask;
            }, logger);

            await middleware.InvokeAsync(context);

            var entry = logger.Entries.Should().ContainSingle().Subject;
            entry.Fields.Should().Contain("user.name", userName).And.Contain("request.id", "request-123")
                .And.Contain("trace.id", null).And.Contain("span.id", null)
                .And.Contain("client.ip", null).And.Contain("user_agent.original", "");
        }
        finally
        {
            Activity.Current = previousActivity;
        }
    }

    [Theory]
    [InlineData("GET", false)]
    [InlineData("GET", true)]
    [InlineData("POST", false)]
    [InlineData("POST", true)]
    public async Task Cancellation_without_request_abort_is_logged_as_error(string method, bool taskCanceled)
    {
        var context = Context(method);
        using var requestCancellation = new CancellationTokenSource();
        context.RequestAborted = requestCancellation.Token;
        context.Response.StatusCode = 202;
        context.Response.ContentType = "text/plain";
        context.Response.Headers["X-Existing"] = "preserved";
        await context.Response.WriteAsync("existing body");
        var originalHeaders = context.Response.Headers.ToDictionary(header => header.Key, header => header.Value);
        var logger = new RecordingLogger<ApiFailureLoggingMiddleware>();
        var dependencyToken = new CancellationToken(true);
        OperationCanceledException exception = taskCanceled
            ? new TaskCanceledException("Dependency canceled", null, dependencyToken)
            : new OperationCanceledException("Dependency canceled", dependencyToken);
        var middleware = new ApiFailureLoggingMiddleware(_ => Task.FromException(exception), logger);

        var act = () => middleware.InvokeAsync(context);
        (await act.Should().ThrowAsync<OperationCanceledException>()).Which.Should().BeSameAs(exception);

        var entry = logger.Entries.Should().ContainSingle().Subject;
        entry.Level.Should().Be(LogLevel.Error);
        entry.Message.Should().Contain("API request failed with an unhandled exception");
        entry.Fields["RequestAborted"].Should().Be(false);
        entry.Exception.Should().BeSameAs(exception);
        context.Response.StatusCode.Should().Be(202);
        context.Response.ContentType.Should().Be("text/plain");
        context.Response.Headers.Should().BeEquivalentTo(originalHeaders);
        context.Response.Body.Position = 0;
        (await new StreamReader(context.Response.Body).ReadToEndAsync()).Should().Be("existing body");
    }

    [Fact]
    public async Task Unexpected_exception_is_rethrown_without_rewriting_response()
    {
        var context = Context("POST");
        context.Request.ContentLength = 123;
        context.Response.StatusCode = 202;
        context.Response.ContentType = "text/plain";
        context.Response.Headers["X-Existing"] = "preserved";
        await context.Response.WriteAsync("existing body");
        var logger = new RecordingLogger<ApiFailureLoggingMiddleware>();
        var exception = new InvalidOperationException("original failure");
        var middleware = new ApiFailureLoggingMiddleware(_ => Task.FromException(exception), logger);

        var act = () => middleware.InvokeAsync(context);
        (await act.Should().ThrowAsync<InvalidOperationException>()).Which.Should().BeSameAs(exception);

        context.Response.StatusCode.Should().Be(202);
        context.Response.ContentType.Should().Be("text/plain");
        context.Response.Headers["X-Existing"].ToString().Should().Be("preserved");
        context.Response.Headers.Should().NotContainKey("X-Request-ID");
        context.Response.Body.Position = 0;
        (await new StreamReader(context.Response.Body).ReadToEndAsync()).Should().Be("existing body");
        var entry = logger.Entries.Should().ContainSingle().Subject;
        entry.Level.Should().Be(LogLevel.Error);
        entry.Exception.Should().BeSameAs(exception);
        entry.Fields["StatusCode"].Should().BeNull();
        entry.Fields["ContentLength"].Should().Be(123L);
        entry.Fields["Method"].Should().Be("POST");
        entry.Fields["Path"]?.ToString().Should().Be("/api/pgmprojects/import");
    }

    [Fact]
    public async Task Non_api_exception_is_passed_through_without_logging()
    {
        var context = Context("GET");
        context.Request.Path = "/health";
        var logger = new RecordingLogger<ApiFailureLoggingMiddleware>();
        var exception = new InvalidOperationException("failure");
        var middleware = new ApiFailureLoggingMiddleware(_ => Task.FromException(exception), logger);
        var act = () => middleware.InvokeAsync(context);
        (await act.Should().ThrowAsync<InvalidOperationException>()).Which.Should().BeSameAs(exception);
        logger.Entries.Should().BeEmpty();
        context.Response.Headers.Should().NotContainKey("X-Request-ID");
    }

    [Fact]
    public async Task Existing_validation_response_is_preserved()
    {
        var context = Context("POST");
        var logger = new RecordingLogger<ApiFailureLoggingMiddleware>();
        var middleware = new ApiFailureLoggingMiddleware(async ctx =>
        {
            ctx.Response.StatusCode = 409;
            await ctx.Response.WriteAsync("Choose a reporting period first.");
        }, logger);
        await middleware.InvokeAsync(context);
        context.Response.StatusCode.Should().Be(409);
        context.Response.Body.Position = 0;
        (await new StreamReader(context.Response.Body).ReadToEndAsync()).Should().Be("Choose a reporting period first.");
        logger.Entries.Should().ContainSingle(e => e.Level == LogLevel.Warning && e.Fields.ContainsKey("ElapsedMs"));
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task Does_not_change_response_after_start_or_disconnect(bool started)
    {
        var context = Context("POST");
        if (started) context.Features.Set<IHttpResponseFeature>(new StartedResponseFeature());
        else context.RequestAborted = new CancellationToken(true);
        var middleware = new ApiFailureLoggingMiddleware(_ => throw new InvalidOperationException("failure"), new RecordingLogger<ApiFailureLoggingMiddleware>());
        await FluentActions.Awaiting(() => middleware.InvokeAsync(context)).Should().ThrowAsync<InvalidOperationException>();
        context.Response.Body.Length.Should().Be(0);
    }

    private static DefaultHttpContext Context(string method)
    {
        var context = new DefaultHttpContext { TraceIdentifier = "request-123" };
        context.Request.Method = method;
        context.Request.Path = "/api/pgmprojects/import";
        context.Response.Body = new MemoryStream();
        context.RequestServices = new ServiceCollection().AddLogging().AddOptions().BuildServiceProvider();
        return context;
    }

    private sealed class StartedResponseFeature : HttpResponseFeature
    {
        public override bool HasStarted => true;
    }

    private static WebApplication CreatePipeline(RecordingLogger<ApiFailureLoggingMiddleware> logger, RequestDelegate endpoint,
        ISecureDataFormat<AuthenticationTicket>? ticketFormat = null)
    {
        var builder = WebApplication.CreateBuilder();
        builder.Logging.ClearProviders();
        builder.Logging.AddProvider(new TestLoggerProvider(logger));
        var authentication = builder.Services.AddAuthentication("Test");
        if (ticketFormat is null)
        {
            authentication.AddScheme<AuthenticationSchemeOptions, TestAuthenticationHandler>("Test", _ => { });
        }
        else
        {
            authentication.AddCookie("Test", options =>
            {
                options.Cookie.Name = "test-auth";
                options.TicketDataFormat = ticketFormat;
            });
        }
        builder.Services.AddAuthorization(options =>
            options.AddPolicy("Allowed", policy => policy.RequireAuthenticatedUser().RequireClaim("allowed", "true")));
        var app = builder.Build();
        app.UseApiFailureLogging();
        app.UseAuthentication();
        app.UseRequestContextLogging();
        app.UseAuthorization();
        app.Run(endpoint);
        return app;
    }

    private sealed class TestLoggerProvider(RecordingLogger<ApiFailureLoggingMiddleware> logger) : ILoggerProvider
    {
        public ILogger CreateLogger(string categoryName) => logger;
        public void Dispose() { }
    }

    private sealed class ThrowingTicketFormat(Exception exception) : ISecureDataFormat<AuthenticationTicket>
    {
        public int UnprotectCalls { get; private set; }
        public string Protect(AuthenticationTicket data) => throw new NotSupportedException();
        public string Protect(AuthenticationTicket data, string? purpose) => throw new NotSupportedException();
        public AuthenticationTicket? Unprotect(string? protectedText) => Unprotect(protectedText, null);
        public AuthenticationTicket? Unprotect(string? protectedText, string? purpose)
        {
            UnprotectCalls++;
            throw exception;
        }
    }

    private sealed class TestAuthenticationHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options, ILoggerFactory logger, UrlEncoder encoder)
        : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
    {
        protected override Task<AuthenticateResult> HandleAuthenticateAsync()
        {
            var name = Request.Headers["X-Test-User"].ToString();
            if (string.IsNullOrEmpty(name)) return Task.FromResult(AuthenticateResult.NoResult());
            var identity = new ClaimsIdentity([
                new Claim(ClaimTypes.Name, name),
                new Claim("allowed", Request.Headers["X-Test-Allowed"].ToString()),
            ], Scheme.Name);
            return Task.FromResult(AuthenticateResult.Success(
                new AuthenticationTicket(new ClaimsPrincipal(identity), Scheme.Name)));
        }
    }
}
