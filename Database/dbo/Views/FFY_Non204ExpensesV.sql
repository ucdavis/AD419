CREATE VIEW dbo.FFY_Non204ExpensesV
AS
SELECT        Id, Chart, Account, SubAccount, PrincipalInvestigator, AnnualReportCode, OpFundNum, ConsolidationCode, TransDocType, OrgR, Org, SFN, Expenses
FROM            dbo.UFY_FFY_FIS_ExpensesWithSFN AS t1
WHERE        (SFN NOT LIKE '204')