-- =============================================
-- Author:		Ken Taylor
-- Create date: 12-Aug-2010
-- Description:	Returns a list of IsCAES and their
-- corresponding details for use with Report Builder, etc.
-- =============================================
CREATE PROCEDURE [dbo].[usp_GetIsCAES] 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	DECLARE @MyTable TABLE (
		IsCAESValue tinyint, 
		IsCAESLabel varchar(40)
	)
		
	Insert into @MyTable (
		IsCAESValue, 
		IsCAESLabel
		)
	VALUES (1, 'CAES'), (2, 'ACBS'), (0, 'BIOS')
	
		Select * from @MyTable
		
END
