

-- =============================================
-- Author:		Ken Taylor
-- Create date: June 15, 2021
-- Description:	Merges the OpFundInvestigator table so we can use it for figuring out
-- the OpFund Expenses for the Federal Fiscal Year.
--
-- Usage:
/*

USE [FISDataMart]
GO

DECLARE	@return_value int, @IsDebug bit = 1

EXEC	@return_value = [dbo].[usp_MergeOpFundInvestigator]
		@FiscalYear = 2020,
		@IsDebug = @IsDebug

IF @IsDebug = 0
	SELECT	'Return Value' = @return_value

GO

*/
-- Modifications
--
-- =============================================
CREATE PROCEDURE [dbo].[usp_MergeOpFundInvestigator]
	@FiscalYear int = 2020,
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    DECLARE @TSQL varchar(MAX) = ''

	SELECT @TSQL = '
MERGE [dbo].[OpFundInvestigator]  as target
USING (
SELECT * FROM OPENQUERY(FIS_DS, ''
	SELECT
		FISCAL_YEAR "Year",
		FISCAL_PERIOD "Period",
		OP_LOCATION_CODE "OpLocationCode",
		OP_FUND_NUM "OpFundNum",
		OP_FUND_INVESTIGATOR_NUM "OpFundInvestigatorNum",
		INVESTIGATOR_TYPE_CODE "InvestigatorTypeCode",
		INVESTIGATOR_DAFIS_USER_ID "InvestigatorDaFisUserId",
		INVESTIGATOR_USER_ID "InvestigatorUserId",
		INVESTIGATOR_NAME "InvestigatorName",
		CHART_NUM "Chart",
		ORG_ID "OrgId",
		CONTACT_IND "ContactInd",
		RESPONSIBLE_IND "ResponsibleInd",
		DS_LAST_UPDATE_DATE "LastUpdateDate"
	FROM
		FINANCE.OP_FUND_INVESTIGATOR
	WHERE FISCAL_YEAR >= ' + CONVERT(char(4), @FiscalYear)  + '
	ORDER BY "Year" DESC, "Period", "OpLocationCode", "OpFundNum", "OpFundInvestigatorNum"
'')
) AS source ON (
	   target.[Year]				  = source.[Year] AND
       target.[Period]				  = source.[Period] AND
       target.[OpLocationCode]		  = source.[OpLocationCode] AND
       target.[OpFundNum]			  = source.[OpFundNum] AND
       target.[OpFundInvestigatorNum] = source.[OpFundInvestigatorNum]
)
WHEN MATCHED THEN UPDATE SET
	   [InvestigatorTypeCode]		= source.[InvestigatorTypeCode]
      ,[InvestigatorDaFisUserId]	= source.[InvestigatorDaFisUserId]
      ,[InvestigatorUserId]			= source.[InvestigatorUserId]
      ,[InvestigatorName]			= source.[InvestigatorName]
      ,[Chart]						= source.[Chart]	
      ,[OrgId]						= source.[OrgId]
      ,[ContactInd]					= source.[ContactInd]	
      ,[ResponsibleInd]				= source.[ResponsibleInd]	
      ,[LastUpdateDate]				= source.[LastUpdateDate]	
	
WHEN NOT MATCHED BY TARGET THEN INSERT VALUES 
 (
	   [Year]
      ,[Period]
      ,[OpLocationCode]
      ,[OpFundNum]
      ,[OpFundInvestigatorNum]
      ,[InvestigatorTypeCode]
      ,[InvestigatorDaFisUserId]
      ,[InvestigatorUserId]
      ,[InvestigatorName]
      ,[Chart]
      ,[OrgId]
      ,[ContactInd]
      ,[ResponsibleInd]
      ,[LastUpdateDate]
)
-- WHEN NOT MATCHED BY SOURCE THEN DELETE
;
'

	IF @IsDebug = 1  
		PRINT @TSQL
	ELSE 
		EXEC(@TSQL)
END