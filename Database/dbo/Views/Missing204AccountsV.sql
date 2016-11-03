CREATE VIEW dbo.Missing204AccountsV
AS
SELECT t1.Chart, t1.Account, t2.IsExpired, t2.IsUCD 
FROM (
SELECT t1.Chart, t1.Account FROM [dbo].[AllAccountsFor204Projects] t1
	--WHERE IsUCD = 1 AND IsExpired = 0
	EXCEPT SELECT Chart, Account FROM ARCCodeAccountExclusions t3
	INNER JOIN CurrentFiscalYear t4 ON t3.Year = t4.FiscalYear
EXCEPT
SELECT DISTINCT Chart, Account FROM [dbo].[UFY_FFY_FIS_ExpensesWithSFN] t2 
WHERE SFN = '204') t1
INNER JOIN [dbo].[AllAccountsFor204Projects] t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account