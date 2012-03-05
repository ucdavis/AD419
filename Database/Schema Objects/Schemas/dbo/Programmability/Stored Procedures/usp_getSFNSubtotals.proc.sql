-- =============================================
-- Author:		Scott Kirkland
-- Create date: 9/18/06
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[usp_getSFNSubtotals]
	@OrgR varchar(4)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
IF @OrgR = 'All'
BEGIN
	SET @OrgR = '%'
END

SELECT     Expenses.Sub_Exp_SFN AS SFN, SUM(Expenses.Expenses) AS SumOfExpenses
FROM         Expenses INNER JOIN
                      SFN ON Expenses.Sub_Exp_SFN = SFN.SFN
WHERE     (Expenses.OrgR LIKE @OrgR)
GROUP BY Expenses.Sub_Exp_SFN
ORDER BY Expenses.Sub_Exp_SFN

/* ---------- Old Version ----------------
SELECT Expenses_CSREES.SFN, Sum(Expenses_CSREES.Expenses) AS SumOfExpenses
FROM Expenses_CSREES
WHERE (((Expenses_CSREES.OrgR)= @OrgR))
GROUP BY Expenses_CSREES.SFN
ORDER BY Expenses_CSREES.SFN;
*/

END
