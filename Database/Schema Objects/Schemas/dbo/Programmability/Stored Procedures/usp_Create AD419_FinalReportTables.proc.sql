/*
PROGRAM: usp_Create AD419_FinalReportTables
BY:	Ken Taylor  02/01/2010
USAGE/TEST:	
EXEC	[dbo].[usp_Create AD419_FinalReportTables]
		@ReportType = 0, -- 0 for select * from various tables once tables have been created
						 -- 1 for create tables after all projects have been associated.  Note 
							this "report" must be run first before running option 0.
		@IsDebug = 0

DESCRIPTION: 
	This sproc will create the AD419 Final Report Table set for each of the spreadsheets in the 
	AD419 Final Report Workbook as described below:
	
	1. AD419_Non-Admin table for the AD419 Non-Admin worksheet
	2. AD419_Non-Admin_WithProratedAmounts table for AD419 Non-Admin with Prorated amounts worksheet
	3. AD419_Admin table for AD419 Admin worksheet with the affected SFNs replaced with
		the sum of the SFN and its corresponding prorated amount.
	4. AD419_UnassociatedTotals for the AD419 Unassociated (Admin) Totals worksheet.  These are the SFNs
		that need to be prorated across the various projects as appropriate.
	5. AD419_Flat_NonAdminWithProrates - A flat version of the AD419_Non-Admin_WithProratedAmounts table, which
		the report server can dynamically use to create its version of the AD419 Non-Admin with Prorated Amounts
		Report without having to know before hand which SFNs have SFN_prorate and SFN_plus_prorate fields.

CURRENT STATUS:
NOTES:
CALLED BY: 
CLIENTS/RELATED FILES/DEPENDENCIES:
TODO LIST:
MODIFICATIONS:

2010-12-16 by kjt: Revised location and project number extraction logic 
	to account for some projects having just "D" as a location and not "D*".
2011-12-14 by kjt: Added logic to exclude cluster expenses.
2012-01-05 by kjt: Revised to allow revised prorating scheme to handle cluster expenses.
*/
-------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[usp_Create AD419_FinalReportTables]
	@ReportType int = 0, -- 0: Display the reports from already created tables (default); 1: Create/Recreate the report tables.
	@NonAdminTableName varchar(255) = '', --The table name, i.e. AD419_Non-Admin, for the Final Non-Admin Report.
	@UnassociatedTotalsTableName varchar(255) = '', --The table name, i.e. AD419_UnassociatedTotals, for the Unassociated Totals Report.
	@Flat_NonAdminWithProratedExpensesTableName varchar(255) = '', --The name of the table,
	-- i.e. AD419_Flat_NonAdminWithProrates, that will contain
	-- the "flattened" non-admin report data for running the report server's AD-419 Non-Admin Report with Prorate Amounts report.
	@AdminTableName varchar(255) = '',  --Table name suffix for <AdminUnit>Admin tables
	@NonAdminWithProratedAmountsTableName varchar(255) = '', --Table name suffix for <AdminUnit>NonAdminWithProratedAmounts tables
	@FinalReportTablesNamePrefix varchar(10) = '', --The table name prefix, i.e. 'AD419_' and variable name for the consolidated AD419 final report tables
	@AllTableNamePrefix varchar(10)= '', --The table name prefix, i.e. 'All' and variable name for the table containing all the unassociated totals.
	-- This will be used later as the source table when creating the AD419_UnassociatedTotals view.
	@IsDebug bit = 0, -- Set to 1 to display debug text.
	@IsVerboseDebug bit = 0 --Set to 1 to display verbose debug text.
AS

/*
0: Display the reports from already created tables (default)
1: Create/Recreate the report tables.

declare @ReportType int = 0
declare @IsDebug bit = 0
*/

