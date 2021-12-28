

-- =============================================
-- Author:		Ken Taylor
-- Create date: January 20, 2011
-- Description:	Given a table name, rebuild, which also includes enabling
-- formerly disabled indexes, all indexes that are either disabled OR 
-- whose average fragmentation is greater than the default value of the
--  @MaxFragmentationPermitted param, i.e. 5%, or the user provided value
-- passed in including the PK and/or clustered index for the table name provided.
--
-- Usage:
--
-- EXEC usp_RebuildAllTableIndexes @TableName = <table_name>[, @MaxFragmentationPermitted = {0-100}][, @IsDebug = {0/1}]
--
-- Modifications:
--	20110303 by kjt:
--		Added param for setting max fragmentation permitted: @MaxFragmentationPermitted.
--	20110304 by kjt:
--		Revised logic to handle rebuilding disabled indexes also, because these would not have been rebuit otherwise.
--		This meant changing the INNER JOIN with sys.dm_db_index_physical_stats to a LEFT OUTER JOIN because 
--		disabled indexes are not returned by this function, only enabled ones,  This is because the purpose of 
--      sys.dm_db_index_physical_stats is to return fragmentation which is non-applicable for disabled indexes.
--		Therefore, the LEFT OUTER JOIN is required to obtain the disabled indexes as well.  This also required
--		modifying the where clause slightly as indicated below:
--
-- from: 
--
--WHERE 
--	(o.id = i.id and o.name = @TableName) AND 
--	(i.status < 9999) AND (ps.avg_fragmentation_in_percent > @MaxFragmentationPermitted)
--
-- to:
--
--WHERE 
--	(o.id = i.id and o.name = @TableName) AND 
--	(i.status < 9999) AND
--	(
--		(ps.avg_fragmentation_in_percent > @MaxFragmentationPermitted) OR
--		(i.first IS NULL) --disabled.
--	)
--	20110310 by kjt:
--		Changed (ps.avg_fragmentation_in_percent > @MaxFragmentationPermitted) OR
--		(i.first IS NULL) --disabled.
--
-- to
--
--		(ps.avg_fragmentation_in_percent > @MaxFragmentationPermitted) OR
--		(ps.avg_fragmentation_in_percent IS NULL) --disabled.
-- in order to correctly handle partitioned indexes.
--
-- Usage: 
/*
	USE [FISDataMart]
	GO

	DECLARE @return_value int,
		@TableName varchar(255) = 'AnotherLaborTransactions', 
		@MaxFragmentationPermitted int = 5,
		@MaxFragmentationToReorganize int = 30,
		@IsDebug bit = 0 

	SET NOCOUNT ON;

	EXEC	@return_value = [dbo].[usp_RebuildAllTableIndexes]
			@TableName = @TableName,
			@MaxFragmentationPermitted = @MaxFragmentationPermitted,
			@MaxFragmentationToReorganize = @MaxFragmentationToReorganize,
			@IsDebug = @IsDebug

	IF @IsDebug = 0
		SELECT	'Return Value' = @return_value
	SET NOCOUNT OFF;

GO

*/
--
-- Modifications:
--	20210723 by kjt: Revised to 
--		Do nothing of less than threshold @MaxFragmentationPermitted (5%),
--		Reorganize between threshold and @MaxFragmentationToReorganize (30%)
--		Rebuild if >  @MaxFragmentationToReorganize (30%).
--	Added new parameter to allow setting of MaxFragmentationToReorganize, which is
--		the maximum amount of fragmentation for which we'll perform a reorganization.
--		Any amount > MaxFragmentationToReorganize results in an full index rebuild.
--
-- =============================================
CREATE PROCEDURE [dbo].[usp_RebuildAllTableIndexes] 
	-- Add the parameters for the stored procedure here
	@TableName varchar(255) = null, 
	@MaxFragmentationPermitted int = 5, --The maximum fragmentation permitted prior to a reorganize (in percent).
	@MaxFragmentationToReorganize int = 30, -- The maximum fragmentation permitted prior to a rebuild (in percent).
	@IsDebug bit = 0 --Set to 1 to only print SQL to be executed.
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
    DECLARE @TSQL varchar(MAX) = ''

	DECLARE @tblName varchar(255), @IndexName varchar(255) = '', @AvgFragPct decimal (5,2)

	DECLARE MyCursor CURSOR FOR SELECT 
	o.name as TableName, 
	i.name AS IndexName,
	ps.avg_fragmentation_in_percent AS AvgFragmentationInPercent
