-- =============================================
-- Author:		Ken Taylor
-- Create date: January 4, 2012
-- Description:	(Drops) and/or Creates the finalized AD419 Non-Admin with prorated 
-- amounts "flat" table that is the final processing step and used as the datasource 
-- for the report server's AD419 Non-Admin with Prorate Amounts report.
-- This is run automatically as the last step of usp_Create AD419_FinalReportTables.
-- Usage:
-- EXEC [dbo].[usp_CreateFlatTableForNonAdminWithProatedValuesReport] <source_table_name>, <destination_table_name>, <debug_flag>, <verbose_debug_flag>
-- EXEC [dbo].[usp_CreateFlatTableForNonAdminWithProatedValuesReport] @IsDebug = 1
-- =============================================
CREATE PROCEDURE usp_CreateFlatTableForNonAdminWithProatedValuesReport 
	-- Add the parameters for the stored procedure here
	@NonAdminWithProratedExpensesTableName varchar(255) = 'NonAdminWithProRatesTotalsTable', --Source table name
	@Flat_NonAdminWithProratedExpensesTableName varchar(255) = 'Flat_NonAdminWithProratedExpensesTable', --Destination table name
	@IsDebug bit = 0, --1 to print various status messages; 0 otherwise
	@IsVerboseDebug bit = 0 -- 1 to print inner SQL statements built and executed by server; 0 otherwise for silent.
AS
BEGIN
	-- Uncomment for exporting code and testing purposes.
	--DECLARE @NonAdminWithProratedExpensesTableName varchar(255) = 'NonAdminWithProRatesTotalsTable'
	--DECLARE @Flat_NonAdminWithProratedExpensesTableName varchar(255) = 'Flat_NonAdminWithProratedExpensesTable' 
	--DECLARE @IsDebug bit = 1
	--DECLARE @IsVerboseDebug bit = 0
	
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	DECLARE @TSQL varchar(MAX) = ''
	--Create a flat table for the Report Server's Non-Admin with Proated Values Report,
    --so that it can have a dynamic number of SFN prorate and SFN plus prorate columns:
	
			IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[' + @Flat_NonAdminWithProratedExpensesTableName + ']') AND type in (N'U'))
			BEGIN
				DECLARE @DropTableSQL varchar(255) = 'DROP TABLE [dbo].[' + @Flat_NonAdminWithProratedExpensesTableName + ']'
				IF @IsDebug = 1 PRINT '--Table ' + @Flat_NonAdminWithProratedExpensesTableName + ' exists; 
		' + @DropTableSQL
				exec sp_executesql N'EXEC(@DropTableSQL)', N'@DropTableSQL varchar(255)', @DropTableSQL
			END
		
		SELECT @TSQL = '
		create table [dbo].[' + @Flat_NonAdminWithProratedExpensesTableName + ']
		(
			loc char(2), 
			dept char(3), 
			proj char(4), 
			project varchar(24), 
			PI varchar(30), 
			accession char(7), 
			SFN varchar(20), 
			expense decimal(16,2), 
			position int, 
			isFTE bit
		)
'
		IF @IsDebug = 1 PRINT @TSQL
			
		EXEC(@TSQL)

		-- get the name of the fields we're dealing with:
		declare MyFieldCursor Cursor for 
			SELECT   COLUMN_NAME, ORDINAL_POSITION 
			FROM     INFORMATION_SCHEMA.COLUMNS 
			WHERE TABLE_NAME = @NonAdminWithProratedExpensesTableName 
				AND COLUMN_NAME not in ('loc', 'dept', 'proj', 'project', 'accession', 'PI')
			ORDER BY ORDINAL_POSITION ASC 
			FOR READ ONLY; 
		
		open MyFieldCursor
		declare @ColumnName varchar(50), @Position int
	
		fetch next from MyFieldCursor into @ColumnName, @Position
		
		while @@FETCH_STATUS <> -1
			BEGIN --while have more SFNs to add to flat table
				-- create a new row for each column in the table, for each project:
				DECLARE @INNER_SQL varchar(MAX) = '
				DECLARE @TSQL varchar(MAX) = ''''
				DECLARE @RowCount int = 0
				DECLARE @IsDebug bit = ' + CONVERT(char(1), @IsDebug) + '
				DECLARE @IsVerboseDebug bit = ' + CONVERT(char(1), @IsVerboseDebug) + '
				declare MyCursor Cursor for 
					select loc, dept, proj, project, accession, PI
					from dbo.[' + @NonAdminWithProratedExpensesTableName + '] 
					order by accession  
					for READ ONLY;
		
				open MyCursor
				declare @loc char(2), @dept char(3), @proj char(4), @project varchar(24), @PI varchar(30), @accession char(7)
		
				fetch next from MyCursor into @loc, @dept, @proj, @project, @accession, @PI
		
				while @@FETCH_STATUS <> -1  
					BEGIN --while have more projects to add for given SFN
						SELECT @RowCount = (@RowCount + 1)
						
						Select @TSQL = ''insert into dbo.[' + @Flat_NonAdminWithProratedExpensesTableName + '](loc, dept, proj, project, PI, accession, SFN, expense, position, isFTE)
						values ('''''' + @loc + '''''', '''''' +  @dept + '''''', '''''' +  @proj + '''''', '''''' +  @project + '''''', '''''' +   REPLACE(@PI, '''''''', '''''''''''')  + '''''', '''''' + @accession + '''''', ''''' + @ColumnName + ''''', 
						(select ' + @ColumnName + ' from dbo.[' + @NonAdminWithProratedExpensesTableName + '] where accession = '''''' + @accession +''''''), ' + CONVERT(varchar(20), @Position) + '''
						
						-- This sets the isFTE bit so that the report server can format the
						-- field with 0.00 for expense amounts and 0.0 for FTE amounts. 
						If ''' + @ColumnName + ''' not like ''f24%'' AND ''' + @ColumnName + ''' != ''f350''
							BEGIN
								-- Expense
								Select @TSQL += '', 0)''
							END
						ELSE
							BEGIN
								-- FTE
								Select @TSQL += '', 1)''
							END
							
						If @IsVerboseDebug = 1
							print @TSQL
							
						exec(@TSQL)
						
						fetch next from MyCursor into @loc, @dept, @proj, @project, @accession, @PI
					END --while have more projects to add for given SFN
					IF @IsDebug = 1 PRINT ''--Num rows inserted for ' + @ColumnName + ': '' + CONVERT(varchar(5), @RowCount) + ''''
					
				close MyCursor
				deallocate MyCursor
				'
				
				IF @IsVerboseDebug = 1 PRINT @INNER_SQL
				EXEC(@INNER_SQL)
					
				fetch next from MyFieldCursor into @ColumnName, @Position
			END --while have more SFNs add to flat table
			
		close MyFieldCursor
		deallocate MyFieldCursor

END --Create a flat table for the Non-Admin with Proated Values Report.
