-- =============================================
-- Author:		Scott Kirkland
-- Create date: 1/16/2007
-- Description:	
-- =============================================
CREATE FUNCTION [dbo].[udf_GetProjectExpenseBySFN] 
(	
	-- Add the parameters for the function here
	@Accession varchar(50), 
	@SFN char(3)
)
RETURNS @ProjectSFNTotal TABLE 
	(
		Total float
	)
AS
BEGIN

DECLARE @FTE_SFNs varchar(50)
SET @FTE_SFNs = '{ 241, 242, 243, 244 }'

INSERT INTO @ProjectSFNTotal
SELECT     SUM(Associations.Expenses) AS Total
FROM         Associations INNER JOIN
			Expenses ON Associations.ExpenseID = Expenses.ExpenseID
WHERE     (Associations.Accession = @Accession) AND Expenses.Exp_SFN = @SFN
GROUP BY Associations.Accession

RETURN 
END
