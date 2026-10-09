using System.Diagnostics;

namespace Server.Helpers;

public sealed class ApiFailureLoggingMiddleware(RequestDelegate next, ILogger<ApiFailureLoggingMiddleware> logger)
{
    public async Task InvokeAsync(HttpContext context)
    {
        if (!context.Request.Path.StartsWithSegments("/api"))
        {
            await next(context);
            return;
        }

        var elapsed = Stopwatch.StartNew();
        try
        {
            await next(context);
        }
        catch (OperationCanceledException ex) when (context.RequestAborted.IsCancellationRequested)
        {
            LogFailure(context, CancellationLevel(context), ex, "API request aborted before completion", elapsed);
            throw;
        }
        catch (Exception ex)
        {
            LogFailure(context, LogLevel.Error, ex, "API request failed with an unhandled exception", elapsed);
            throw;
        }

        if (context.Response.StatusCode >= 400)
        {
            LogFailure(context, LogLevel.Warning, null, "API request completed unsuccessfully", elapsed);
        }
    }

    private void LogFailure(HttpContext context, LogLevel level, Exception? exception, string outcome, Stopwatch elapsed)
    {
        using var routeScope = logger.BeginScope(context.Request.RouteValues);
        using var bodyScope = logger.BeginScope(ApiOperationContext.Get(context));
        logger.Log(level, exception,
            "{Outcome}: {Method} {Path}. ElapsedMs={ElapsedMs}, StatusCode={StatusCode}, RequestAborted={RequestAborted}, ContentLength={ContentLength}.",
            outcome, context.Request.Method, context.Request.Path, elapsed.ElapsedMilliseconds,
            exception is null || context.Response.HasStarted ? context.Response.StatusCode : (int?)null,
            context.RequestAborted.IsCancellationRequested, context.Request.ContentLength);
    }

    private static LogLevel CancellationLevel(HttpContext context) =>
        HttpMethods.IsPost(context.Request.Method) || HttpMethods.IsPut(context.Request.Method)
        || HttpMethods.IsPatch(context.Request.Method) || HttpMethods.IsDelete(context.Request.Method)
            ? LogLevel.Warning : LogLevel.Information;
}
