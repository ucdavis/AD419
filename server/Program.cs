using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Server.Authorization;
using Server.Controllers;
using Server.Core.Data;
using Server.Import;
using Server.Core.Import;
using Server.Core.Notification;
using Server.ExpenseReview;
using Server.Helpers;
using Server.ProjectIdentification;
using Server.ProjectList;
using Server.Workflow;

var builder = WebApplication.CreateBuilder(args);

// setup configuration sources (last one wins)
builder.Configuration
    .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
    .AddJsonFile($"appsettings.{builder.Environment.EnvironmentName}.json", optional: true, reloadOnChange: true)
    .AddEnvFile(".env", optional: true) // secrets stored here
    .AddEnvFile($".env.{builder.Environment.EnvironmentName}", optional: true) // env-specific secrets
    .AddEnvironmentVariables(); // OS env vars override everything

// setup logging and telemetry
TelemetryHelper.ConfigureLogging(builder.Logging);
TelemetryHelper.ConfigureOpenTelemetry(builder.Services);

// handy for getting true client IP
builder.Services.Configure<ForwardedHeadersOptions>(o =>
{
    o.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
});

// Add auth config (entra)
builder.Services.AddAuthenticationServices(builder.Configuration);
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy(AuthorizationPolicies.AuthorizedUser, policy =>
    {
        policy.RequireAuthenticatedUser();
        policy.Requirements.Add(new AuthorizedUserRequirement());
    });
});

builder.Services.AddControllers();
builder.Services.AddNotificationServices(builder.Configuration);

// Add response caching for pages that opt-in
// https://learn.microsoft.com/en-us/aspnet/core/performance/caching/middleware?view=aspnetcore-9.0
builder.Services.AddResponseCaching();

// add scoped services here
builder.Services.AddScoped<IDbInitializer, DbInitializer>();
builder.Services.AddScoped<IAuthorizationHandler, AuthorizedUserHandler>();
builder.Services.AddScoped<IPgmProjectsImportService, PgmProjectsImportService>();
builder.Services.AddSingleton<IFlatFileImportRegistry, FlatFileImportRegistry>();
builder.Services.AddScoped<IFlatFileImportService, FlatFileImportService>();
builder.Services.AddScoped<IProjectIdentificationService, ProjectIdentificationService>();
builder.Services.AddScoped<IProjectListService, ProjectListService>();
builder.Services.AddScoped<IExpenseReviewService, ExpenseReviewService>();
builder.Services.AddScoped<IWorkflowService, WorkflowService>();
builder.Services.AddScoped<ImportRunOrchestrator>();
builder.Services.AddSingleton<IImportRunStarter, ImportRunStarter>();
builder.Services.AddScoped<ChartSegmentsImportService>();
builder.Services.AddScoped<AeTransactionsImportService>();
builder.Services.AddScoped<UcPathTransactionsImportService>();
builder.Services.AddScoped<SprocStageService>();
builder.Services.AddScoped<IImportReadinessCheck, ImportReadinessCheck>();
builder.Services.AddScoped<IImportStageProvider, ImportStageProvider>();
// add auth policies here

// add db context (check secrets first, then config, then default)
var conn = builder.Configuration["DB_CONNECTION"]
            ?? builder.Configuration.GetConnectionString("DefaultConnection");

if (string.IsNullOrWhiteSpace(conn))
{
    const string message = "No database connection string configured. Set the DB_CONNECTION environment variable or " +
                           "configure ConnectionStrings:DefaultConnection. For host-based local development use " +
                           "Server=localhost,14333;Database=AppDb;User ID=sa;Password=LocalDev123!;Encrypt=False;TrustServerCertificate=True;. " +
                           "Inside the DevContainer use Server=sql,1433;Database=AppDb;User ID=sa;Password=LocalDev123!;Encrypt=False;TrustServerCertificate=True;.";

    throw new InvalidOperationException(message);
}

builder.Services.AddDbContextPool<AppDbContext>(o => o.UseSqlServer(conn, opt => opt
    .MigrationsAssembly("server.core")
    .MigrationsHistoryTable(AppDbContext.MigrationsHistoryTable, AppDbContext.AppSchema)));

var dataConn = DataDbConnection.Resolve(builder.Configuration, conn);
builder.Services.AddDbContextPool<DataDbContext>(o => o.UseSqlServer(dataConn));

builder.Services
    .AddHealthChecks()
    .AddDbContextCheck<AppDbContext>()
    .AddDbContextCheck<DataDbContext>("data_db");

// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// configure data protection (generated keys for auth and such)
var keysPath = Path.Combine(builder.Environment.ContentRootPath, "..", ".aspnet", "DataProtection-Keys");
Directory.CreateDirectory(keysPath);

builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo(keysPath));

var app = builder.Build();

await StartupLogging.RunAsync(app, async cancellationToken =>
{
    // do db migrations at startup
    using (var scope = app.Services.CreateScope())
    {
        var init = scope.ServiceProvider.GetRequiredService<IDbInitializer>();
        var env = scope.ServiceProvider.GetRequiredService<IHostEnvironment>();
        await init.InitializeAsync(env.IsDevelopment());
    }

    app.UseForwardedHeaders();

    app.UseStaticFiles();

    app.UseResponseCaching();

    // Configure the HTTP request pipeline.
    if (app.Environment.IsDevelopment())
    {
        // swagger only in development
        app.UseSwagger();
        app.UseSwaggerUI();
    }
    else
    {
        app.UseDefaultFiles();

        // only use HTTPS redirection in non-development environments
        app.UseHttpsRedirection();
    }


    app.UseApiFailureLogging();
    app.UseAuthentication();
    app.UseAuthorization();

    // enrich every log with request context
    app.UseRequestContextLogging();

    // app.UseHttpLogging(); // if you want extra logging. It's a little overkill though with the current logging setup

    app.MapControllers();

    var healthEndpoint = app.MapHealthChecks("/health");

    // Cache the health check response for 10 seconds to protect the database from rapid polling.
    healthEndpoint.WithMetadata(new ResponseCacheAttribute
    {
        Duration = 10,
        Location = ResponseCacheLocation.Any,
        NoStore = false,
    });


    if (!app.Environment.IsDevelopment())
    {
        // In production, fallback to index.html for SPA routing
        app.MapFallbackToFile("/index.html");
    }

    await app.RunAsync(cancellationToken);
});
