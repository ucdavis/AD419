
-- =============================================
-- Author:		Scott Kirkland
-- Create date: 6/9/2020
-- Description:
-- =============================================
CREATE PROCEDURE [dbo].[usp_getTotalExpensesByDepartment]
	@OrgR varchar(4)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

IF @OrgR = 'All'
	SET @OrgR = '%'

/* Totals */
SELECT     'Total' as Name, ISNULL(SUM(Expenses),0) AS SPENT, ISNULL(SUM(FTE),0) AS FTE, COUNT(Expenses) AS RECS
FROM         Expenses
WHERE     (OrgR LIKE @OrgR)

UNION ALL
/* Associated */
SELECT     'Associated' as Name, ISNULL(SUM(Expenses),0) AS SPENT, ISNULL(SUM(FTE),0) AS FTE, COUNT(Expenses) AS RECS
FROM         Expenses
WHERE     (OrgR LIKE @OrgR) AND (isAssociated = 1)

UNION ALL
/* Unassociated */
SELECT     'Unassociated' as Name, ISNULL(SUM(Expenses),0) AS SPENT, ISNULL(SUM(FTE),0) AS FTE, COUNT(Expenses) AS RECS
FROM         Expenses
WHERE     (OrgR LIKE @OrgR) AND ( (isAssociated = 0) OR (isAssociated IS NULL ) )

END