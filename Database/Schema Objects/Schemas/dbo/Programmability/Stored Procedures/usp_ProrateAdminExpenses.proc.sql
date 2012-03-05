-- =============================================
-- Author:		Ken Taylor
-- Create date: January 4, 2012
-- Description:	Runs the logic that prorates the admin expenses across the relevent departments
-- for both unassociated monetary and FTE amounts. 
-- Usages:
-- EXEC usp_ProrateAdminExpenses @AdminUnit = '' or 'ADNO' or 'ACL1' thru 'ACL5'.
-- =============================================
CREATE PROCEDURE usp_ProrateAdminExpenses 
	-- Add the parameters for the stored procedure here
	@AdminUnit varchar(4) = '', --'' is representative of "ALL" unassociated admin expenses.
	@AdminTotalsTableName varchar(255) = 'AdminTotalsTable', --The table name for the Final Admin Report.
	@NonAdminWithProRatesTotalsTableName varchar(255) = 'NonAdminWithProRatesTotalsTable', --The table name for the Final Non Admin Report with prorates.
	@NonAdminTableName varchar(255) = 'NonAdmin', --The table name, i.e. AD419_Non-Admin, for the Final Non-Admin Report.
	@UnassociatedTotalsTableName varchar(255) = 'UnassociatedTotals', --The table name, i.e. AD419_UnassociatedTotals, for the Unassociated Totals Report.
	@NonAdminWithProratedAmountsTableName varchar(255) = 'NonAdminWithProratedAmounts', --Table name suffix for <AdminUnit>NonAdminWithProratedAmounts tables
	@AdminTableName varchar(255) = 'AdminTable',  --Table name suffix for <AdminUnit>Admin tables
	@AllTableNamePrefix varchar(10)= 'All', --The table name prefix and variable name for the table containing all the unassociated totals.
	@IsDebug bit = 0 --1 to display debug messages; 0 for silent running.
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	DECLARE @TSQL varchar(MAX) = ''
			
	DECLARE @SFN_UnassociatedTotal SFN_UnassociatedTotalsType
	
	DECLARE @MySFN varchar(4), @MyUnassociatedTotal decimal(16,2), @ProjectsTotal decimal(16,0), @ProrateAmount decimal(16,2)
	DECLARE @RemainingAmountToApply decimal(16,2) = 0
							
	DECLARE @TargetAmount  decimal(16,2) = 0
	DECLARE @StartingAmount decimal(16,2) = 0
	DECLARE @RecordsToApplyTo int = 0
	DECLARE @AmountApplied decimal(16,2) = 0
	DECLARE @RecordsAppliedTo int = 0
	DECLARE @MySum decimal(16,2) = 0
	DECLARE @accession varchar(7) = '', @amt decimal(16,2) = 0, @prorate decimal(16,2) = 0
	DECLARE @NewProrateAmount decimal(16,2) = 0
	DECLARE @MyNonAdminWithProratedAmountsSFN varchar(5) = ''
	
	-- Save the Admin Unit's unassocoated totals to a table
	IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[' + @AdminUnit + '_' + @UnassociatedTotalsTableName + ']') AND type in (N'U'))
			EXEC('DROP TABLE [dbo].[' + @AdminUnit + '_' + @UnassociatedTotalsTableName + ']')
			
	
	SELECT @TSQL = '
	DECLARE @NonAdminTable AS NonAdminTableType
	INSERT INTO @NonAdminTable SELECT * from [' + @NonAdminTableName + '] 
				
	DECLARE @SFN_UnassociatedTotal AS SFN_UnassociatedTotalsType
	SELECT TOP 0 * INTO [AD419].[dbo].[' + @AdminUnit + '_' + @UnassociatedTotalsTableName + '] FROM @SFN_UnassociatedTotal 
	INSERT INTO [AD419].[dbo].[' + @AdminUnit + '_' + @UnassociatedTotalsTableName + '] EXEC usp_GetSFN_UnassociatedTotals @NonAdminTable, ''' + @AdminUnit + ''', ''' + @AllTableNamePrefix + '''
	'

	IF @IsDebug = 1
		BEGIN
			PRINT @TSQL
		END
			
	EXEC(@TSQL)

	-- Delete and load the Admin Unit's unassociated totals to a table variable
	DELETE FROM @SFN_UnassociatedTotal	
	INSERT INTO @SFN_UnassociatedTotal EXEC('SELECT * FROM [AD419].[dbo].[' + @AdminUnit + '_' + @UnassociatedTotalsTableName + ']');

	-- Create a new copy from AdminTemp table for the particular admin unit
	IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].['+ @AdminUnit + '_' + @AdminTableName + ']') AND type in (N'U'))
		EXEC('drop table [AD419].[dbo].[' + @AdminUnit + '_' + @AdminTableName + ']')
		EXEC('SELECT * INTO [AD419].[dbo].[' + @AdminUnit + '_' + @AdminTableName+ '] FROM [dbo].[' + @AdminTableName + '_temp]')

	-- Create a new copy of NonAdminWithProratedAmounts from NonAdminWithProratedAmounts_temp for the particular admin unit
	IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].['+ @AdminUnit + '_' + @NonAdminWithProratedAmountsTableName + ']') AND type in (N'U'))
		EXEC('drop table [AD419].[dbo].[' + @AdminUnit + '_' + @NonAdminWithProratedAmountsTableName +']')
		EXEC('SELECT * INTO [AD419].[dbo].[' + @AdminUnit + '_' + @NonAdminWithProratedAmountsTableName + '] FROM [dbo].[' + @NonAdminWithProratedAmountsTableName + '_temp]')

	IF @IsDebug = 1
		BEGIN
			select @AdminUnit + ' Unassociated Totals: ' as 'Report Name:'
			select 
				SFN,
				ProjCount,
				UnassociatedTotal,
				ProjectsTotal 
			from @SFN_UnassociatedTotal 
		END
		
	BEGIN --Section: Prorate admin amounts:
		declare MyCursor Cursor for select SFN, UnassociatedTotal, ProjectsTotal 
		from @SFN_UnassociatedTotal for READ ONLY;
		
		open MyCursor
		--declare @MySFN varchar(4), @MyUnassociatedTotal decimal(16,2), @ProjectsTotal decimal(16,0), @ProrateAmount decimal(16,2)
		SELECT @MySFN = '',  @MyUnassociatedTotal = 0, @ProjectsTotal = 0, @ProrateAmount = 0
		fetch next from MyCursor into @MySFN, @MyUnassociatedTotal, @ProjectsTotal
		
		while @@FETCH_STATUS <> -1
			BEGIN --while have more unassociated SFNs to prorate:
				SELECT @TSQL = ''
				if @MySFN not in ('241','242','243','244')
					begin  --if @MySFN not in ('241','242','243','244')
						select @TSQL = 
						'update AD419.dbo.[' + @AdminUnit + '_' + @NonAdminWithProratedAmountsTableName + '] set f' + @MySFN + '_prorate    = (f' + @MySFN + ') / (' + CONVERT(varchar(50), @ProjectsTotal) + ') * ' + CONVERT(varchar(50), @MyUnassociatedTotal) 
						
						IF @AdminUnit IS NULL OR @AdminUnit LIKE '' OR @AdminUnit LIKE @AllTableNamePrefix OR @AdminUnit LIKE 'ADNO' 
							SELECT @TSQL += ';
