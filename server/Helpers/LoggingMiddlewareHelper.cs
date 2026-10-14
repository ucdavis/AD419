namespace Server.Helpers;

public static class LoggingMiddlewareHelper
{
    public static void UseApiFailureLogging(this WebApplication app)
    {
        app.UseMiddleware<ApiFailureLoggingMiddleware>();
    }

    /// <summary>
    /// Adds request context enrichment middleware that includes trace info, user info, and client details in log scope
    /// </summary>
    public static void UseRequestContextLogging(this WebApplication app)
    {
        app.Use(async (ctx, next) =>
        {
            using (app.Logger.BeginScope(RequestLogContext.Create(ctx)))
            {
                await next();
            }
        });
    }
}
