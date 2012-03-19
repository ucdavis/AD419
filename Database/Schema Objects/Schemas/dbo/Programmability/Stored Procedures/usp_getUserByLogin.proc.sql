-- =============================================
-- Author:		Ken Taylor
-- Create date: 2009-10-28
-- Description:	Replaces the old catbert usp_getUserByLogin
-- =============================================
CREATE PROCEDURE [dbo].[usp_getUserByLogin] 

	-- Add the parameters for the stored procedure here
	@LoginID nvarchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	SELECT * FROM Users_V WHERE LoginID = @LoginID

END