BEGIN -- Main program
	SET NOCOUNT ON
	
	-- Set the appropriate value based on the input param, table value or default value for the various table name, prefix and suffix variables:
	SELECT @NonAdminTableName = (SELECT dbo.udf_GetParameterValue (@NonAdminTableName, 'AD419_Non-Admin', 'NonAdminTableName'))
	SELECT @UnassociatedTotalsTableName = (SELECT dbo.udf_GetParameterValue (@UnassociatedTotalsTableName,  'UnassociatedTotals', 'UnassociatedTotalsTableName'))
	SELECT @Flat_NonAdminWithProratedExpensesTableName = (SELECT dbo.udf_GetParameterValue (@Flat_NonAdminWithProratedExpensesTableName, 'Flat_NonAdminWithProrates', 'Flat_NonAdminWithProratedExpensesTableName'))
	SELECT @AdminTableName = (SELECT dbo.udf_GetParameterValue (@AdminTableName, 'AdminTable', 'AdminTableName'))
	SELECT @NonAdminWithProratedAmountsTableName = (SELECT dbo.udf_GetParameterValue (@NonAdminWithProratedAmountsTableName, 'Non-AdminWithProratedAmounts', 'NonAdminWithProratedAmountsTableName'))
	SELECT @FinalReportTablesNamePrefix = (SELECT dbo.udf_GetParameterValue (@FinalReportTablesNamePrefix, 'AD419', 'FinalReportTablesNamePrefix'))
	SELECT @AllTableNamePrefix = (SELECT dbo.udf_GetParameterValue (@AllTableNamePrefix, 'All', 'AllTableNamePrefix'))
	
