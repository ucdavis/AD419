-- =============================================
-- Author:		Ken Taylor
-- Create date: August 20, 2016
-- Description:	Check if all necessary tables have
-- been loaded, and all associations have been made,
-- and the perform some post processing and the 
-- create the final reports.
--
--Usage:
/*
	EXEC usp_PerformPostProcessingAndCreateFinalReports @FiscalYear = 2015, @IsDebug = 1
*/
--
-- Modifications:
--	20160821 by kjt: Fixed unassociated expenses checking logic.
--	20160907 by kjt: Adding error raising so that the error reason could be returned
--	and displayed on the web page. 
--	20160914 by kjt: Revised raise error logic to set an error message and use a single throw block. 
--	20161215 by kjt: Revised logic to handle projects with NULL expense sums as these were not being 
--		handled properly due to their expense totals being NULL instead of zero (0).
-- =============================================
CREATE PROCEDURE [dbo].[usp_PerformPostProcessingAndCreateFinalReports] 
	-- Add the parameters for the stored procedure here
	@FiscalYear int = 2016, 
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @ErrorMessage varchar(200) = ''

	IF NOT EXISTS (SELECT dbo.udf_CheckIfAllExpenseCategoriesHaveBeenLoaded())
		SELECT @ErrorMessage = 'Not All Expenses have be loaded.'
	ELSE IF NOT EXISTS (SELECT dbo.udf_CheckIfProjectAndProjXOrgRHaveBeenLoaded())
		SELECT @ErrorMessage = 'Projects and/or ProjXOrgR have not been loaded.'
	ELSE IF EXISTS (
		SELECT *
		FROM Expenses 
		WHERE isAssociated = 0 AND 
			OrgR NOT LIKE 'ACL%' AND OrgR NOT LIKE 'ADNO'
	)
		SELECT @ErrorMessage = 'Not all expenses have been associated.'
	
	IF @ErrorMessage IS NOT NULL AND @ErrorMessage NOT LIKE ''
	BEGIN
		IF @IsDebug = 1
			PRINT '-- ' + @ErrorMessage + '
	'
		IF @IsDebug = 0
		BEGIN
			RAISERROR(@ErrorMessage, 16, 1)
			RETURN -1
		END
	END

	DECLARE @TSQL varchar(MAX) = ''

	SELECT @TSQL = '
	UPDATE AllProjectsNew
	SET IsIgnored = 0 
	WHERE AccessionNumber IN (
		SELECT AccessionNumber 
		FROM   FFY_SFN_Entries
		WHERE IsExpired = 0 AND SFN = ''204''
		GROUP BY AccessionNumber HAVING ISNULL(SUM(Expenses),0) <= 100
	)

	TRUNCATE TABLE Project
	INSERT INTO Project
	SELECT * FROM udf_AD419ProjectsForFiscalYear(' + CONVERT(varchar(4), @FiscalYear) + ') 

	EXEC	[dbo].[usp_Create AD419_FinalReportTables]
		@ReportType = 1, -- 0 for select * from various tables once tables have been created
						 -- 1 for create tables after all projects have been associated.  Note 
						 -- this "report" must be run first before running option 0.
		@IsDebug = ' + CONVERT(varchar(1), @IsDebug) + '
'
	
    IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)
END