using System.Diagnostics;
using System.Security.Claims;
using FluentAssertions;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
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
        var middleware = new ApiFailureLoggingMiddleware(ctx =>
        {
            using var inner = logger.BeginScope(new Dictionary<string, object?> { ["InnerScope"] = true });
            ctx.User = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.Name, "test-user")], "test"));
            cancellation.Cancel();
            return Task.FromException(exception);
        }, logger);

        var act = () => middleware.InvokeAsync(context);
        (await act.Should().ThrowAsync<OperationCanceledException>()).Which.Should().BeSameAs(exception);
        var entry = logger.Entries.Should().ContainSingle().Subject;
        entry.Level.Should().Be(level);
        entry.Fields["RequestAborted"].Should().Be(true);
        entry.Message.Should().Contain("API request aborted before completion").And.NotContain("by the client");
        entry.Fields["ElapsedMs"].Should().BeOfType<long>().Which.Should().BeGreaterThanOrEqualTo(0);
        entry.Fields["request.id"].Should().Be("request-123");
        entry.Fields["trace.id"].Should().Be(activity.TraceId.ToString());
        entry.Fields.Should().NotContainKey("SupportReference");
        context.Response.Headers.Should().NotContainKey("X-Request-ID");
        entry.Fields["user.name"].Should().Be("test-user");
        entry.Fields.Should().NotContainKey("InnerScope");
        context.Response.Body.Length.Should().Be(0);
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
}
