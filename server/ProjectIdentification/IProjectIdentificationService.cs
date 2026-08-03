using System.Security.Claims;
using Server.Core.Import;
using Server.Models.ProjectIdentification;

namespace Server.ProjectIdentification;

public interface IProjectIdentificationService
{
    Task<ProjectIdentificationSetupResponse> GetSetupAsync(
        ClaimsPrincipal user,
        CancellationToken cancellationToken);

    Task<ProjectIdentificationSetupResponse?> ConfirmFiscalPeriodAsync(
        string? fiscalYear,
        ClaimsPrincipal user,
        CancellationToken cancellationToken);

    Task<ProjectIdentificationSetupResponse?> SetChecklistItemCompletionAsync(
        string itemId,
        bool completed,
        ClaimsPrincipal user,
        CancellationToken cancellationToken);

    Task<ProjectIdentificationSetupResponse?> FinalizeProjectsAsync(
        ClaimsPrincipal user,
        CancellationToken cancellationToken);

    Task RecordPgmImportAsync(
        PgmProjectsImportResult result,
        ClaimsPrincipal user,
        CancellationToken cancellationToken);
}
