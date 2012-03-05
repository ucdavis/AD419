-- =============================================
-- Author:		Ken Taylor
-- Create date: 2011-12-28
-- Description:	Drop and Create ProjectSFN table
-- =============================================
CREATE PROCEDURE [usp_DropAndRecreateProjectSFN_20120112_bak] 
	-- Add the parameters for the stored procedure here
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
   --SET NOCOUNT ON;

   DECLARE @ProjSFN TABLE
					(
						Project varchar(24),
						Accession char(7),
						OrgR char(4),
						inv1 varchar(30),
						SFN char(3),
						Amt decimal(16,3),
						isExpense bit
					)

				-- Populate a temporary table with all non-zero expense data
				INSERT INTO @ProjSFN
				SELECT     Project.Project, Project.Accession, Associations.OrgR, Project.inv1, Expenses.Exp_SFN, ISNULL(ROUND(SUM(Associations.Expenses),0),0) AS Amt, 1
				FROM         Expenses INNER JOIN
									  ReportingOrg ON Expenses.OrgR = ReportingOrg.OrgR INNER JOIN
									  Associations ON Expenses.ExpenseID = Associations.ExpenseID INNER JOIN
									  Project ON Associations.Accession = Project.Accession
				GROUP BY Project.Project, Project.Accession, Associations.OrgR, Project.inv1, Expenses.Exp_SFN
				HAVING      (SUM(Associations.Expenses) > 0)

				-- Populate this time with FTE data
				INSERT INTO @ProjSFN
				SELECT     Project.Project, Project.Accession, Associations.OrgR, Project.inv1, Expenses.FTE_SFN, ISNULL(ROUND(SUM(Associations.FTE), 1),0) AS Amt, 0
				FROM         Expenses INNER JOIN
									  ReportingOrg ON Expenses.OrgR = ReportingOrg.OrgR INNER JOIN
									  Associations ON Expenses.ExpenseID = Associations.ExpenseID INNER JOIN
									  Project ON Associations.Accession = Project.Accession
				GROUP BY Project.Project, Project.Accession, Associations.OrgR, Project.inv1, Expenses.FTE_SFN
				HAVING      (SUM(Associations.FTE) > 0)
				
				-- This table is needed for future calls for udf_GetSFN_UnassociatedTotal
				IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ProjSFN]') AND type in (N'U'))
					DROP table [AD419].[dbo].[ProjSFN]
				SELECT * INTO [AD419].[dbo].[ProjSFN] FROM @ProjSFN
END
