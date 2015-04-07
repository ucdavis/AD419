-- =============================================
-- Author:		Scott Kirkland
-- Create date: 11/15/06
-- Description:	
-- Modifications:
-- 2012-03-08 by kjt: Revised Employee branch to handle staff type.
-- =============================================
CREATE PROCEDURE [dbo].[usp_getExpensesByRecordGrouping] 
	-- Add the parameters for the stored procedure here
	@Grouping varchar(50),
	@OrgR char(4),
	@Chart char(2),
	@Criterion varchar(50),
	@isAssociated bit

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

DECLARE @CriterionNull bit
IF @Criterion = '----'
	SET @CriterionNull = 1
ELSE IF @Criterion = ''
	SET @CriterionNull = 1
ELSE
	SET @CriterionNull = 0

-- We are going to build up a list of ExpenseID's and the corresponding info in the current grouping
DECLARE @txtSQL varchar(2000)

-- Insert all of the matching expenseIDs
SET @txtSQL =
	'
	SELECT     E.ExpenseID, E.Expenses, E.FTE
	FROM         Expenses AS E
	WHERE     (E.OrgR = ''' + @OrgR + ''') AND (E.Chart = ''' + @Chart + ''') 
	'
	+
	CASE @isAssociated
		WHEN 1 THEN
			' AND (E.isAssociated = 1) '
		WHEN 0 THEN
			' AND (E.isAssociated = 0) '
	END
	+
	CASE @Grouping
		WHEN  'Organization' THEN
			CASE @CriterionNull
				WHEN 1 THEN
					' AND ( E.Org IS NULL )'
				WHEN 0 THEN
					' AND ( E.Org = ''' +@Criterion + ''')' 
			END
		WHEN 'Sub-Account' THEN
			CASE @CriterionNull
				WHEN 1 THEN
					' AND ( E.SubAcct IS NULL )'
				WHEN 0 THEN
					' AND ( E.SubAcct = ''' +@Criterion + ''')'
			END
		WHEN 'PI' THEN
			CASE @CriterionNull
				WHEN 1 THEN
					' AND ( E.PI_Name IS NULL )'
				WHEN 0 THEN
					' AND ( E.PI_Name = ''' +@Criterion + ''')'
			END		
		WHEN 'Account' THEN
			CASE @CriterionNull
				WHEN 1 THEN
					' AND ( E.Account IS NULL )'
				WHEN 0 THEN
					' AND ( E.Account = ''' +@Criterion + ''')'
			END
		WHEN 'Employee' THEN
			CASE @CriterionNull
				WHEN 1 THEN
					' AND ( E.EID IS NULL )'
				WHEN 0 THEN
					' AND ( E.EID + ''|'' + E.FTE_SFN = ''' + @Criterion + ''')'
			END
		WHEN 'None' THEN
			CASE @CriterionNull
				WHEN 1 THEN
					' AND ( E.ExpenseID IS NULL )'
				WHEN 0 THEN
					' AND ( E.ExpenseID = ''' +@Criterion + ''')'
			END
	END	
	
EXEC (@txtSQL)

END
