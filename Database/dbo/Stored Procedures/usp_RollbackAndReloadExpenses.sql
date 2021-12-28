-- =============================================
-- Author:		Ken Taylor
-- Create date: December 15, 2016
-- Description:	
-- Rollback the tables used in the AD-419 application after testing
-- to the pre-manual association phase, so that the departments can
-- make their associations.
-- The steps involved are the following:
-- 1. Truncate and reload the projects table so that it contains
-- Truncate the AD-419 Expenses and Associations table,
--  
--	and reset the ProcessStatus and ProcessCategory IsCompleted flags 
-- to false back to category 13 so we can restart the process at step 13. 
--
-- Usage:
/*
	EXEC usp_RollbackAndReloadExpenses @FiscalYear = 2016, @IsDebug = 1 --*

-- *Note that the 2 parameters are just place holders and need not be provided.
*/
-- Modifications:
--	2017-09-21 by kjt: Added new calls for additional stored procedures.
--	2017-10-05 by kjt: Changed <= 100 to < 100 as per AD-419 reporting instructions. 
--	2017-11-15 by kjt: Update procedures called to match those called by DataHelper.
-- =============================================
CREATE PROCEDURE [dbo].[usp_RollbackAndReloadExpenses]
	@FiscalYear int = 2016, 
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @TSQL varchar(MAX) = ''

	-- Handle re-hiding 204 projects with less than $100 in expenses and reload project table: 
	SELECT @TSQL = '
	-- Rehide 204 projects with less than $100 in expenses: 
	UPDATE AllProjectsNew
	SET IsIgnored = 1 
	WHERE AccessionNumber IN (
		SELECT AccessionNumber 
		FROM   FFY_SFN_Entries
		WHERE IsExpired = 0 AND SFN = ''204''
		GROUP BY AccessionNumber HAVING ISNULL(SUM(Expenses),0) < 100
	)

	-- Reload the project table used by AD419 UI so that hidden projects will not be included:
	TRUNCATE TABLE Project
	INSERT INTO Project
	SELECT * FROM udf_AD419ProjectsForFiscalYear(' + CONVERT(varchar(4), @FiscalYear) + ') 
'
    IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)

   -- Clear all existing Associations and Expenses:
   SELECT @TSQL = '
   -- Clear all existing Associations and Expenses:
   TRUNCATE TABLE [dbo].[Associations]

   TRUNCATE TABLE [dbo].[AllExpenses]
'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)

	-- Transfer 204, 20x, and non-204, 20x expenses from the intermediate tables into Expenses, 
	-- and make associations for 204 and 20x expenses:
	SELECT @TSQL = '
	-- Transfer 204, 20x, and non-204, 20x expenses from the intermediate tables into Expenses, 
	-- and make associations for 204 and 20x expenses:
	DECLARE @return_value int
	EXEC @return_value = [dbo].[usp_TransferExpensesAndAssociate]
	@FiscalYear = ' + CONVERT(varchar(4), @FiscalYear) + ', @IsDebug = 0

	SELECT	''Return Value'' = @return_value
'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)

	-- Transfer the CE values to the Expenses and Associations tables using the following:
	SELECT @TSQL = '
	-- Transfer the CE values to the Expenses and Associations tables:
	DECLARE @return_value1 int
	EXEC	@return_value1 = [dbo].[sp_Repopulate_AD419_CE]
			@FiscalYear = 9999,
			@SFN = N''220'',
			@IsDebug = 0

	SELECT	''Return Value'' = @return_value1
'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)

	-- Transfer field station values into expenses and auto-associate:
	SELECT @TSQL = 	'
	-- Transfer field station values into expenses and auto-associate:
	DECLARE @return_value2 int
	EXEC	@return_value2 = [dbo].[sp_INSERT_22F_EXPENSES_INTO_EXPENSES]
			@FiscalYear = ' + CONVERT(varchar(4), @FiscalYear) + ',
			@IsDebug = 0

	SELECT	''Return Value'' = @return_value2
'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)

	-- Adjust expenses' FTE_SFN for 241 Employees by calling:
		SELECT @TSQL = '
	-- Adjust expenses'' FTE_SFN for 241 Employees:
	DECLARE	@return_value3 int

	EXEC @return_value3 = [dbo].[sp_Adjust241FTE]
			
	SELECT	''Return Value'' = @return_value3
'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)

    -- Remap ADNO AGARGAA employee expenses to AIND:
	SELECT @TSQL = '
	-- Remap ADNO AGARGAA employee expenses to AIND:
	DECLARE	@return_value4 int 
	
	EXEC	@return_value4 = [dbo].[sp_Associate_AD419_IND_with_AIND] @IsDebug = 0
			
	SELECT	''Return Value'' = @return_value4
	'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)

	-- Change OrgR for Associate Deans section:

	SELECT @TSQL = '
	-- Change the OrgR for Associate Deans to ADNO to allow automatic proration across all 
	-- College''s projects and to hide corresponding expenses for AD-419 reporting module:
	DECLARE	@return_value3 int '
	SELECT @TSQL += '
	EXEC	@return_value3 = [dbo].[usp_RemapAssociateDeansExpenseDepartmentsToADNO] @IsDebug = ' + CONVERT(varchar(1), @IsDebug) + '
			
	SELECT	''Return Value'' = @return_value3
'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)

	-- Auto-Associate 241 Employees:
	SELECT @TSQL = '
	-- Auto-Associate 241 Employees:
	DECLARE	@return_value5 int
	
	EXEC @return_value5 = [dbo].[usp_InsertAssociationsFor241Expenses] @IsDebug = 0
			
	SELECT	''Return Value'' = @return_value5
'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)

	-- The process should now be at the point where we can do pre-association review again, so 
	-- we will reset the process category and process status after and including
	-- "Manually Associating Any Remaining Independent (AIND) 241 Employee Expenses":

	SELECT @TSQL = '
	-- Reset IsCompleted back to false for anything after and including CategoryId 27
	-- so we can resume the process at "Manually Associating Any Remaining Independent (AIND) 241 Employee Expenses"

	UPDATE [dbo].[ProcessCategory]
	SET IsCompleted = 0 
	WHERE Id IN 
	(
		select id
		from processCategory
		where sequenceOrder >= 
		(
			select SequenceOrder 
			FROM processCategory 
			WHERE ID = 27
		)
	)

	 UPDATE [dbo].[ProcessStatus]
	 SET IsCompleted = 0
	 WHERE Id IN 
	 (
		select id
		FROM processStatus
		WHERE CategoryId IN 
		(
			select id
			from processCategory
			where sequenceOrder >= 
			(
				select SequenceOrder 
				FROM processCategory 
				WHERE ID = 27
			)
		)
	)
'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)
END