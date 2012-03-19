-- =============================================
-- Author:		Ken Taylor
-- Create date: 2010-07-01
-- Description:	Download all of the Object Sub Types From DaFIS
-- This table contains only 43 records, so we're just going to truncate the 
-- table and reload, which takes about less than 1 second to run the whole process.
-- =============================================
CREATE PROCEDURE [dbo].[usp_DownloadObjectSubTypes] 
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
Print ''-- Truncating table [dbo].[ObjectSubTypes]...''
TRUNCATE TABLE [dbo].[ObjectSubTypes]

Print ''-- Reloading table [dbo].[ObjectSubTypes]...''
INSERT INTO [FISDataMart].[dbo].[ObjectSubTypes]
(
	   [ObjectSubType]
      ,[ObjectSubTypeName]
      ,[LastUpdateDate]
)

SELECT [ObjectSubType]
      ,[ObjectSubTypeName]
      ,[LastUpdateDate]
FROM OPENQUERY(FIS_DS, 
	''SELECT 
		OBJECT_SUB_TYPE_CODE OBJECTSUBTYPE,
		OBJECT_SUB_TYPE_NAME OBJECTSUBTYPENAME,
		DS_LAST_UPDATE_DATE LASTUPDATEDATE
	FROM FINANCE.OBJECT_SUB_TYPE
	ORDER BY OBJECTSUBTYPE
'')
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
