CREATE VIEW Raw_FIS_JV_Expenses
AS
SELECT  
	OrgCode AS Org, 
	AccountNum Account, 
	SubAccount, 
	CASE WHEN OCR.ObjConsol IS NULL THEN BSV.ConsolidationCode ELSE OCR.ObjConsol END AS ObjConsol, 
	SUM(Amount) AS Expenses
FROM    
	FISDataMart.dbo.BalanceSummaryView BSV
LEFT OUTER JOIN [dbo].[ObjConsolRemap] OCR ON BSV.ObjectCode = OCR.Object AND BSV.ConsolidationCode = OldObjConsol
WHERE 
	Chart = '3'
	AND FiscalYear = 2012 
	AND TransBalanceType = 'AC'
	AND ConsolidationCode Not In ('INC0', 'BLSH', 'SB74')
	AND AnnualReportCode IN (SELECT ArcCode FROM FISDataMart.dbo.ArcCodes) 
	AND CollegeLevelOrg IN ('AAES', 'BIOS')
	AND TransDocType like 'JV'
GROUP BY 
	FiscalYear, 
	OrgCode, 
	AccountNum, 
	SubAccount, 
	ConsolidationCode,
	ObjConsol
