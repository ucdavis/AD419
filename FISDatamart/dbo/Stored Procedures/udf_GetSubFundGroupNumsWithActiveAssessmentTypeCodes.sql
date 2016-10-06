-- =============================================
-- Author:		Ken Taylor
-- Create date: March 7, 2014
-- Description:	Given a Fiscal Year, return a list of sub fund groups 
-- with Accounts having active Assessment Type Codes
-- Usage:
/*
USE [FISDataMart]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[udf_GetSubFundGroupNumsWithActiveAssessmentTypeCodes]
		@FiscalYear = N'2014',
		@IsDebug = 0

SELECT	'Return Value' = @return_value

GO
*/
-- =============================================
CREATE PROCEDURE udf_GetSubFundGroupNumsWithActiveAssessmentTypeCodes 
	-- Add the parameters for the stored procedure here
	@FiscalYear varchar(4) = '2014', 
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @TSQL varchar(max) = ''
	SELECT @TSQL = '
	select DISTINCT t2.SubFundGroupNum from openquery(FIS_DS, ''SELECT * FROM FINANCE.ORG_ACCOUNT_ASSESSMENT where ACTIVE_IND = ''''Y'''' AND FISCAL_YEAR = ' + @FiscalYear +'
	'') t1
	INNER JOIN Accounts t2 ON t1.ACCT_NUM = t2.Account AND t1.CHart_NUM = t2.CHart AND t1.FISCAL_YEAR = t2.Year
	INNER JOIN OrganizationsV t3 ON t2.Year = t3.year AND t2.Org = t3.Org and t2.Chart = t3.Chart AND t2.Period = t3.Period
	WHERE t2.IsCAES = 1 
	ORDER BY 1
	'

	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC (@TSQL)
END