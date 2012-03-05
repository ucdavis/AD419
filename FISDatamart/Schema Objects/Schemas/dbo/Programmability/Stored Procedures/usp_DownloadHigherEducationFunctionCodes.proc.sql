-- =============================================
-- Author:		Ken Taylor
-- Create date: 2010-07-01
-- Description:	Download all of the Higher Education Function Codes From DaFIS
-- This table contains only 19 records, so we're just going to truncate the 
-- table and reload, which takes about 5 seconds to run the whole process.
-- =============================================
CREATE PROCEDURE [dbo].[usp_DownloadHigherEducationFunctionCodes] 
	-- Add the parameters for the stored procedure here
	@IsDebug bit = 0 -- Set to 1 to display SQL only.
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	--SET NOCOUNT ON;

    -- Insert statements for procedure here
	DECLARE @TSQL varchar(max) = ''
	
	SELECT @TSQL = '
Print ''-- Truncating table dbo.HigherEducationFunctionCodes...''
TRUNCATE TABLE dbo.HigherEducationFunctionCodes
	
Print ''-- Reloading table dbo.HigherEducationFunctionCodes...''
INSERT INTO dbo.HigherEducationFunctionCodes (
	[HigherEducationFunctionCode]
   ,[HigherEducationFunctionName]
   ,[LastUpdateDate])
SELECT 
	HIGHER_ED_FUNC_CODE, 
	HIGHER_ED_FUNC_NAME, 
	DS_LAST_UPDATE_DATE from OPENQUERY (FIS_DS,
		''SELECT 
			HIGHER_ED_FUNC_CODE, 
			HIGHER_ED_FUNC_NAME, 
			DS_LAST_UPDATE_DATE
		from FINANCE.higher_ed_function_code
		ORDER BY higher_ed_func_code'')
		'
		
	If @IsDebug = 1 
	BEGIN
		Print @TSQL
	END
	ELSE
	BEGIN
		EXEC(@TSQL)
	END
END
