-- =============================================
-- Author:		Ken Taylor
-- Create date: 02-Jun-2010
-- Description:	Returns a list of Object Consolidatn Codes and  
-- their corresponding Level for use with Report Builder, etc.
-- =============================================
CREATE FUNCTION [dbo].[udf_ObjectLevelCodesList] 
(
	-- Add the parameters for the function here
	@AddWildcard bit = 0, -- 0: Do NOT add wildcard ('%') (default); 1: Add wildcard.
	@ReturnInactiveAlso bit = 1 -- 1: Return ALL Objects Consolidation Codes and their 
	-- associated levels (default); 0: Return only those with records where the 
	-- LevelActiveInd = 'Y'.
)
RETURNS 
@MyTable TABLE 
(
	-- Add the column definitions for the TABLE variable here
	ConsolidatnCode varchar(4), 
	ConsolidatnName varchar(40),
	ConsolidatnShortName char(12), 
	ObjectLevel varchar(100), 
	LevelCode varchar(4), 
	LevelName varchar(40), 
	ObjectLevelShortName char(12),
	LevelActiveInd char(1)
)
AS
BEGIN
	-- Fill the table variable with the rows for your result set
	
	If @AddWildcard = 1
		BEGIN
			Insert into @MyTable (
				ConsolidatnCode, 
				ConsolidatnName, 
				ConsolidatnShortName, 
				ObjectLevel, 
				LevelCode, 
				LevelName, 
				ObjectLevelShortName,
				LevelActiveInd
				) VALUES ('%', '%', '%', '%', '%', '%', '%', 'Y')
		END
		
		If @ReturnInactiveAlso = 1
		BEGIN
			Insert into @MyTable (ConsolidatnCode, ConsolidatnName, ConsolidatnShortName, ObjectLevel , LevelCode, LevelName, ObjectLevelShortName, LevelActiveInd)
			Select distinct ConsolidatnCode, ConsolidatnName, ConsolidatnShortName, (ConsolidatnCode + ': ' + LevelCode + ' - ' +  LevelName) AS ObjectLevel, LevelCode, LevelName, ObjectLevelShortName, LevelActiveInd
			From dbo.Objects
			Where Year = 9999
			Group by ConsolidatnCode, ConsolidatnName, ConsolidatnShortName, LevelCode, LevelName, ObjectLevelShortName, LevelActiveInd
			Order by ConsolidatnCode, ConsolidatnName, ConsolidatnShortName, LevelCode, LevelName, ObjectLevelShortName, LevelActiveInd
		END
	Else
		BEGIN
			Insert into @MyTable (ConsolidatnCode, ConsolidatnName, ConsolidatnShortName, ObjectLevel , LevelCode, LevelName, ObjectLevelShortName, LevelActiveInd)
			Select distinct ConsolidatnCode, ConsolidatnName, ConsolidatnShortName, (ConsolidatnCode + ': ' + LevelCode + ' - ' +  LevelName) AS ObjectLevel, LevelCode, LevelName, ObjectLevelShortName, LevelActiveInd
			From dbo.Objects
			Where Year = 9999 AND LevelActiveInd = 'Y'
			Group by ConsolidatnCode, ConsolidatnName, ConsolidatnShortName, LevelCode, LevelName, ObjectLevelShortName, LevelActiveInd
			Order by ConsolidatnCode, ConsolidatnName, ConsolidatnShortName, LevelCode, LevelName, ObjectLevelShortName, LevelActiveInd
		END
	
	RETURN 
END
