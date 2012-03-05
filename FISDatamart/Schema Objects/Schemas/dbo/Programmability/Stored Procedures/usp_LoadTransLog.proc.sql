-- =============================================
-- Author:		Ken Taylor
-- Create date: April 12, 2011
-- Description:	Wrapper to use for which trans log load 
-- sproc to call depending if a table is partitioned of not.
-- This replaces the former usp_LaodTransLog sproc, which has
-- been renamed to usp_LoadTransLogNonPartitioned.
-- Modifications:
-- 20110414 by kjt:
--	Modified to call renamed usp_LoadTransLogNonPartitioned which is now usp_LoadNamedTransLogTable,
--	as usp_LoadNamedTransLogTable is also called by usp_LoadTableUsingSwapPartitions.
--  Added call to usp_DeleteFromTableUsingPeriods if non-partitioned table.
-- =============================================
CREATE PROCEDURE [dbo].[usp_LoadTransLog] 
	@FirstDateString varchar(16) = null,
		--earliest date to download  
		--optional, defaults to highest date in table
	@LastDateString varchar(16) = null,
		-- latest date to download 
		-- optional, defaults to today's date.
	@GetUpdatesOnly bit = 0, -- This parameter is just a placeholder so that it can be called
		-- using usp_Download_TableRecordsForFiscalYear.
	@TableName varchar(255) = 'TransLog', --Can be passed another table name, i.e. TransLog, etc.
	@IsDebug bit = 0 -- Set to 1 just print the SQL and not actually execute it. 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	--SET NOCOUNT ON;
	DECLARE @TSQL varchar(MAX) = '';

    IF dbo.udf_IsPatitionedTable(@TableName) = 1
		BEGIN
			SELECT @TSQL = '
			EXEC usp_LoadTableUsingSwapPartitions 
				@FirstDateString = ''' + @FirstDateString + ''', 
				@LastDateString = ''' + @LastDateString + ''', 
				@GetUpdatesOnly = ' + CONVERT(char(1),@GetUpdatesOnly) + ', 
				@TableName = ''' + @TableName + ''',
				@IsDebug = ' + CONVERT(char(1),@IsDebug) + '
			'
		END
	ELSE
		BEGIN
			SELECT @TSQL = '
			EXEC usp_DeleteFromTableUsingPeriods
				@FirstDateString = ''' + @FirstDateString + ''', 
				@LastDateString = ''' + @LastDateString + ''', 
				@GetUpdatesOnly = ' + CONVERT(char(1),@GetUpdatesOnly) + ', 
				@TableName = ''' + @TableName + ''',
				@UseFiscalPrefix = 1, 
				@IsDebug = ' + CONVERT(char(1),@IsDebug) + '
			
			EXEC usp_LoadNamedTransLogTable 
				@FirstDateString = ''' + @FirstDateString + ''', 
				@LastDateString = ''' + @LastDateString + ''', 
				@GetUpdatesOnly = ' + CONVERT(char(1),@GetUpdatesOnly) + ', 
				@TableName = ''' + @TableName + ''',
				@IsDebug = ' + CONVERT(char(1),@IsDebug) + '
			'
		END
		
	IF @IsDebug = 1
		PRINT '/*' + @TSQL + '
*/'
	
	EXEC(@TSQL)
    
END
