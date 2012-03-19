-- =============================================
-- Author:		Scott Kirkland
-- Create date: 9/15/06
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[usp_getSFN] 

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

SELECT     SFN, SFN + '  (' + Description + ')' AS Description
FROM         SFN
WHERE     (SFN <> '204')
ORDER BY SFN

END
