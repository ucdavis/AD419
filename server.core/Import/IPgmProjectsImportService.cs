namespace Server.Core.Import;

public interface IPgmProjectsImportService
{
    /// <summary>
    /// Replaces the contents of [data].[PGMProjects] with project-grain rows pulled from the
    /// ae_dwh warehouse, selecting each project's budget period as of <paramref name="reportDate"/>.
    /// </summary>
    Task<PgmProjectsImportResult> ImportAsync(DateOnly reportDate, CancellationToken cancellationToken = default);
}

public sealed record PgmProjectsImportResult(int RowsImported, DateOnly ReportDate);
