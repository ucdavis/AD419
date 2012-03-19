-- =============================================
-- Author:		Ken Taylor
-- Create date: 03/03/2011
-- Description:	Rebuilds all FISDataMart indexes except TransLog,
-- and executes or prints them depending on @IsDebug provided
-- by calling sproc usp_RebuildAllTableIndexes multiple times.
--
-- Usage: EXEC usp_RebuildFISIndexes [@MaxFragmentationPermitted = {0-100}][, @IsDebug = 1/0] -- Set to 1 to print SQL only.
--
-- Modifications:
-- 20110120 by kjt: 
--		Revised to dynamically determine table and index names and then build rebuild index statments.
--     and executes or prints them depending on @IsDebug provided.
--	20110303 by kjt:
--		Added param for setting max fragmentation permitted: @MaxFragmentationPermitted.
--		Revised to call usp_RebuildAllTableIndexes
--	20110427 by kjt:
--		Added '%' to NOT LIKE 'TransLog%'
-- =============================================
CREATE Procedure [dbo].[usp_RebuildFISIndexes]
	@MaxFragmentationPermitted int = 5, --The maximum fragmentation permitted (in percent).
	@IsDebug bit = 0 --Set to 1 to print SQL to be executed only.
AS

BEGIN

	DECLARE @TSQL varchar(MAX) = ''

	PRINT '--Rebuilding all FISDataMart indexes except TransLog...'
	declare @tblName varchar(50);
	DECLARE MyTableNameCursor CURSOR FOR select distinct name from sysobjects where xtype='U' AND name NOT LIKE 'TransLog%'
	-- First update all indexes except on TransLog table, LoadTransLog, and then update TransLog indexes.
	OPEN MyTableNameCursor
	FETCH NEXT FROM MyTableNameCursor INTO @tblName
	
	DECLARE @StartTime datetime = (SELECT GETDATE())
	DECLARE @TempTime datetime = (SELECT @StartTime)
	DECLARE @EndTime datetime = (SELECT @StartTime)
	PRINT '--Start time: ' + CONVERT(varchar(20),@StartTime, 114)	+ '
	'
	
	WHILE (@@FETCH_STATUS <> -1)
		BEGIN
			SELECT @TSQL = ''

			SELECT @TSQL = 'EXEC usp_RebuildAllTableIndexes @TableName = ' +@tblName + ', @MaxFragmentationPermitted = ' + CONVERT(varchar(3), @MaxFragmentationPermitted) + ', @IsDebug = ' + CONVERT(char(1), @IsDebug)

			IF @IsDebug = 1
				PRINT @TSQL
			ELSE
				BEGIN
					EXEC (@TSQL)
				END
		
			FETCH NEXT FROM MyTableNameCursor INTO @tblName
		END
	CLOSE MyTableNameCursor
	DEALLOCATE MyTableNameCursor
	
	SELECT @StartTime = (@TempTime)
	SELECT @EndTime = (GETDATE())
	PRINT '
--Total Execution Time: ' + CONVERT(varchar(20),@EndTime - @StartTime, 114)
END
