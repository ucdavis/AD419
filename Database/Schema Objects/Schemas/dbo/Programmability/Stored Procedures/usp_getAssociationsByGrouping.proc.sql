-- =============================================
-- Author:		Scott Kirkland
-- Create date: 11/12/2006
-- Description:	
/*
EXEC usp_getAssociationsByGrouping 'AANS', 'Organization', '3', 'ASGI'
EXEC usp_getAssociationsByGrouping 'AANS', 'PI', 'L', '----'

*/
-- =============================================
CREATE PROCEDURE [dbo].[usp_getAssociationsByGrouping] 
	-- Add the parameters for the stored procedure here
	@OrgR char(4),
	@Grouping varchar(50),
	@Chart char(2),
	@Criterion varchar(50),
	@isAssociated tinyint

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

-- The string '----' is the code for a null entry
DECLARE @isCriterionNull bit
IF @Criterion = '----'
	SET @isCriterionNull = 1
ELSE
	SET @isCriterionNull = 0

DECLARE @txtSQL varchar(2000)

SET @txtSQL =
	'
	SELECT     Project.Project, SUM(Associations.Expenses) AS Spent, SUM(Associations.FTE) AS FTE
	'
	+
	CASE @Grouping
		WHEN 'PI' THEN
			'
			FROM         Associations INNER JOIN
							  Expenses ON Associations.ExpenseID = Expenses.ExpenseID INNER JOIN
							  Project ON Associations.Accession = Project.Accession		
			'
			+
			'
			WHERE     (Associations.OrgR = '''+@OrgR+''') 
						AND (Expenses.Chart = '''+@Chart+''') 
						AND (Expenses.isAssociable <> 0)
						AND (Expenses.isAssociated = '+CAST(@isAssociated AS varchar(25))+')
			'
			+
			CASE @isCriterionNull
				WHEN 1 THEN
					' AND (Expenses.PI_Name IS NULL) '
				WHEN 0 THEN
					' AND (Expenses.PI_Name = '''+@Criterion+''') '
			END
		WHEN 'Organization' THEN
			'
			FROM         Associations INNER JOIN
								  Expenses ON Associations.ExpenseID = Expenses.ExpenseID INNER JOIN
								  Project ON Associations.Accession = Project.Accession
			'
			+
			'
			WHERE     (Associations.OrgR = '''+@OrgR+''') 
						AND (Expenses.Chart = '''+@Chart+''') 
						AND (Expenses.isAssociable <> 0)
						AND (Expenses.isAssociated = '+CAST(@isAssociated AS varchar(25))+')
			'
			+
			CASE @isCriterionNull
				WHEN 1 THEN
					' AND (Expenses.Org IS NULL) '
				WHEN 0 THEN
					' AND (Expenses.Org = '''+@Criterion+''') '
			END
		WHEN 'Sub-Account' THEN
			'
			FROM         Associations INNER JOIN
								  Expenses ON Associations.ExpenseID = Expenses.ExpenseID INNER JOIN
								  Project ON Associations.Accession = Project.Accession
			'
			+
			'
			WHERE     (Associations.OrgR = '''+@OrgR+''') 
						AND (Expenses.Chart = '''+@Chart+''') 
						AND (Expenses.isAssociable <> 0)
						AND (Expenses.isAssociated = '+CAST(@isAssociated AS varchar(25))+')
			'
			+
			CASE @isCriterionNull
				WHEN 1 THEN
					' AND (Expenses.SubAcct IS NULL) '
				WHEN 0 THEN
					' AND (Expenses.SubAcct = '''+@Criterion+''') '
			END
		WHEN 'Account' THEN
			'
			FROM         Associations INNER JOIN
								  Expenses ON Associations.ExpenseID = Expenses.ExpenseID INNER JOIN
								  Project ON Associations.Accession = Project.Accession
			'
			+
			'
			WHERE     (Associations.OrgR = '''+@OrgR+''') 
						AND (Expenses.Chart = '''+@Chart+''') 
						AND (Expenses.isAssociable <> 0)
						AND (Expenses.isAssociated = '+CAST(@isAssociated AS varchar(25))+')
			'
			+
			CASE @isCriterionNull
				WHEN 1 THEN
					' AND (Expenses.Account IS NULL) '
				WHEN 0 THEN
					' AND (Expenses.Account = '''+@Criterion+''') '
			END
		WHEN 'Employee' THEN
			'
			FROM         Associations INNER JOIN
								  Expenses ON Associations.ExpenseID = Expenses.ExpenseID INNER JOIN
								  Project ON Associations.Accession = Project.Accession
			'
			+
			'
			WHERE     (Associations.OrgR = '''+@OrgR+''') 
						AND (Expenses.Chart = '''+@Chart+''') 
						AND (Expenses.isAssociable <> 0)
						AND (Expenses.isAssociated = '+CAST(@isAssociated AS varchar(25))+')
			'
			+
			CASE @isCriterionNull
				WHEN 1 THEN
					' AND (Expenses.EID IS NULL) '
				WHEN 0 THEN
					' AND (Expenses.EID = '''+@Criterion+''') '
			END
		WHEN 'None' THEN
			'
			FROM         Associations INNER JOIN
								  Expenses ON Associations.ExpenseID = Expenses.ExpenseID INNER JOIN
								  Project ON Associations.Accession = Project.Accession
			'
			+
			'
			WHERE     (Associations.OrgR = '''+@OrgR+''') 
						AND (Expenses.Chart = '''+@Chart+''') 
						AND (Expenses.isAssociable <> 0)
						AND (Expenses.isAssociated = '+CAST(@isAssociated AS varchar(25))+')
			'
			+
			CASE @isCriterionNull
				WHEN 1 THEN
					' AND (Expenses.ExpenseID IS NULL) '
				WHEN 0 THEN
					' AND (Expenses.ExpenseID = '''+@Criterion+''') '
			END
	END
	+
	'
	GROUP BY Project.Project
	ORDER BY Project.Project
	'
		
EXEC(@txtSQL)

/* ------------------------- Example of Old Non-Dynamic SQL --------------------

/ By Organization /
ELSE IF @Grouping = 'Organization'
BEGIN
	IF @isCriterionNull = 1
		BEGIN
			SELECT     Project.Project, SUM(Associations.Expenses) AS Spent, SUM(Associations.FTE) AS FTE
			FROM         Associations INNER JOIN
								  Expenses ON Associations.ExpenseID = Expenses.ExpenseID INNER JOIN
								  Project ON Associations.Accession = Project.Accession INNER JOIN
								  FIS.dbo.Organization AS O ON Expenses.Org = O.Org
			WHERE     (Associations.OrgR = @OrgR) AND (O.Org IS NULL) AND (Expenses.Chart = @Chart) AND (Expenses.isAssociable <> 0)
			GROUP BY Project.Project
			ORDER BY Project.Project
		END
	ELSE
		BEGIN
			SELECT     Project.Project, SUM(Associations.Expenses) AS Spent, SUM(Associations.FTE) AS FTE
			FROM         Associations INNER JOIN
								  Expenses ON Associations.ExpenseID = Expenses.ExpenseID INNER JOIN
								  Project ON Associations.Accession = Project.Accession INNER JOIN
								  FIS.dbo.Organization AS O ON Expenses.Org = O.Org
			WHERE     (Associations.OrgR = @OrgR) AND (O.Org = @Criterion) AND (Expenses.Chart = @Chart) AND (Expenses.isAssociable <> 0)
			GROUP BY Project.Project
			ORDER BY Project.Project
		END
END
-----------------------------------------------------------------------------------*/

END
