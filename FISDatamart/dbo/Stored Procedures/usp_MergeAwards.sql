
-- =============================================
-- Author:		Ken Taylor
-- Create date: December 13, 2019
-- Description:	Merges the Awards table so we can use it for figuring out
-- the Scientist Years and Cost Share Scientist Years.
--
-- Usage:
/*

USE [FISDataMart]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[usp_MergeAwards]
		@FiscalYear = 2018,
		@IsDebug = 1

SELECT	'Return Value' = @return_value

GO

*/
-- Modifications
--
-- =============================================
CREATE PROCEDURE [dbo].[usp_MergeAwards]
	@FiscalYear int = 2018, 
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    DECLARE @TSQL varchar(MAX) = ''

	SELECT @TSQL = '
MERGE [FISDataMart].[dbo].[Awards]  as target
USING (
SELECT * FROM OPENQUERY(FIS_DS, ''
SELECT FISCAL_YEAR, 
	FISCAL_PERIOD, 
	CGPRPSL_NBR, 
	UC_LOC_CD, 
	UC_FUND_NBR, 
	DS_LAST_UPDATE_DATE, 
	CGAWD_STAT_CD
FROM FINANCE.Award
WHERE FISCAL_YEAR = 9999 and FISCAL_PERIOD = ''''--''''
ORDER BY UC_FUND_NBR, UC_LOC_CD''
)
) AS source ON (
	target.[Year] = source.FISCAL_YEAR AND 
	target.[Period] = source.FISCAL_PERIOD AND 
	target.[CgprpslNum] = source.CGPRPSL_NBR
)
WHEN MATCHED THEN UPDATE SET
	[UcLocationCode]	= UC_LOC_CD, 
	[OpFundNum]			= UC_FUND_NBR,
	[LastUpdateDate]	= DS_LAST_UPDATE_DATE,
	[CgAwardsStatusCd]	= CGAWD_STAT_CD
	
WHEN NOT MATCHED BY TARGET THEN INSERT VALUES 
 (
	FISCAL_YEAR, 
	FISCAL_PERIOD, 
	CGPRPSL_NBR, 
	UC_LOC_CD, 
	UC_FUND_NBR, 
	DS_LAST_UPDATE_DATE, 
	CGAWD_STAT_CD
)
-- WHEN NOT MATCHED BY SOURCE THEN DELETE
;
'

	IF @IsDebug = 1  
		PRINT @TSQL
	ELSE 
		EXEC(@TSQL)
END