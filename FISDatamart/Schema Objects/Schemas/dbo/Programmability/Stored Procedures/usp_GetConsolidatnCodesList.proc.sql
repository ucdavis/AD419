-- =============================================
-- Author:		Ken Taylor
-- Create date: 02-Jun-2010
-- Description:	Returns a list of ConsolidatnCodes and their
-- corresponding details for use with Report Builder, etc.
-- =============================================
CREATE PROCEDURE [dbo].[usp_GetConsolidatnCodesList] 
	-- Add the parameters for the stored procedure here
	@AddWildcard bit = 0, -- 0: Do NOT add wildcard ('%') (default); 1: Add wildcard.
	@ReturnInactiveAlso bit = 1 -- 1: Return ALL records (default); 0: Return only those records where the 
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
		ObjectConsolidation varchar(100),
		ConsolidatnActiveInd char(1)
	)

	If @AddWildcard = 1
		BEGIN
			Insert into @MyTable (
				ConsolidatnCode, 
				ConsolidatnName, 
				ConsolidatnShortName, 
				ObjectConsolidation,
				ConsolidatnActiveInd
			) VALUES ('%', '%', '%', '%', 'Y')
		END
		
	Insert into @MyTable (
		ConsolidatnCode, 
		ConsolidatnName, 
		ConsolidatnShortName, 
		ObjectConsolidation,
		ConsolidatnActiveInd
		)
	SELECT distinct 
		ConsolidatnCode, 
		ConsolidatnName, 
		ConsolidatnShortName, 
	   (ConsolidatnCode + ' - ' + ConsolidatnName) AS ObjectConsolidation,
	    ConsolidatnActiveInd  
	From dbo.Objects
	Where 
		Year = 9999 
	Group by ConsolidatnCode, ConsolidatnName, ConsolidatnShortName, ConsolidatnActiveInd
	Order by ConsolidatnCode, ConsolidatnName, ConsolidatnShortName, ConsolidatnActiveInd
	
	If @ReturnInactiveAlso = 1
		BEGIN
			Select * from @MyTable
		END
	Else
		BEGIN
			Select * from @MyTable where ConsolidatnActiveInd = 'Y'
		END
END
