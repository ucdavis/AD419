-- =============================================
-- Author:		Scott Kirkland
-- Create date: 9/14/06
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[usp_getInterdepartmentalProjectInfo] 
	-- Add the parameters for the stored procedure here
	@Accession char(7)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
SELECT TOP 1  Accession, Project, Title, inv1, inv2, inv3, inv4, inv5, inv6
FROM         Project
WHERE	(Accession = @Accession)

END
