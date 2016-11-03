-- =============================================
-- Author:		Ken Taylor
-- Create date: June 30, 2016
-- Description:	Return a list of expired 20x projects that need to be remapped.
--Usage:
/*
	SELECT * FROM udf_GetExpired20xProjects(2015)
*/
-- Modifications:
--	2016-08-18 by kjt: Revised to use AllProjectsNew table where IsUCD = 1
--  2017-08-19 by kjt: Revised matching to remove tabs and spaces from project numbers
-- =============================================
CREATE FUNCTION [dbo].[udf_GetExpired20xProjects] 
(
	-- Add the parameters for the function here
	@FiscalYear int = 2015
)
RETURNS 
@ExpiredProjects TABLE 
(
  OrgR varchar(4), 
  ProjectDirector varchar(50),  
  Title varchar(512), 
  ProjectEndDate datetime2, 
  Expenses Money , 
  SFN varchar(5), 
  Accounts_AwardNum varchar(20), 
  OPFund_AwardNum varchar(20),
  ProjectNumber varchar(24),
  AccessionNumber varchar(7)
)
AS
BEGIN
	INSERT INTO @ExpiredProjects
	SELECT DISTINCT t3.OrgR, t5.ProjectDirector,  t5.Title, t5.ProjectEndDate, SUM(Total) Expenses, t1.SFN, REPLACE(REPLACE(t1.Accounts_AwardNum,'	', ''), '*', '') Accounts_AwardNum, t1.OPFund_AwardNum,
	  COALESCE(t3.ProjectNumber, t4.ProjectNumber) ProjectNumber, t5.AccessionNumber
	FROM [AD419].[dbo].[NewAccountSFN] t1
	INNER JOIN [dbo].[FFY_ExpensesByARC] t2 ON t1.Chart = t2.Chart and t1.Account = t2.Account
	LEFT OUTER JOIN AllProjectsNew t3 ON IsUCD = 1 AND (REPLACE(t1.[OPFund_AwardNum],'-','') = REPLACE(t3.AwardNumber,'-','') OR 
		REPLACE(t1.[Accounts_AwardNum],'-','') = REPLACE(t3.AwardNumber,'-','') OR
		RTRIM(REPLACE(t1.[Accounts_AwardNum],'*','')) = REPLACE(t3.ProjectNumber, '	', ''))
	LEFT OUTER JOIN ArcCodeAccountExclusions t4 ON t1.Chart = t4.Chart AND t1.Account = t4.Account AND Year = @FiscalYear
	LEFT OUTER JOIN (
		SELECT DISTINCT RTRIM(REPLACE(ProjectNumber,'	', '')) ProjectNumber, MAX(AccessionNumber) AccessionNumber, AwardNumber, MAX(ProjectEndDate) ProjectEndDate,
			MAX(ProjectDirector) ProjectDirector, MAX(Title) Title 
		FROM AllProjectsNew
		WHERE IsUCD = 1
		GROUP BY RTRIM(REPLACE(ProjectNumber,'	', '')), AwardNumber
	  ) t5 ON RTRIM(REPLACE(t1.[Accounts_AwardNum],'*','')) = REPLACE(t5.ProjectNumber, '	', '') OR
			REPLACE(t1.[OPFund_AwardNum],'-','') = REPLACE(t5.AwardNumber,'-','') OR 
			REPLACE(t1.[Accounts_AwardNum],'-','') = REPLACE(t5.AwardNumber,'-','')

	   WHERE t1.SFN IN ('201', '202', '203', '204','205') AND IsAccountInFinancialData = 1
			AND (t1.Accounts_AwardNum IS NOT NULL OR OPFund_AwardNum IS NOT NULL)
			AND t5.ProjectEndDate < CONVERT(varchar(4), @FiscalYear -1) + '-10-01' AND t1.SFN IN ('201', '202', '203', '205')
	   group by t1.SFN,t1.Accounts_AwardNum, t1.OPFund_AwardNum, t3.ProjectNumber, t4.ProjectNumber,t5.AccessionNumber, t5.ProjectEndDate
			,t3.OrgR, t5.ProjectDirector, t5.Title having sum(Total) > 0
  
	RETURN 
END