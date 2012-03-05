-- =============================================
-- Author:		Ken Taylor
-- Create date: 2010-07-01
-- Description:	Download all of the Object Types From DaFIS
-- This table contains only 15 records, so we're just going to truncate the 
-- table and reload, which takes about less than 1 second to run the whole process.
-- =============================================
CREATE PROCEDURE [dbo].[usp_DownloadObjectTypes] 
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
Print ''-- Truncating table [dbo].[ObjectTypes]...''
TRUNCATE TABLE [dbo].[ObjectTypes]

Print ''-- Reloading table [dbo].[ObjectTypes]...''
INSERT INTO [FISDataMart].[dbo].[ObjectTypes]
(
	   [ObjectType]
      ,[ObjectTypeName]
      ,[LastUpdateDate]
)

SELECT [ObjectType]
      ,[ObjectTypeName]
      ,[LastUpdateDate]
FROM OPENQUERY(FIS_DS, 
	''SELECT 
		OBJECT_TYPE_CODE OBJECTTYPE,
		OBJECT_TYPE_NAME OBJECTTYPENAME,
		DS_LAST_UPDATE_DATE LASTUPDATEDATE
	FROM FINANCE.OBJECT_TYPE
	ORDER BY OBJECTTYPE
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
