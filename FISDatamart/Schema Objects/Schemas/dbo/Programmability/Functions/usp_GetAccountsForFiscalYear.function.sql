-- =============================================
-- Author:		Ken Taylor
-- Create date: February 23, 2011
-- Description:	Given a Fiscal Year, return a table of the corresponding 
-- Accounts for the '--' period.  This function is used when doing an 
-- in-memory setting of Transactions' IsCAES value because doing the join
-- in the Transaction download code is too slow.
-- =============================================
CREATE FUNCTION [dbo].[usp_GetAccountsForFiscalYear] 
(
	-- Add the parameters for the function here
	@FiscalYear int 
)
RETURNS 
@AccountsTable TABLE 
(
	-- Add the column definitions for the TABLE variable here
	   [Year] int not null
      ,[Chart] varchar(2) not null
      ,[Account] char(7) not null
      ,[AccountPK] varchar(17)
      ,[IsCAES] tinyint
)
AS
BEGIN
	-- Fill the table variable with the rows for your result set
	INSERT INTO @AccountsTable 

SELECT 
	Fiscal_Year, 
	Chart_Num,
	Account_Num,
	Account_PK,
	Is_CAES
	
FROM
		OPENQUERY (FIS_DS,
		'SELECT
			A.FISCAL_YEAR Fiscal_Year,
			A.FISCAL_PERIOD Fiscal_Period,
			A.CHART_NUM Chart_Num,
			A.ACCT_NUM Account_Num,
			(A.FISCAL_YEAR || ''|'' || A.FISCAL_PERIOD || ''|'' || A.CHART_NUM || ''|'' || A.ACCT_NUM) Account_PK,
			CASE 
					 WHEN (ORG_ID_LEVEL_2 = ''ACBS'' OR ORG_ID_LEVEL_5 = ''ACBS'') THEN 2
				     WHEN (ORG_ID_LEVEL_1 = ''BIOS'' OR ORG_ID_LEVEL_4 = ''BIOS'') THEN 0
				     ELSE 1 END AS Is_CAES
		FROM
			FINANCE.ORGANIZATION_ACCOUNT A 
			INNER JOIN FINANCE.ORGANIZATION_HIERARCHY O ON 
				A.FISCAL_YEAR = O.FISCAL_YEAR AND 
				A.FISCAL_PERIOD = O.FISCAL_PERIOD AND 
				A.CHART_NUM = O.CHART_NUM AND 
				A.ORG_ID = O.ORG_ID
		WHERE (
				(
					A.FISCAL_YEAR >= 2009 AND A.FISCAL_PERIOD = ''--''
				)	
				AND (
						(A.CHART_NUM, A.ORG_ID) IN 
						  (
							SELECT  DISTINCT CHART_NUM, ORG_ID 
							FROM FINANCE.ORGANIZATION_HIERARCHY O
							WHERE
							(
								(CHART_NUM_LEVEL_1=''3'' AND ORG_ID_LEVEL_1 = ''AAES'')
								OR
								(CHART_NUM_LEVEL_2=''L'' AND ORG_ID_LEVEL_2 = ''AAES'')
								
								OR
								(ORG_ID_LEVEL_1 = ''BIOS'')
								
								OR 
								(CHART_NUM_LEVEL_4 = ''3'' AND ORG_ID_LEVEL_4 = ''AAES'')
								OR
								(CHART_NUM_LEVEL_5 = ''L'' AND ORG_ID_LEVEL_5 = ''AAES'')
								
								OR
								(ORG_ID_LEVEL_4 = ''BIOS'')
							)
							AND
							(
								FISCAL_YEAR >= 2009
							)
						)
				)
			)
		')
		WHERE Fiscal_Year = @FiscalYear
	
	RETURN 
END
