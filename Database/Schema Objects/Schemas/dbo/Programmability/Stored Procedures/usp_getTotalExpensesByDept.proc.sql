﻿-- =============================================
-- Author:		Scott Kirkland
-- Create date: 10/12/2006
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[usp_getTotalExpensesByDept] 
	@OrgR varchar(4)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

IF @OrgR = 'All'
	SET @OrgR = '%'

/* Totals */
SELECT     'Total', ISNULL(SUM(Expenses),0) AS SPENT, ISNULL(SUM(FTE),0) AS FTE, COUNT(Expenses) AS RECS
FROM         Expenses
WHERE     (OrgR LIKE @OrgR)

UNION ALL
/* Associated */
SELECT     'Associated', ISNULL(SUM(Expenses),0) AS SPENT, ISNULL(SUM(FTE),0) AS FTE, COUNT(Expenses) AS RECS
FROM         Expenses
WHERE     (OrgR LIKE @OrgR) AND (isAssociated = 1)

UNION ALL
/* Unassociated */
SELECT     'Unassociated', ISNULL(SUM(Expenses),0) AS SPENT, ISNULL(SUM(FTE),0) AS FTE, COUNT(Expenses) AS RECS
FROM         Expenses
WHERE     (OrgR LIKE @OrgR) AND ( (isAssociated = 0) OR (isAssociated IS NULL ) )

END
