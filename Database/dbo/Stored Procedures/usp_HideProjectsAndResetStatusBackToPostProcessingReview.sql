


-- =============================================
-- Author:		Ken Taylor
-- Create date: December 20, 2019
-- Description:	Re-hides the hidden 204 projects, truncates and reloads the Project table and
--	resets IsCompleted flags in the ProcessCategory and ProcessStatus tables
--	so that DataHelper Status' is returned to Step 29: Post-Processing.  That way
--	Shannon may re-run the final reports if Shannon or the departments have needed to
--	re-associate any expenses that may have been associated incorrectly.
--	  
-- Usage:
/*

	USE [AD419]
	GO

	EXEC usp_HideProjectsAndResetStatusBackToPostProcessingReview @FiscalYear = 2021, @IsDebug = 1
	
*/
--
-- Modifications:
--
CREATE PROCEDURE [dbo].[usp_HideProjectsAndResetStatusBackToPostProcessingReview] 
	-- Add the parameters for the stored procedure here
	@FiscalYear int = 2021,
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    DECLARE @TSQL varchar(MAX) = ''

	SELECT @TSQL = '
	-- Reset status:
	UPDATE ProcessStatus
	SET IsCompleted = 0 
	WHERE CategoryID IN (
		SELECT Id
		FROM ProcessCategory
		WHERE SequenceOrder > = 29
	)

	UPDATE ProcessCategory
	SET IsCompleted = 0
	WHERE SequenceOrder > = 29	
'
	IF @IsDebug = 1
		PRINT @TSQL	
	ELSE
		EXEC(@TSQL)

	SELECT @TSQL = '
	-- Rehide projects:
	UPDATE AllProjectsNew
	SET IsIgnored = 1
	WHERE AccessionNumber IN (
	  SELECT  [AccessionNumber]
	  FROM [AD419].[dbo].[204ProjectsToBeExcludedFromDepartmentAssociationV] 
	)

	--Reload project table without hidden projects:
	TRUNCATE TABLE Project

	INSERT INTO Project
	SELECT * 
	FROM [dbo].[udf_AD419ProjectsForFiscalYear](' + CONVERT(char(4), @FiscalYear) + ')
'
	IF @IsDebug = 1
		PRINT @TSQL	
	ELSE
		EXEC(@TSQL)

END