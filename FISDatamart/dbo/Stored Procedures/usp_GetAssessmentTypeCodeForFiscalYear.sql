-- =============================================
-- Author:		Ken Taylor
-- Create date: March 5, 2014
-- Description:	Given a comma delimited list of SubFundNumbers and FiscalYear, 
-- return a corresponding list of Assessment Type Codes per Account
-- Usage:
/*
USE [FISDataMart]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[usp_GetAssessmentTypeCodeForFiscalYear]
		@FiscalYear = N'2014',
		@SubFundGroupNumsString = 'SSEDAC',
		@IsDebug = 0

SELECT	'Return Value' = @return_value

GO
*/
-- =============================================
CREATE PROCEDURE [dbo].[usp_GetAssessmentTypeCodeForFiscalYear] 
	-- Add the parameters for the stored procedure here
	@FiscalYear varchar(4) = '9999', 
	@SubFundGroupNumsString varchar(MAX) = '',
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

   DECLARE @TSQL varchar(max) = ''
	SELECT @TSQL = '
	SELECT DISTINCT 
	t1.Chart CHART_NUM, t1.SubFundGroupNum, t2.OrgR, t1.Org, t1.Account ACCT_NUM , t1.TypeCode, t3.Assessment_Type_Code, t3.Active_Ind, t3.TP_Acct_Assmnt_Update_Date
	FROM Accounts t1
	INNER JOIN OrganizationsV t2 ON t1.Year = t2.year AND t1.Chart = t2.Chart AND t1.Period = t2.Period AND t1.Org = t2.Org
	LEFT OUTER JOIN (
	 SELECT * from openquery(OPP_FIS, ''SELECT * FROM FINANCE.ORG_ACCOUNT_ASSESSMENT where ACTIVE_IND = ''''Y'''' AND FISCAL_YEAR >= '+ @FiscalYear + '
	'')
	) t3 ON t1.Account = t3.ACCT_NUM AND t1.Chart = t3.CHART_NUM AND t1.Year = t3.FISCAL_YEAR 
	WHERE t1.IsCAES = 1 AND t1.Year >= ' + @FiscalYear

	IF @SubFundGroupNumsString IS NOT NULL AND @SubFundGroupNumsString NOT LIKE '' 
		SELECT @TSQL += '
	AND SubFundGroupNum IN (Select * FROM [dbo].[SplitVarcharValues](''' + @SubFundGroupNumsString + '''))'

	SELECT @TSQL += '
	AND (t1.ExpirationDate IS NULL OR (t1.ExpirationDate IS NOT NULL AND t1.ExpirationDate >= GETDATE())) 
	AND TypeCode NOT IN (''UB'', ''PR'', ''BS'')
	ORDER BY t1.Chart, SubFundGroupNum, OrgR, t1.Org, Account, Assessment_Type_Code, TypeCode, 
	TP_Acct_Assmnt_Update_Date, t3.Active_Ind'

	IF @IsDebug = 1 
		PRINT @TSQL
	ELSE
		EXEC (@TSQL)
END