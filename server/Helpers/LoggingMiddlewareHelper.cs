using System.Diagnostics;

namespace Server.Helpers;

public static class LoggingMiddlewareHelper
{
    public static void UseApiFailureLogging(this WebApplication app)
    {
        app.Use(async (ctx, next) =>
        {
            try
            {
                await next();
            }
            catch (OperationCanceledException ex)
                when (ctx.Request.Path.StartsWithSegments("/api") && ctx.RequestAborted.IsCancellationRequested)
            {
                app.Logger.LogInformation(
                    ex,
                    "API request was canceled by the client: {Method} {Path}. ContentLength={ContentLength}.",
                    ctx.Request.Method,
                    ctx.Request.Path,
                    ctx.Request.ContentLength);
                throw;
            }
            catch (Exception ex) when (ctx.Request.Path.StartsWithSegments("/api"))
            {
                app.Logger.LogError(
                    ex,
                    "API request failed with an unhandled exception: {Method} {Path}. ContentLength={ContentLength}.",
                    ctx.Request.Method,
                    ctx.Request.Path,
                    ctx.Request.ContentLength);
                throw;
            }

            if (ctx.Request.Path.StartsWithSegments("/api") && ctx.Response.StatusCode >= 400)
            {
                app.Logger.LogWarning(
                    "API request completed with status {StatusCode}: {Method} {Path}. ContentLength={ContentLength}.",
                    ctx.Response.StatusCode,
                    ctx.Request.Method,
                    ctx.Request.Path,
                    ctx.Request.ContentLength);
            }
        });
    }

    /// <summary>
    /// Adds request context enrichment middleware that includes trace info, user info, and client details in log scope
    /// </summary>
    public static void UseRequestContextLogging(this WebApplication app)
    {
        app.Use(async (ctx, next) =>
        {
            // ASP.NET's intrinsic request id + W3C trace context
            var requestId = ctx.TraceIdentifier;
            var activity = Activity.Current;
            var traceId = activity?.TraceId.ToString();
            var spanId = activity?.SpanId.ToString();

            // user info (name/ID if authenticated)
            var userName = ctx.User.Identity?.IsAuthenticated == true
                ? (ctx.User.Identity?.Name ?? "authenticated")
                : "anonymous";

            // client IP (respects ForwardedHeaders above)
            var clientIp = ctx.Connection.RemoteIpAddress?.ToString();

            // user agent
            var ua = ctx.Request.Headers.UserAgent.ToString();

            // Make these available to all logs in this request
            using (app.Logger.BeginScope(new Dictionary<string, object?>
            {
                ["user.name"] = userName,
                ["request.id"] = requestId,
                ["trace.id"] = traceId,
                ["span.id"] = spanId,
                ["client.ip"] = clientIp,
                ["user_agent.original"] = ua
            }))
            {
                await next();
            }
        });
    }
}