-- Check the @ReportType variable: 0 for print AD419 reports; 1 for create AD419 Report tables:
IF @ReportType = 0
	BEGIN 
		DECLARE @AdminUnitForReport varchar(10) = @FinalReportTablesNamePrefix
		IF @AdminUnitForReport IS NULL OR @AdminUnitForReport LIKE ''
			SELECT @AdminUnitForReport = @AllTableNamePrefix
		
	-- Output the reports:
		IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[' + @NonAdminTableName + ']') AND type in (N'U'))
			OR (NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[' + @AdminUnitForReport + '_' + @UnassociatedTotalsTableName + ']') AND type in (N'U'))
				AND NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[' + @AdminUnitForReport + '_' + @UnassociatedTotalsTableName +']') AND type in (N'V')))
			OR NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[' + @AdminUnitForReport + '_' + @NonAdminWithProratedAmountsTableName + ']') AND type in (N'U'))
			OR NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[' + @AdminUnitForReport + '_' + @AdminTableName +']') AND type in (N'U'))
			BEGIN
				Select 'Run 
				EXEC [dbo].[usp_Create AD419_FinalReportTables] @ReportType = 1
				first before running option 0.';
				Return -1;
			END
		ELSE
			BEGIN --Else tables exist
				
				select @AdminUnitForReport + ' Unassociated Totals Report: ' as 'Report Name:'
				EXEC ('select * from [AD419].[dbo].[' + @AdminUnitForReport + '_' + @UnassociatedTotalsTableName + '];')
				
				-- Output the AD419_Non-Admin Report:
				Select @AdminUnitForReport +' Non-Admin Report (from [' + @NonAdminTableName +'] table): ' as 'Report Name:' 
				EXEC ('select * from [AD419].[dbo].[' + @NonAdminTableName + '];')
					
				-- Output the AD419_Non-Admin_WithProratedAmounts table:
				select @AdminUnitForReport + ' Non-Admin Report with Prorated Amounts (from [' + @AdminUnitForReport + '_' + @NonAdminWithProratedAmountsTableName + '] table: ' as 'Report Name:'
				EXEC ('select * from [AD419].[dbo].[' + @AdminUnitForReport + '_' + @NonAdminWithProratedAmountsTableName + '];')
					
				-- Output the AD419_Admin Report:
				select @AdminUnitForReport + ' Admin Report (from [' + @AdminUnitForReport + '_' + @AdminTableName + '] table (already has prorated amounts added to appropriate SFNs)): ' as 'Report Name:'
				EXEC ('select * from [AD419].[dbo].[' + @AdminUnitForReport + '_' + @AdminTableName + '];')
			END --Else tables exist
	END --IF @ReportType = 0
ELSE
	BEGIN -- ELSE @ReportType != 0
		-- First we need to check to see that all non-excluded expenses have
		-- been associated
		DECLARE @OrgRExclusions  TABLE (OrgR char(4))
		INSERT INTO @OrgRExclusions VALUES ('ADNO');
		-- This will get any additional admin clusters like ACL1-ACL5:
		INSERT INTO @OrgRExclusions SELECT [AdminClusterOrgR] FROM [AD419].[dbo].[ReportingOrg] WHERE [IsAdminCluster] = 1 AND [IsActive] = 1;

		DECLARE @Unassociated_Non_CAES_Expenses TABLE (OrgR varchar(4), Spent float, FTE float)

		INSERT INTO @Unassociated_Non_CAES_Expenses
		SELECT  OrgR, SUM(Expenses) AS Spent, SUM(FTE) AS FTE
				FROM         Expenses
				WHERE     (isAssociated = 0) AND --( OrgR NOT IN (@OrgRExclusions) )
					( OrgR NOT IN (SELECT * FROM @OrgRExclusions) )
				GROUP BY OrgR
				ORDER BY OrgR
			
		IF @@ROWCOUNT <> 0
			BEGIN -- Check that all departments are fully associated
				PRINT 'WARNING: Not all departments fully associated'
				SELECT * FROM @Unassociated_Non_CAES_Expenses
				RETURN -1
			END -- Check that all departments are fully associated.
		ELSE
			BEGIN -- Else all departments are fully associated so create/recreate tables.
				DECLARE @AdminUnit varchar(5) = '' 
				DECLARE @TSQL varchar(MAX) = ''
				DECLARE @MyNonAdminWithProratedExpensesTableName varchar(255) = ''
				DECLARE @MyFlat_NonAdminWithProratedExpensesTableName varchar(255) = ''
				DECLARE @NonAdminWithProRatesTotalsTableName varchar(255) = @FinalReportTablesNamePrefix + '_' + @NonAdminWithProratedAmountsTableName
				DECLARE @AdminTotalsTableName varchar(255) = @FinalReportTablesNamePrefix + '_' + @AdminTableName
				---- Create/Recreate the ProjSFN Table 
				---- Used in udf_GetReportList and usp_GetSFN_UnassociatedTotal
				--DECLARE @ProjSFN_Table AS [dbo].[ProjectSFN_TableType]
				--INSERT INTO @ProjSFN_Table SELECT * FROM udf_GetProjectSFN()
				
				--IF @IsDebug = 1 PRINT 'Completed creating projectSFN table'
				
				-- Create, Re-create the Non-Admin Report Table
				-- *This will be used for the Final Non-Admin report
				IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[' + @NonAdminTableName + ']') AND type in (N'U'))
					EXEC('drop table [AD419].[dbo].[' + @NonAdminTableName + ']')
				-- Save the Non-Admin report to the database:
				EXEC('
				select * into [AD419].[dbo].[' + @NonAdminTableName + '] from [AD419].[dbo].[ReportsList] order by dept, proj')
				IF @IsDebug = 1 PRINT 'Completed creating Non-Admin table'
				
				-- Create, Re-create the Admin Report Table -- Basically the non-admin table with the admin amounts 
				-- pro-rated across the various projects' SFNs as appropriate.
				-- This is a template table used as a starting place for the individual admin units' admin reports
				IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[' + @AdminTableName + '_temp]') AND type in (N'U'))
					EXEC('drop table [AD419].[dbo].[' + @AdminTableName + '_temp]')
				-- Save the Admin report to the database:
				EXEC('select * into [AD419].[dbo].[' + @AdminTableName + '_temp] from [AD419].[dbo].[' + @NonAdminTableName + ']')
				IF @IsDebug = 1 PRINT 'Completed creating Admin temp table'
				
				-- Drop and re-create AdminTotalsTable to keep track of running totals:
				-- *This will be used for the Final Admin Report 
				IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[' + @FinalReportTablesNamePrefix + '_' + @AdminTableName + ']') AND type in (N'U'))
					EXEC('drop table [AD419].[dbo].[' + @FinalReportTablesNamePrefix + '_' + @AdminTableName + ']')
				-- This is where we store the running totals for the admin expenses
				EXEC('SELECT * INTO AD419.dbo.[' + @FinalReportTablesNamePrefix + '_' + @AdminTableName + '] FROM [AD419].[dbo].[' + @AdminTableName + '_temp]')
				IF @IsDebug = 1 PRINT 'Completed creating AdminTotalsTable table'
				
				-- Create, Re-create the AdminWithProratedAmountsTemp Table
				-- This is as a template table used as a starting place for the individual admin units' non-admin with prorated amounts reports
				EXEC('
				DECLARE @NonAdminTable AS NonAdminTableType;
				INSERT into @NonAdminTable SELECT * FROM [' + @NonAdminTableName + '];
				
				DECLARE @SFN_UnassociatedTotal AS SFN_UnassociatedTotalsType
				INSERT INTO @SFN_UnassociatedTotal EXEC usp_GetSFN_UnassociatedTotals @NonAdminTable, ''' + @AllTableNamePrefix + ''' 
				
				EXEC [dbo].[usp_DropAndCreateAdminWithProratedAmountsTable] 
					@OutputTableName = [' + @NonAdminWithProratedAmountsTableName + '_temp], 
					@NonAdminTableName = [' + @NonAdminTableName + '], 
					@NonAdminTable = @NonAdminTable, 
					@SFN_UnassociatedTotal = @SFN_UnassociatedTotal,
					@IsDebug = ' + @IsDebug
				)

				-- Drop and re-create NonAdminWithProRatesTotalsTable to keep track of running totals:
				-- *This will be used for the final Non-Admin with Prorated Amounts report.
				IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[' + @FinalReportTablesNamePrefix + '_' + @NonAdminWithProratedAmountsTableName + ']') AND type in (N'U'))
					EXEC('drop table [AD419].[dbo].[' + @FinalReportTablesNamePrefix + '_' + @NonAdminWithProratedAmountsTableName + ']')
				EXEC('SELECT * INTO AD419.dbo.[' + @FinalReportTablesNamePrefix + '_' + @NonAdminWithProratedAmountsTableName + '] FROM [dbo].[' + @NonAdminWithProratedAmountsTableName + '_temp]')
				
				-- This is a table variable containing '' for all admin units, plus ADNO.  It is then populated from the 
				-- [AD419].[dbo].[ReportingOrg] table WHERE IsAdminCluster = 1 for the remaining admin clusters
				DECLARE @AdminUnits TABLE (AdminUnit varchar(5))
				
				INSERT INTO @AdminUnits VALUES (@AllTableNamePrefix), ('ADNO')  -- '' is for ALL admin unit expenses, i.e. ADNO, ACL1-ACl5; ADNO is for the Dean's Office expenses.
				-- These are for the remaining admin clusters, currently ACL1-ACL5
				INSERT INTO @AdminUnits SELECT OrgR FROM [AD419].[dbo].[ReportingOrg] WHERE IsAdminCluster = 1
				
				DECLARE AdminUnitCursor Cursor for select AdminUnit from @AdminUnits for READ ONLY
				open AdminUnitCursor
			    
				fetch next from AdminUnitCursor into @AdminUnit
				while @@FETCH_STATUS <> -1 
					begin -- While more Admin Units to process
					
					PRINT 'Begin creating ' + @AdminUnit + ' admin unit reports...
'
						-- Prorate the individual admin unit's unassociated expenses across the projects of their corresponding 
						-- departments: 
						EXEC [dbo].[usp_ProrateAdminExpenses] 
							 @AdminUnit = @AdminUnit,
							 @AdminTotalsTableName = @AdminTotalsTableName, 
							 @NonAdminWithProRatesTotalsTableName = @NonAdminWithProRatesTotalsTableName, 
							 @NonAdminTableName = @NonAdminTableName,
							 @UnassociatedTotalsTableName = @UnassociatedTotalsTableName,
							 @NonAdminWithProratedAmountsTableName = @NonAdminWithProratedAmountsTableName,
							 @AdminTableName = @AdminTableName,
							 @AllTableNamePrefix = @AllTableNamePrefix,
							 @IsDebug = @IsDebug;
							 
						-- Create a flat table for all and each of the admin units, i.e., ADNO, and ACL1-ACL5:
						SELECT @MyNonAdminWithProratedExpensesTableName = @AdminUnit + '_' + @NonAdminWithProratedAmountsTableName
						SELECT @MyFlat_NonAdminWithProratedExpensesTableName = @AdminUnit + '_' + @Flat_NonAdminWithProratedExpensesTableName
						EXEC [dbo].[usp_CreateFlatTableForNonAdminWithProatedValuesReport]
						@NonAdminWithProratedExpensesTableName = @MyNonAdminWithProratedExpensesTableName,
						@Flat_NonAdminWithProratedExpensesTableName = @MyFlat_NonAdminWithProratedExpensesTableName,
						@IsDebug = @IsDebug,
						@IsVerboseDebug = @IsVerboseDebug;
						
						PRINT 'Finished creating ' + @AdminUnit + ' admin unit reports.
'
						fetch next from AdminUnitCursor into @AdminUnit
						-- Get next Admin Unit
					END -- While more Admin Units to process
										
				CLOSE AdminUnitCursor
				DEALLOCATE AdminUnitCursor
				
				-- Update the final report totals in the Category and Sub-Category Totals and Sub-totals
				-- in the Admin totals table:
				
				SELECT @TSQL = '
				Update AD419.dbo.[' + @FinalReportTablesNamePrefix + '_' + @AdminTableName + '] set f231 = (f201 + f202 + f203 + f204 + f205)
				Update AD419.dbo.[' + @FinalReportTablesNamePrefix + '_' + @AdminTableName + '] set f332 = (f219 + f209 + f310 + f308 + f311 + f316 + f312 + f313 + f314 + f315 + f318)
				Update AD419.dbo.[' + @FinalReportTablesNamePrefix + '_' + @AdminTableName + '] set f233 = (f220 + f22F + f221 + f222 + f223)
				Update AD419.dbo.[' + @FinalReportTablesNamePrefix + '_' + @AdminTableName + '] set f234 = (f231 + f332 + f233)
				Update AD419.dbo.[' + @FinalReportTablesNamePrefix + '_' + @AdminTableName + '] set f350 = (f241 + f242 + f243 + f244)
			'
				if @IsDebug = 1
					Print @TSQL
										
				EXEC(@TSQL)
				
				-- Update the final report totals in the Category and Sub-Category Totals and Sub-totals
				-- in the Non-Admin with Prorated expenses totals table:
				-- Note that this uses totals from the Admin totals table, so it must have already been updated, as in the previous step.
				 
				SELECT @TSQL = '
				Update AD419.dbo.[' + @FinalReportTablesNamePrefix + '_' + @NonAdminWithProratedAmountsTableName + '] set f231 = (f201 + f202 + f203 + f204 + f205)
				Update AD419.dbo.[' + @FinalReportTablesNamePrefix + '_' + @NonAdminWithProratedAmountsTableName + '] set f332 = (select f332 from AD419.dbo.[' + @FinalReportTablesNamePrefix + '_' + @AdminTableName + '] t2 where t2.accession = AD419.dbo.[' + @FinalReportTablesNamePrefix + '_' + @NonAdminWithProratedAmountsTableName + '].accession) 
				Update AD419.dbo.[' + @FinalReportTablesNamePrefix + '_' + @NonAdminWithProratedAmountsTableName + '] set f233 = (select f233 from AD419.dbo.[' + @FinalReportTablesNamePrefix + '_' + @AdminTableName + '] t2 where t2.accession = AD419.dbo.[' + @FinalReportTablesNamePrefix + '_' + @NonAdminWithProratedAmountsTableName + '].accession)
				Update AD419.dbo.[' + @FinalReportTablesNamePrefix + '_' + @NonAdminWithProratedAmountsTableName + '] set f234 = (select f234 from AD419.dbo.[' + @FinalReportTablesNamePrefix + '_' + @AdminTableName + '] t2 where t2.accession = AD419.dbo.[' + @FinalReportTablesNamePrefix + '_' + @NonAdminWithProratedAmountsTableName + '].accession)
				Update AD419.dbo.[' + @FinalReportTablesNamePrefix + '_' + @NonAdminWithProratedAmountsTableName + '] set f350 = (select f350 from AD419.dbo.[' + @FinalReportTablesNamePrefix + '_' + @AdminTableName + '] t2 where t2.accession = AD419.dbo.[' + @FinalReportTablesNamePrefix + '_' + @NonAdminWithProratedAmountsTableName + '].accession)
			'
				if @IsDebug = 1
					Print @TSQL
										
				EXEC(@TSQL)
				
				IF @IsDebug = 1 
					BEGIN
						EXEC('SELECT * FROM AD419.dbo.[' + @NonAdminTableName + ']')
						EXEC('SELECT * FROM AD419.dbo.[' + @FinalReportTablesNamePrefix + '_' + @NonAdminWithProratedAmountsTableName + ']')
						EXEC('SELECT * FROM AD419.dbo.[' + @FinalReportTablesNamePrefix + '_' + @AdminTableName + ']')
					END
										
				--- Create the finalized Non-Admin with prorated amounts "flat" table used for the "AD419 Non-Admin with Prorate Amounts report"
				SELECT @MyFlat_NonAdminWithProratedExpensesTableName = (@FinalReportTablesNamePrefix + '_' + @Flat_NonAdminWithProratedExpensesTableName)
				EXEC [dbo].[usp_CreateFlatTableForNonAdminWithProatedValuesReport]
					@NonAdminWithProratedExpensesTableName = @NonAdminWithProRatesTotalsTableName,
					@Flat_NonAdminWithProratedExpensesTableName = @MyFlat_NonAdminWithProratedExpensesTableName,
					@IsDebug = @IsDebug,
					@IsVerboseDebug = @IsVerboseDebug;
					
				-- Drop the temp tables:					
				EXEC('DROP TABLE [AD419].[dbo].[' + @AdminTableName + '_temp]');
				EXEC('DROP TABLE [AD419].[dbo].[' + @NonAdminWithProratedAmountsTableName + '_temp]'); 
				
				-- Create the AD419_UnassociatedTotals view, that is really just a view of the All_UnassociatedTotals table.
				DECLARE @MyFinalReportTablesNamePrefix varchar(255) = (SELECT @FinalReportTablesNamePrefix + '_' )
				EXEC usp_CreateAD419_UnassociatedTotalsView 
					@AllTableNamePrefix = @AllTableNamePrefix, 
					@UnassociatedTotalsTableName = @UnassociatedTotalsTableName, 
					@FinalReportTablesNamePrefix = @MyFinalReportTablesNamePrefix, 
					@IsDebug = @IsDebug
							
			END --Else all departments are fully associated so create/recreate tables.
			
	END --ELSE @ReportType != 0
	
END -- Main Program
