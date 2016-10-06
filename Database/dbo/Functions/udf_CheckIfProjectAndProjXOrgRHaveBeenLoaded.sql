-- =============================================
-- Author:		Ken Taylor
-- Create date: August 20, 2016
-- Description:	Check if Project and ProjXOrgR tables have been loaded.
-- Usage:
/*
	SELECT dbo.udf_CheckIfProjectAndProjXOrgRHaveBeenLoaded() AS ProjectAndProjXOrgRHaveBeenLoaded
*/
-- Modifications:
--
-- =============================================
CREATE FUNCTION udf_CheckIfProjectAndProjXOrgRHaveBeenLoaded 
(
)
RETURNS int
AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result bit = 1, @ProjectCount int = 0, @ProjectXOrgRCount int = 0

	SELECT @ProjectCount = (
		SELECT COUNT(*) FROM Project
	)

	SELECT @ProjectXOrgRCount = (
		SELECT COUNT(*) FROM ProjXOrgR
	)

	IF @ProjectCount = 0 OR @ProjectXOrgRCount = 0
	BEGIN
		RETURN 0
	END

	RETURN @Result

END