FROM 
	sysobjects o, 
	sysindexes i
LEFT OUTER JOIN 
	sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, NULL) AS ps
	ON 
		i.id = ps.object_id AND 
		ps.index_id = i.indid
WHERE 
	(o.id = i.id and o.name = @TableName) AND 
	(i.status < 9999) AND
	(
		(ps.avg_fragmentation_in_percent > @MaxFragmentationPermitted) OR
		(ps.avg_fragmentation_in_percent IS NULL) --disabled.
	)
ORDER BY 
	i.status DESC

	-- 0 user defined, non-PK, non-clustered.
	-- 2066, 16, 18 Clustered
	-- 2 Unique

	DECLARE @StartTime datetime = (SELECT GETDATE())
	DECLARE @TempTime datetime = (SELECT @StartTime)
	DECLARE @EndTime datetime = (SELECT @StartTime)
	PRINT '--Rebuilding/Enabling ALL indexes on table: ' + @TableName + '
--Start time: ' + CONVERT(varchar(20),@StartTime, 114)	+ '
'
	OPEN MyCursor

	Fetch NEXT FROM MyCursor INTO @tblName, @IndexName, @AvgFragPct
    IF @@FETCH_STATUS = -1
		BEGIN
			PRINT '--No ' + @TableName + ' table index(es) are disabled and/or
--no index fragmentation > ' + CONVERT(varchar(3), @MaxFragmentationPermitted) + '%.  No ' + @TableName + ' table indexes will be rebuilt.'
		END
	ELSE
		BEGIN
			WHILE (@@FETCH_STATUS <> -1)
			BEGIN
				IF @IsDebug = 1
					SELECT @TSQL = '--Index: ' + @IndexName + ' has ' + CONVERT(varchar(20), @AvgFragPct) + '%.
		'
				DECLARE @IndexAction varchar(20) = 'rebuild'
				-- You must first rebuild an index after it''s been disabled.  
				-- Once it's rebuilt, it can be reorganized if appropriate.
				IF @AvgFragPct IS NULL OR @AvgFragPct > @MaxFragmentationToReorganize
				  SELECT @TSQL += 'ALTER INDEX [' + @IndexName + '] ON [dbo].[' + @TableName + '] REBUILD PARTITION = ALL WITH ( PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, ONLINE = OFF, SORT_IN_TEMPDB = OFF )
		'
				ELSE
				-- Reorganize any index that's enabled and has a @AvgFragPct between @MaxFragmentationPermitted and @MaxFragmentationToReorganize.
				  BEGIN
					SELECT @IndexAction = 'reorganize'
					SELECT @TSQL += 'ALTER INDEX [' + @IndexName + '] ON [dbo].[' + @TableName + '] REORGANIZE  WITH ( LOB_COMPACTION = ON )
		'		  END
				
				IF @IsDebug = 1
					PRINT @TSQL
				ELSE
					BEGIN
						EXEC (@TSQL)
						SELECT @StartTime = (@EndTime)
						SELECT @EndTime = (GETDATE())
						PRINT '--Time to ' + @IndexAction + ' ' + @IndexName + ' on table ' +@TableName + ': ' + CONVERT(varchar(20),@EndTime - @StartTime, 114)
					END
				Fetch NEXT FROM MyCursor INTO @tblName, @IndexName, @AvgFragPct
			END --WHILE
		END

	CLOSE MyCursor
	DEALLOCATE MyCursor

	SELECT @StartTime = (@TempTime)
	SELECT @EndTime = (GETDATE())
	PRINT '--Stop Time: ' +  CONVERT(varchar(20),@EndTime, 114) + '
--Total Execution Time: ' + CONVERT(varchar(20),@EndTime - @StartTime, 114) + '

'

END