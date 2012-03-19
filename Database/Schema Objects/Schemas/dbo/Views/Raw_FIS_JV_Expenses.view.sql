
	CREATE VIEW [dbo].[Raw_FIS_JV_Expenses]
AS
SELECT  
	OrgCode AS Org, 
	AccountNum Account, 
	SubAccount, 
	ConsolidationCode AS ObjConsol, 
	SUM(Amount) AS Expenses
FROM    
	FISDataMart.dbo.BalanceSummaryView 
WHERE 
	Chart = '3'
	AND FiscalYear = 2011 
	AND TransBalanceType = 'AC'
	AND ConsolidationCode Not In ('INC0', 'BLSH', 'SB74')
	AND AnnualReportCode IN ('430200', '440201', '440205', '440210', '440211', '440219', '440221', '440222', '440223', '440224', '440225', '440227', '440229', '440231', '440232', '440233', '440240', '440246', '440247', '440248', '440251', '440287', '440290', '440319', '440352', '441016', '441020', '441035', '441038', '441092', '441096') 
	AND CollegeLevelOrg IN ('AAES', 'BIOS')
	AND TransDocType like 'JV'
GROUP BY 
	FiscalYear, 
	OrgCode, 
	AccountNum, 
	SubAccount, 
	ConsolidationCode
