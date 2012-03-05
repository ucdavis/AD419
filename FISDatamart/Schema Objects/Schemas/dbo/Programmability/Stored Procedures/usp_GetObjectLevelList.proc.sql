-- =============================================
-- Author:		Ken Taylor
-- Create date: 02-Jun-2010
-- Description:	Returns a list of Object Consolidatn Codes and 
-- their corresponding Level with Report Builder, etc.
-- =============================================
CREATE PROCEDURE [dbo].[usp_GetObjectLevelList] 
	-- Add the parameters for the stored procedure here
	@AddWildcard bit = 0, -- 0: Do NOT add wildcard ('%') (default); 1: Add wildcard.
	@ReturnInactiveAlso bit = 1 -- 1: Return ALL Objects Consolidation Codes and their 
	-- associated levels (default); 0: Return only those with records where the 
	-- LevelActiveInd = 'Y'.
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	DECLARE @MyTable TABLE (
		ConsolidatnCode varchar(4), 
		ConsolidatnName varchar(40), 
		ConsolidatnShortName char(12), 
		ObjectLevel varchar(100), 
		LevelCode varchar(4), 
		LevelName varchar(40), 
		ObjectLevelShortName char(12),
		LevelActiveInd char(1)
	)

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
		
	Insert into @MyTable (ConsolidatnCode, ConsolidatnName, ConsolidatnShortName, ObjectLevel , LevelCode, LevelName, ObjectLevelShortName, LevelActiveInd)
	Select distinct ConsolidatnCode, ConsolidatnName, ConsolidatnShortName, (ConsolidatnCode + ': ' + LevelCode + ' - ' +  LevelName) AS ObjectLevel, LevelCode, LevelName, ObjectLevelShortName, LevelActiveInd
	From dbo.Objects
	Where Year = 9999
	Group by ConsolidatnCode, ConsolidatnName, ConsolidatnShortName, LevelCode, LevelName, ObjectLevelShortName, LevelActiveInd
	Order by ConsolidatnCode, ConsolidatnName, ConsolidatnShortName, LevelCode, LevelName, ObjectLevelShortName, LevelActiveInd

	If @ReturnInactiveAlso = 1
		BEGIN
			Select * from @MyTable
		END
	Else
		BEGIN
			Select * from @MyTable where LevelActiveInd = 'Y'
		END
END
