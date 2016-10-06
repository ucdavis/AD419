CREATE VIEW dbo.NonExpiredMissing204AccountsV
AS
SELECT t1.Chart, t1.Account FROM [AD419].[dbo].[AllAccountsFor204Projects] t1
	WHERE IsUCD = 1 AND IsExpired = 0
	EXCEPT SELECT Chart, Account FROM ARCCodeAccountExclusions t3
	INNER JOIN CurrentFiscalYear t4 ON t3.Year = t4.FiscalYear
EXCEPT
SELECT DISTINCT Chart, Account FROM [dbo].[UFY_FFY_FIS_ExpensesWithSFN] t2 
WHERE SFN = '204'