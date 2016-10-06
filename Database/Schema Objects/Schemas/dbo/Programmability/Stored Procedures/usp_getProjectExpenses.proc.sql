-- =============================================
-- Author:		Scott Kirkland
-- Create date: 9/15/06
-- Description:	
-- Modifications:
--	2013-11-21 by kjt: Added SQL to also include AINT entries.
-- =============================================
CREATE PROCEDURE [dbo].[usp_getProjectExpenses] 
	-- Add the parameters for the stored procedure here
	@SFN varchar(4), 
	@OrgR varchar(4)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

IF @SFN = 'All'
BEGIN
	SET @SFN = '%'
END

PRINT @OrgR

IF @OrgR = 'All'
BEGIN
	SET @OrgR = '%'
END

SELECT     Expenses.ExpenseID, Expenses.Sub_Exp_SFN AS SFN, Project.Project, Expenses.Expenses, Expenses.OrgR, Project.inv1 AS PI
FROM         Expenses INNER JOIN
                      Associations ON Expenses.ExpenseID = Associations.ExpenseID INNER JOIN
                      Project ON Associations.Accession = Project.Accession INNER JOIN
                      ReportingOrg ON Expenses.OrgR = ReportingOrg.OrgR
WHERE     (Expenses.Sub_Exp_SFN LIKE @SFN) AND (Expenses.OrgR LIKE @OrgR) AND (ReportingOrg.IsActive = 1 OR ReportingOrg.OrgR IN ('AINT', 'XXXX')) AND (Expenses.Sub_Exp_SFN IN ('201', '202', '205', '22F') )

/*
SELECT DISTINCT 
                      Expenses_CSREES.idExpense, Expenses_CSREES.SFN, Project.Project, Expenses_CSREES.Expenses, Expenses_CSREES.IfChecked AS OK, 
                      Project.inv1 AS PI, ReportingOrg.OrgR
FROM         Expenses_CSREES INNER JOIN
                      ReportingOrg ON Expenses_CSREES.OrgR = ReportingOrg.OrgR LEFT OUTER JOIN
                      Project ON Expenses_CSREES.Accession = Project.Accession
WHERE     (Expenses_CSREES.SFN LIKE @SFN) AND (ReportingOrg.OrgR LIKE @OrgR) AND (ReportingOrg.isActive = 1)
ORDER BY Expenses_CSREES.SFN, ReportingOrg.OrgR, Project.Project
*/


END
