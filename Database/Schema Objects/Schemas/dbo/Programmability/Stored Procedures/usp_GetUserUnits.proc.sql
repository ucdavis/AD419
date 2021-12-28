
-- =============================================
-- Author:		Ken Taylor
-- Create date: 10/28/2009
-- Description:	Returns a user's units for construction
--	of the principal
-- Usage:
/*
	USE [AD419]
	GO

	EXEC [dbo].[usp_GetUserUnits] @EmployeeID = '838163392'
	GO

*/
-- Modifications:
--	20191021 by kjt: Added Usage section for testing.
--
CREATE PROCEDURE [dbo].[usp_GetUserUnits] (
	@EmployeeID nvarchar(9),
	@ApplicationName varchar(50) = 'AD419'
)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;


	DECLARE @UserID int
	SET @UserID = ( SELECT UserID FROM Catbert3.dbo.Users WHERE EmployeeID = @EmployeeID )

	SELECT * FROM udf_GetUserUnitsForApplication(@EmployeeID, @ApplicationName)
END
