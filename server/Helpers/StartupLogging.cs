namespace Server.Helpers;

public static class StartupLogging
{
    public static Task RunAsync(WebApplication app, Func<Task> startup)
    {
        ArgumentNullException.ThrowIfNull(app);
        ArgumentNullException.ThrowIfNull(startup);

        return RunAsync(app, _ => startup(), CancellationToken.None);
    }

    public static async Task RunAsync(WebApplication app, Func<CancellationToken, Task> startup, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(app);
        ArgumentNullException.ThrowIfNull(startup);

        try
        {
            await startup(cancellationToken);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception ex)
        {
            app.Logger.LogCritical(ex, "Application failed during startup.");

            throw;
        }
        finally
        {
            // Disposing the host shuts down OpenTelemetry log processors and drains pending exports.
            await app.DisposeAsync();
        }
    }
}
