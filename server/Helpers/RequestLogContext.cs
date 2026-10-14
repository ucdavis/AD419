using System.Diagnostics;

namespace Server.Helpers;

internal static class RequestLogContext
{
    public static Dictionary<string, object?> Create(HttpContext context)
    {
        var activity = Activity.Current;
        var userName = context.User.Identity?.IsAuthenticated == true
            ? context.User.Identity.Name ?? "authenticated"
            : "anonymous";

        return new Dictionary<string, object?>
        {
            ["user.name"] = userName,
            ["request.id"] = context.TraceIdentifier,
            ["trace.id"] = activity?.TraceId.ToString(),
            ["span.id"] = activity?.SpanId.ToString(),
            ["client.ip"] = context.Connection.RemoteIpAddress?.ToString(),
            ["user_agent.original"] = context.Request.Headers.UserAgent.ToString(),
        };
    }
}
