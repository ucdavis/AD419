namespace Server.Models.AutoAssociations;

public sealed record AutoAssociationReportResponse<T>(string FiscalYear, DateOnly CycleStart, DateOnly CycleEnd, T Data);
public sealed record AutoAssociationBuildDto(int BuildId, DateOnly CycleStart, DateOnly CycleEnd, DateTime BuiltAt, int SummaryRows, int AssociationRows, int ExcludedProjects, int Misclassified204Rows);
public sealed record ExcludedProjectDto(string AccessionNumber, string NifaProjectNumber, string? Title, string? ProjectDirector, string? AeProjects, decimal Total);
public sealed record FteOverOneDto(string EmployeeId, string? EmployeeName, decimal Fte, int RowCount);
public sealed record PreAssociationTotalDto(string OrgR, string? FinancialDepartment, string? FinancialDepartmentName, string? ExpenseSfn, string? SfnLabel, decimal Expenses, decimal Fte);
public sealed record AssociatedProjectDto(string AccessionNumber, string NifaProjectNumber, string? Title, string? ProjectDirector, string? AeProjects, decimal Expenses, decimal Fte);
public sealed record UnassociatedExpenseDto(int ExpenseId, string Source, string? Project, string? Fund, string? FinancialDepartment, string OrgR, string? EmployeeId, string? EmployeeName, string? ExpenseSfn, decimal Expenses, decimal Fte, string Reason);
public sealed record Rule204ReportDto(IReadOnlyList<AssociatedProjectDto> Projects, IReadOnlyList<UnassociatedExpenseDto> Unassociated, IReadOnlyList<UnassociatedExpenseDto> Misclassified);
public sealed record Rule20xPiDto(string EmployeeId, string? EmployeeName, int ProjectCount, decimal Expenses, decimal Fte);
public sealed record Rule20xSfnDto(string Sfn, string? Label, decimal Expenses, decimal Fte, int ProjectCount, IReadOnlyList<Rule20xPiDto> Pis);
public sealed record Rule20xReportDto(IReadOnlyList<Rule20xSfnDto> Sfns, IReadOnlyList<UnassociatedExpenseDto> Unassociated);
public sealed record Rule220ReportDto(IReadOnlyList<AssociatedProjectDto> Projects, IReadOnlyList<UnassociatedExpenseDto> Unassociated);
