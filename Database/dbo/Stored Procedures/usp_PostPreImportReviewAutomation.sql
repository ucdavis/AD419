-- =============================================
-- Author:		Ken Taylor
-- Create date: September 19, 2016
-- Description:	Executes all the stored procedures after manual
-- review of consolidation codes, trans doc type, DOS codes, and
-- report organizations, but prior to importing projects and other
-- user data.
-- I broke this out into a separate step even though the only 
-- sproc it currently runs is sp_Repopulate_OrgXOrgR, but this 
-- gives us the flexibility to add others in the future at this
-- point in the process.
--
-- Usage:
/*
	EXEC usp_PostPreImportReviewAutomation @FiscalYear = 2015, @IsDebug = 1
*/
--
-- Modifications:
--
CREATE PROCEDURE usp_PostPreImportReviewAutomation
	@FiscalYear int = 2015,
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    DECLARE @TSQL varchar(MAX) = ''

	SELECT @TSQL = '
	-- Reload the OrgXOrgR table:
	EXEC [dbo].[usp_Repopulate_OrgXOrgR] @FiscalYear = ' + CONVERT(varchar(4), @FiscalYear) + ', 
		@IsDebug = ' + CONVERT(varchar(1), @IsDebug) + '
'
	IF @IsDebug = 1
		PRINT @TSQL	
	ELSE
		EXEC(@TSQL)
END