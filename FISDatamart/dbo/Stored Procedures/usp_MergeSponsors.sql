

-- =============================================
-- Author:		Ken Taylor
-- Create date: June 15, 2021
-- Description:	Merges the Sponsors table so we can use it for figuring out
-- the OpFund Expenses for the Federal Fiscal Year.
--
-- Usage:
/*

USE [FISDataMart]
GO

DECLARE	@return_value int, @IsDebug bit = 0

EXEC	@return_value = [dbo].[usp_MergeSponsors]
		@FiscalYear = 2021,
		@IsDebug = @IsDebug

IF @IsDebug = 0
	SELECT	'Return Value' = @return_value

GO

*/
-- Modifications
--
-- =============================================
CREATE PROCEDURE [dbo].[usp_MergeSponsors]
	@FiscalYear int = 2021, -- Not used.  Just present to keep consistant method signature.
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    DECLARE @TSQL varchar(MAX) = ''

	SELECT @TSQL = '
MERGE [FISDataMart].[dbo].[Sponsors]  as target
USING (
SELECT * FROM OPENQUERY(FIS_DS, ''
	SELECT
		SPONSOR_CODE            "SponsorCode",
		SPONSOR_CODE_NAME       "SponsorCodeName",
		FEDERAL_AGENCY_CODE     "FederalAgencyCode",
		SPONSOR_CATEGORY_CODE   "SponsorCategoryCode",
		SPONSOR_CATEGORY_NAME   "SponsorCategoryName",
		FOREIGN_SPONSOR_IND     "ForeignSponsorInd",
		UCOP_LAST_UPDATE_DATE   "UCOP_LastUpdateDate",
		TP_LAST_UPDATE_DATE     "TP_LastUpdateDate"
	FROM
		FINANCE.SPONSOR
	ORDER BY SPONSOR_CODE''
)
) AS source ON (
	target.[SponsorCode] = source.[SponsorCode]
)
WHEN MATCHED THEN UPDATE SET
	   [SponsorCodeName]	 = source.[SponsorCodeName]
      ,[FederalAgencyCode]	 = source.[FederalAgencyCode] 
      ,[SponsorCategoryCode] = source.[SponsorCategoryCode]
      ,[SponsorCategoryName] = source.[SponsorCategoryName]
      ,[ForeignSponsorInd]	 = source.[ForeignSponsorInd]
      ,[UCOP_LastUpdateDate] = source.[UCOP_LastUpdateDate]
      ,[TP_LastUpdateDate]	 = source.[TP_LastUpdateDate]
	
WHEN NOT MATCHED BY TARGET THEN INSERT VALUES 
 (
	   [SponsorCode]
      ,[SponsorCodeName]
      ,[FederalAgencyCode]
      ,[SponsorCategoryCode]
      ,[SponsorCategoryName]
      ,[ForeignSponsorInd]
      ,[UCOP_LastUpdateDate]
      ,[TP_LastUpdateDate]
)
-- WHEN NOT MATCHED BY SOURCE THEN DELETE
;
'

	IF @IsDebug = 1  
		PRINT @TSQL
	ELSE 
		EXEC(@TSQL)
END