'  
						ELSE SELECT @TSQL +=  ' WHERE dept IN (SELECT OrgCd3Char FROM [AD419].[dbo].[ReportingOrg] WHERE AdminClusterOrgR = ''' + @AdminUnit + ''');
'
						select @TSQL += 'update AD419.dbo.[' + @AdminUnit + '_' + @NonAdminWithProratedAmountsTableName + '] set f' + @MySFN + '_plus_admin = (f' + @MySFN + ') + (f' + @MySFN + '_prorate)'
						IF @AdminUnit IS NULL OR @AdminUnit LIKE '' OR @AdminUnit LIKE @AllTableNamePrefix OR @AdminUnit LIKE 'ADNO' 
							SELECT @TSQL += ';
'   
						ELSE SELECT @TSQL +=  ' WHERE dept IN (SELECT OrgCd3Char FROM [AD419].[dbo].[ReportingOrg] WHERE AdminClusterOrgR = ''' + @AdminUnit + ''');
'
						select @TSQL += 'update AD419.dbo.[' + @AdminUnit + '_' + @AdminTableName + '] set f' + @MySFN +  '= (f' + @MySFN + ') + ((f' + @MySFN + ') / (' + CONVERT(varchar(50), @ProjectsTotal) + ') * ' + CONVERT(varchar(50), @MyUnassociatedTotal) + ')'
						IF @AdminUnit IS NULL OR @AdminUnit LIKE '' OR @AdminUnit LIKE @AllTableNamePrefix OR @AdminUnit LIKE 'ADNO' 
							SELECT @TSQL += ';'   
						ELSE SELECT @TSQL +=  ' WHERE dept IN (SELECT OrgCd3Char FROM [AD419].[dbo].[ReportingOrg] WHERE AdminClusterOrgR = ''' + @AdminUnit + ''');'
							
						if @IsDebug = 1
							print @TSQL
							
						EXEC (@TSQL)
					end --if @MySFN not in ('241','242','243','244') 
				else 
					begin -- else @MySFN in ('241','242','243','244') 
						if @IsDebug = 1
							select 'Now updating SFN: ' + @MySFN
							
						select @TSQL = '
						update AD419.dbo.[' + @AdminUnit + '_' + @NonAdminWithProratedAmountsTableName + '] set f' + @MySFN + '_prorate = ROUND((f' + @MySFN + ') / (' + CONVERT(varchar(50), @ProjectsTotal) + ') * ' + CONVERT(varchar(20), @MyUnassociatedTotal) + ',1)'
						IF @AdminUnit IS NULL OR @AdminUnit LIKE '' OR @AdminUnit LIKE @AllTableNamePrefix OR @AdminUnit LIKE 'ADNO' 
							SELECT @TSQL += ';
'   
						ELSE SELECT @TSQL +=  ' WHERE dept IN (SELECT OrgCd3Char FROM [AD419].[dbo].[ReportingOrg] WHERE AdminClusterOrgR = ''' + @AdminUnit + ''');
'
						select @TSQL += 'update AD419.dbo.[' + @AdminUnit + '_' + @NonAdminWithProratedAmountsTableName + '] set f' + @MySFN + '_plus_admin = (f' + @MySFN + ') + (f' + @MySFN + '_prorate)'
						IF @AdminUnit IS NULL OR @AdminUnit LIKE '' OR @AdminUnit LIKE @AllTableNamePrefix OR @AdminUnit LIKE 'ADNO' 
							SELECT @TSQL += ';
'   
						ELSE SELECT @TSQL +=  ' WHERE dept IN (SELECT OrgCd3Char FROM [AD419].[dbo].[ReportingOrg] WHERE AdminClusterOrgR = ''' + @AdminUnit + ''');
'
						select @TSQL += 'update AD419.dbo.[' + @AdminUnit + '_' + @AdminTableName + '] set f' + @MySFN +  '= (f' + @MySFN + ') +             ROUND((f' + @MySFN + ') / (' + CONVERT(varchar(50), @ProjectsTotal) + ') * ' + CONVERT(varchar(20), @MyUnassociatedTotal) + ',1)'
						IF @AdminUnit IS NULL OR @AdminUnit LIKE '' OR @AdminUnit LIKE @AllTableNamePrefix OR @AdminUnit LIKE 'ADNO' 
							SELECT @TSQL += ';
'   
						ELSE SELECT @TSQL +=  ' WHERE dept IN (SELECT OrgCd3Char FROM [AD419].[dbo].[ReportingOrg] WHERE AdminClusterOrgR = ''' + @AdminUnit + ''');
'
						if @IsDebug = 1
							print @TSQL
						
						EXEC (@TSQL)
						
						IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[TableValuesToProrate]') AND type in (N'U'))
							Drop TABLE [AD419].[dbo].[TableValuesToProrate];
							
						create TABLE [AD419].[dbo].[TableValuesToProrate] (accession varchar(7), amt decimal(16,2), prorate decimal(16,2))
					 
						select @TSQL = '
						select accession, f' + @MySFN + ', f' + @MySFN + '_prorate as prorate from AD419.dbo.[' + @AdminUnit + '_' + @NonAdminWithProratedAmountsTableName + '] where f' + @MySFN + ' > 0'
						IF @AdminUnit IS NULL OR @AdminUnit LIKE '' OR @AdminUnit LIKE @AllTableNamePrefix OR @AdminUnit LIKE 'ADNO'
							SELECT @TSQL +=  '
' 
						ELSE 
							select @TSQL += ' AND dept IN (SELECT OrgCd3Char FROM [AD419].[dbo].[ReportingOrg] WHERE AdminClusterOrgR = ''' + @AdminUnit + ''')
'
						SELECT @TSQL +=  ' order by f' + @MySFN + ' desc;
'
						if @IsDebug = 1
							print @TSQL
							
						insert into TableValuesToProrate (accession, amt, prorate) EXEC(@TSQL)
					
					if @IsDebug = 1
						BEGIN
							select @AdminUnit + ' Admin Table SFN: ' + @MySFN + ' values to prorate:'
							select * from TableValuesToProrate
						END
					 
					SELECT @RemainingAmountToApply  = (@MyUnassociatedTotal - (select SUM(prorate) from TableValuesToProrate))
					
					SELECT @TargetAmount   = (@MyUnassociatedTotal) 	
					SELECT @StartingAmount  = (SELECT SUM(prorate) FROM TableValuesToProrate)
					SELECT @RecordsToApplyTo  = abs(round(@RemainingAmountToApply/0.1,1))
					SELECT @AmountApplied  = 0
					SELECT @RecordsAppliedTo  = 0
					SELECT @MySum  = 0
					IF @RemainingAmountToApply = 0
						select @MySum =  @MyUnassociatedTotal
						
					if @IsDebug = 1 
					BEGIN
						select 'Target Amount: ' + Convert(varchar(50), @TargetAmount) 	+ '; Starting Amount: ' +  CONVERT(varchar(30),@StartingAmount ) +'; Remaining amount to apply: ' + CONVERT(varchar(30),@RemainingAmountToApply )
					END
							
					declare MyCursor2 Cursor for select accession, amt, prorate
					from TableValuesToProrate for READ ONLY
					 
					open MyCursor2
					 
					SELECT @accession = '', @amt = 0, @prorate = 0
					
					fetch next from MyCursor2 into @accession, @amt, @prorate
					while @@FETCH_STATUS <> -1 AND @RecordsAppliedTo < @RecordsToApplyTo
						begin --while have outstanding unassociated amount to prorate for the given SFN
							SELECT @NewProrateAmount  = 0
				
							if @RemainingAmountToApply < 0
								BEGIN
									select @NewProrateAmount = @prorate - 0.1
									select @AmountApplied = @AmountApplied - 0.1
								END
							else
								BEGIN
									select @NewProrateAmount = @prorate + 0.1
									select @AmountApplied = @AmountApplied + 0.1
								END
				
							Select @TSQL = '	
							update AD419.dbo.[' + @AdminUnit + '_' + @NonAdminWithProratedAmountsTableName + '] set f' + @MySFN + '_prorate = ' + Convert(varchar(50), @NewProrateAmount)
							+ ', f' + @MySFN + '_plus_admin = ' + Convert(varchar(50), @NewProrateAmount + @amt) + ' where accession = ' + Convert(varchar(7), @accession) + ';
						
							update AD419.dbo.[' + @AdminUnit + '_' + @AdminTableName + '] set f' + @MySFN + ' = ' + Convert(varchar(50), @NewProrateAmount + @amt) + ' where accession = ' + Convert(varchar(7), @accession) + ';
'
							if @IsDebug = 1
								Print @TSQL
								
							EXEC(@TSQL)
							
							--Select @AmountApplied = @AmountApplied + @NewProrateAmount
							Select @RecordsAppliedTo = @RecordsAppliedTo + 1
							
							if @IsDebug = 1
						Select @MySum  = ((select SUM(prorate) from TableValuesToProrate) + @AmountApplied)
						--select 'Amount: ' + Convert(varchar(50), @MyUnassociatedTotal) + '; Applied: ' + CONVERT(varchar(50), @MySum)
							
							fetch next from MyCursor2 into @accession, @amt, @prorate
						end --while have outstanding unassociated amount to prorate for the given SFN
					drop TABLE [AD419].[dbo].[TableValuesToProrate]
					
					if @IsDebug = 1
						select 'Final Amount: ' + CONVERT(varchar(50), @MySum) + '; Amount Applied: ' + CONVERT(varchar(50), @AmountApplied)
					
					close MyCursor2
					deallocate MyCursor2	 
				end -- else @MySFN in ('241','242','243','244') 
				
			fetch next from MyCursor into @MySFN, @MyUnassociatedTotal, @ProjectsTotal
				
			END --while have more unassociated SFNs to prorate.
			
		close MyCursor
		deallocate MyCursor
		
		-- Update the totals in the Category and Sub-Category Totals and Sub-totals
		-- in the AD419_Admin and AD419_Non-Admin tables:
		
		SELECT @TSQL = '
		Update AD419.dbo.[' + @AdminUnit + '_' + @AdminTableName + '] set f231 = (f201 + f202 + f203 + f204 + f205)
		Update AD419.dbo.[' + @AdminUnit + '_' + @AdminTableName + '] set f332 = (f219 + f209 + f310 + f308 + f311 + f316 + f312 + f313 + f314 + f315 + f318)
		Update AD419.dbo.[' + @AdminUnit + '_' + @AdminTableName + '] set f233 = (f220 + f22F + f221 + f222 + f223)
		Update AD419.dbo.[' + @AdminUnit + '_' + @AdminTableName + '] set f234 = (f231 + f332 + f233)
		Update AD419.dbo.[' + @AdminUnit + '_' + @AdminTableName + '] set f350 = (f241 + f242 + f243 + f244)
'
		if @IsDebug = 1
			Print @TSQL
								
		EXEC(@TSQL)
		 
		SELECT @TSQL = '
		Update AD419.dbo.[' + @AdminUnit + '_' + @NonAdminWithProratedAmountsTableName + '] set f231 = (f201 + f202 + f203 + f204 + f205)
		Update AD419.dbo.[' + @AdminUnit + '_' + @NonAdminWithProratedAmountsTableName + '] set f332 = (select f332 from AD419.dbo.[' + @AdminUnit + '_' + @AdminTableName + '] t2 where t2.accession = AD419.dbo.[' + @AdminUnit + '_' + @NonAdminWithProratedAmountsTableName + '].accession) 
		Update AD419.dbo.[' + @AdminUnit + '_' + @NonAdminWithProratedAmountsTableName + '] set f233 = (select f233 from AD419.dbo.[' + @AdminUnit + '_' + @AdminTableName + '] t2 where t2.accession = AD419.dbo.[' + @AdminUnit + '_' + @NonAdminWithProratedAmountsTableName + '].accession)
		Update AD419.dbo.[' + @AdminUnit + '_' + @NonAdminWithProratedAmountsTableName + '] set f234 = (select f234 from AD419.dbo.[' + @AdminUnit + '_' + @AdminTableName + '] t2 where t2.accession = AD419.dbo.[' + @AdminUnit + '_' + @NonAdminWithProratedAmountsTableName + '].accession)
		Update AD419.dbo.[' + @AdminUnit + '_' + @NonAdminWithProratedAmountsTableName + '] set f350 = (select f350 from AD419.dbo.[' + @AdminUnit + '_' + @AdminTableName + '] t2 where t2.accession = AD419.dbo.[' + @AdminUnit + '_' + @NonAdminWithProratedAmountsTableName + '].accession)
'
		if @IsDebug = 1
			Print @TSQL
								
		EXEC(@TSQL)
		
		IF @IsDebug = 1 
			BEGIN
				SELECT @TSQL = 'SELECT * FROM AD419.dbo.[' + @AdminUnit + '_' + @AdminTableName + ']
				SELECT * FROM AD419.dbo.[' + @AdminUnit + '_' + @NonAdminWithProratedAmountsTableName + ']
'
				EXEC(@TSQL)
			END
		-- Skip updating totals if @AdminUnit = '', i.e. All
		IF @AdminUnit IS NOT NULL AND @AdminUnit NOT LIKE '' AND @AdminUnit NOT LIKE @AllTableNamePrefix 
			BEGIN 	
				-- Sum old and new for running total
				
				SELECT @TSQL = ''		
				declare MySFNCursor Cursor for select SFN from @SFN_UnassociatedTotal for READ ONLY;
				
				open MySFNCursor
				SELECT @MyNonAdminWithProratedAmountsSFN = ''
				
				fetch next from MySFNCursor into @MyNonAdminWithProratedAmountsSFN
				
				while @@FETCH_STATUS <> -1
					BEGIN --while have more SFN amounts to total:
						SELECT @TSQL += '
						Update AD419.dbo.[' + @NonAdminWithProRatesTotalsTableName + '] set f' + @MyNonAdminWithProratedAmountsSFN + '_prorate = f' + @MyNonAdminWithProratedAmountsSFN + '_prorate + (SELECT f' + @MyNonAdminWithProratedAmountsSFN + '_prorate FROM AD419.dbo.[' + @AdminUnit + '_' + @NonAdminWithProratedAmountsTableName + '] t2 WHERE t2.Accession = AD419.dbo.[' + @NonAdminWithProRatesTotalsTableName + '].Accession)
						Update AD419.dbo.[' + @NonAdminWithProRatesTotalsTableName + '] set f' + @MyNonAdminWithProratedAmountsSFN + '_plus_admin = (f' + @MyNonAdminWithProratedAmountsSFN + ' + f' + @MyNonAdminWithProratedAmountsSFN + '_prorate)
						Update AD419.dbo.[' + @AdminTotalsTableName + '] set f' + @MyNonAdminWithProratedAmountsSFN + ' = (f' + @MyNonAdminWithProratedAmountsSFN + ') + (SELECT f' + @MyNonAdminWithProratedAmountsSFN + '_prorate FROM AD419.dbo.[' + @AdminUnit + '_' + @NonAdminWithProratedAmountsTableName + '] t2 WHERE t2.Accession = AD419.dbo.[' + @AdminTotalsTableName + '].Accession)
'
						fetch next from MySFNCursor into @MyNonAdminWithProratedAmountsSFN
					END --while have more SFN amounts to total.
					
				close MySFNCursor
				deallocate MySFNCursor
				
				if @IsDebug = 1
					Print @TSQL
										
				EXEC(@TSQL)
				
			END --IF @AdminUnit IS NOT NULL AND @AdminUnit NOT LIKE ''
	END --Section: Prorate admin amounts.
END
