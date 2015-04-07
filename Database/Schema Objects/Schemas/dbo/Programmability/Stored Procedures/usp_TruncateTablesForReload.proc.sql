-- =============================================
-- Author:		Ken Taylor
-- Create date: November 26, 2014
-- Description:	Truncate the AD419 database tables to allow reloading of expenses and making associations.
-- Note that you will also need to truncate additional tables to do a total reload for the next fiscal year. 
-- =============================================
CREATE PROCEDURE [dbo].[usp_TruncateTablesForReload] 
	@FiscalYear int = 2014, -- The later portion of the AD-419 reporting year, i.e. 2014 for 2013-2014, etc.
	@IsDebug bit = 0 -- Set to 1 to print SQL created by this procedure only.
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	-- SET NOCOUNT ON;

	DECLARE @TSQL varchar(MAX) = ''

	SELECT @TSQL = '
truncate table [204AcctXProj]

truncate table Acct_SFN

truncate table [204AcctXProj]

truncate table Associations

truncate table dbo.CESList

truncate table CESXProjects

truncate table AllExpenses

truncate table dbo.Expenses_CAES

truncate table Expenses_CE_Nonsalary

truncate table Expenses_PPS

truncate table ProjXOrgR

truncate table Raw_PPS_Expenses

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N''[SFN_PROJECT_QUAD_NUM]'') AND type in (N''U'')) 
	DROP TABLE [SFN_PROJECT_QUAD_NUM]

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N''[FFY_' + CONVERT(varchar(4), @FiscalYear) + '_SFN_ENTRIES]'') AND type in (N''U'')) 
	DROP TABLE [FFY_' + CONVERT(varchar(4), @FiscalYear) + '_SFN_ENTRIES]
'

IF @IsDebug = 1
BEGIN
	PRINT @TSQL
END
ELSE
	EXEC(@TSQL)

END