-- =============================================
-- Author:		Ken Taylor
-- Create date: July 11, 2016
-- Description:	Load FFY_SFN_Entries
-- This table contains a list of all SFN 20x chart, account, SFN, and associated project, 
-- as well as, whether or not the project has expired.
-- This procedure will attempt to match accounts to projects using their account or OP(UC) 
-- fund award number, but just copy over the 204 project matches as those projects we mapped in
-- a previous step.
--
-- This is one of the final tables to load.
-- Pre-requsites:
-- 1. The AllProjectsImport table must have already been loaded.
-- 2. The ARC codes table must have already been loaded.
-- 3. The ARCcodeAccountExclusions must have already been loaded.
-- 4. The NewAccountSFN table must have already been loaded.
-- 5. The FFY_ExpensesByARC table must have already been loaded.
-- 6. The AllAccountsFor204Projects table must have already been loaded.
-- 7. The AD419Accounts table must have already been loaded.
--Usage:
/*
	USE AD419
	GO

	EXEC usp_Load_FFY_SFN_Entries @FiscalYear = 2015
	GO
*/
--
--Modifications:
--  20160819 by kjt: Added logic to exclude projects already in ARCCodeAccountExclusions
-- =============================================
CREATE PROCEDURE [dbo].[usp_Load_FFY_SFN_Entries] 
	@FiscalYear int = 2015
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	TRUNCATE table FFY_SFN_Entries

	INSERT INTO FFY_SFN_Entries (
		t1.Chart, t1.Account, t1.SFN, Accounts_AwardNum, OpFund_AwardNum, 
		AccessionNumber, ProjectNumber, 
		IsExpired, ProjectEndDate 
	)
	SELECT t1.Chart, t1.Account, t1.SFN, Accounts_AwardNum, OpFund_AwardNum, 
	CONVERT(varchar(10), NULL) AS AccessionNumber, CONVERT(varchar(24), NULL) AS ProjectNumber, 
	CONVERT(bit,NULL) AS IsExpired, CONVERT(datetime2, NULL) AS ProjectEndDate
	--INTO FFY_SFN_Entries
	FROM AD419Accounts t1
	INNER JOIN NewAccountSFN t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account
	WHERE t1.SFN BETWEEN '201' AND '205' 
	AND t1.Chart + t1.Account NOT IN (
		SELECT Chart+Account FROM ARCcodeAccountExclusions where year = @FiscalYear
	)
	Order by t1.SFN, t1.chart, t1.Account

	-- Update the 204 accounts with their project info:
	update FFY_SFN_Entries
	SET AccessionNumber = t2.AccessionNumber, ProjectNumber = t2.ProjectNumber,
	ProjectEndDate = t2.ProjectEndDate, IsExpired = t2.IsExpired
	FROM FFY_SFN_Entries t1
	INNER JOIN [dbo].[AllAccountsFor204Projects] t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account

	-- The projects in this list will need to either be matched or manually excluded:
	--DECLARE @FiscalYear int = 2015
	SELECT 'These 204 Projects will either need to be matched or manually excluded:' As Title
	select * FROM FFY_SFN_Entries where SFN = '204' AND ProjectNumber is null
	AND Chart+Account NOT IN (
	SELECT Chart+Account FROM ARCcodeAccountExclusions where year = @FiscalYear
	)

	-- Now let's try matching the 20x projects
	-- First replace the "*" with nothing.
	UPDATE FFY_SFN_Entries
	SET Accounts_AwardNum = REPLACE(Accounts_AwardNum, '*', '')
	WHERE SFN IN ('201', '202', '203', '205')

	-- This is a list of 20x accounts and their project matches (or not)
	SELECT 'List of 20x accounts and their projects matches (or not):' AS Title
	SELECT t1.Chart, t1.Account, t1.SFN, t1.Accounts_AwardNum, t4.ProjectNumber,
	MAX(t4.AccessionNumber) AccessionNumber, MAX(t4.ProjectEndDate) ProjectEndDate
	FROM  FFY_SFN_Entries t1
	LEFT OUTER JOIN [dbo].[udf_AllProjectsNewForFiscalYear](@FiscalYear) t4 ON 
		(
			(REPLACE(t1.Accounts_AwardNum, '-','' ) = REPLACE(REPLACE(t4.ProjectNumber, '	', ''), '-','')) 
		)
	WHERE SFN IN ('201', '202', '203', '205')
	GROUP BY Chart, Account, SFN, Accounts_AwardNum, t4.ProjectNumber 
	ORDER BY Chart, Account, SFN

	-- Update the entries based on the the project matches
	UPDATE FFY_SFN_Entries
	SET ProjectNumber = t2.ProjectNumber, AccessionNumber = t2.AccessionNumber
	, ProjectEndDate = t2.ProjectEndDate, IsExpired = CASE WHEN 
		t2.ProjectEndDate < '' + CONVERT(varchar(4),@FiscalYear-1) + '-10-01' THEN 1 ELSE 0 END
	FROM FFY_SFN_Entries t1
	INNER JOIN (
		SELECT t1.Chart, t1.Account, t1.SFN, t1.Accounts_AwardNum, t4.ProjectNumber,
		MAX(t4.AccessionNumber) AccessionNumber, MAX(t4.ProjectEndDate) ProjectEndDate
		FROM  FFY_SFN_Entries t1
		LEFT OUTER JOIN [dbo].[udf_AllProjectsNewForFiscalYear](@FiscalYear) t4 ON 
			(
				(REPLACE(t1.Accounts_AwardNum, '-','' ) = REPLACE(REPLACE(t4.ProjectNumber, '	', ''), '-','')) 
			)
		WHERE SFN IN ('201', '202', '203', '205')
		GROUP BY Chart, Account, SFN, Accounts_AwardNum, t4.ProjectNumber 
		--ORDER BY Chart, Account, SFN
		) t2 ON t1.Chart = t2.Chart and t1.Account = t2.Account


	-- This was just a check to look for any matches that were excluded intentionally:
	SELECT 'This is a list of 204 and 20x projects that were either exluded or could not be matched:' AS Title
	select t1.*, t2.ProjectNumber from FFY_SFN_Entries t1
	LEFT OUTER JOIN ARCCodeAccountExclusions t2 ON t1.Chart = t2.Chart And t1.Account = t2.Account AND Year = @FiscalYear
	where SFN BETWEEN '201' AND '205'
	and accessionNumber is null

	UPDATE FFY_SFN_Entries
	SET IsExpired = t2.IsExpired
	FROM FFY_SFN_Entries t1
	INNER JOIN AD419Accounts t2 ON t1.Chart = t2.Chart and t1.Account = t2.Account
	WHERE t2.SFN = '204' 

END