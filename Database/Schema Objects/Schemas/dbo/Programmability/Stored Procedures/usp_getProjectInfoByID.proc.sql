-- =============================================
-- Author:		Scott Kirkland
-- Create date: 9/27/06
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[usp_getProjectInfoByID] 
	-- Add the parameters for the stored procedure here
	@ProjectID varchar(24)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

SELECT     Accession, inv1, inv2, inv3, inv4, inv5, inv6, BeginDate, TermDate, ProjTypeCd, RegionalProjNum, StatusCd, Title
FROM         Project
WHERE     (Project = @ProjectID)

END
