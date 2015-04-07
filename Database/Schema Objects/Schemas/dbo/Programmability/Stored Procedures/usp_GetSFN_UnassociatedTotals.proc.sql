-- =============================================
-- Author:		Ken Taylor
-- Create date: January 10, 2012
-- Description:	Given a copy of the non-admin table, and the orgR
-- return the SFN unassociated totals table for the orgR provided. 
-- Usage: INSERT INTO @SFN_UnassociatedTotal EXEC usp_GetSFN_UnassociatedTotals @NonAdminTable, @OrgR
-- Modifications: 
-- 2014-12-17 by kjt: Removed specific references to AD419 database so SP can be used against other AD419 
--	databases like AD419_2014, etc.
-- 2015-01-13 by kjt: Modified SQL statements returning count(*) to COUNT(Distinct Accession) because
-- interdepartmental projects were being counted multiple times, i.e., once for each participating org.
-- =============================================
CREATE PROCEDURE [dbo].[usp_GetSFN_UnassociatedTotals] 
	-- Add the parameters for the stored procedure here
	@NonAdminTable NonAdminTableType READONLY,
	@OrgR varchar(4) = '',
	@AllTableNamePrefix varchar(10) = 'All',
	@IncludeZeroExpenseRecords bit = 0, --Set to one if you want the all the SFNs returned, even those with zero expense amounts.
	@IsDebug bit = 0,
	@IsVerboseDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	DECLARE @SFN_UnassociatedTotal AS SFN_UnassociatedTotalsType 

				-- These are the expense amounts that need to be progated across the various SFNs:
				Insert into @SFN_UnassociatedTotal
				SELECT 
					SFN.SFN
					, (CASE WHEN @OrgR IS NULL OR @OrgR LIKE '' OR @OrgR LIKE @AllTableNamePrefix OR @OrgR LIKE 'ADNO' THEN
							(SELECT COUNT(DISTINCT Accession) FROM [dbo].[ProjectSFN] AS PSFN WHERE PSFN.SFN = SFN.SFN AND PSFN.Amt > 0)
						ELSE 
							(SELECT COUNT(DISTINCT Accession) FROM [dbo].[ProjectSFN] AS PSFN WHERE PSFN.SFN = SFN.SFN AND PSFN.Amt > 0 
							AND PSFN.OrgR IN (SELECT OrgR FROM [dbo].[ReportingOrg] WHERE AdminClusterOrgR = @OrgR))
						END						
					) as ProjCount
					, (
						SELECT ISNULL(SUM(Expenses),0) 
						FROM Expenses 
						WHERE 
							isAssociated = 0 AND Expenses.Exp_SFN = SFN.SFN AND Expenses.OrgR LIKE
							CASE WHEN @OrgR IS NOT NULL AND @OrgR NOT LIKE '' AND @OrgR NOT LIKE @AllTableNamePrefix THEN @OrgR
							ELSE
								'%'
							END
					) as UnassociatedTotal,
					0 as ProjectsTotal
					
				FROM SFN_Display SFN
				WHERE  SFN.LineTypeCode = 'SFN'
				ORDER BY SFN.GroupDisplayOrder, SFN.LineDisplayOrder
				
				-- These are the FTE amounts that need to be progated across the various SFNs:
				Insert into @SFN_UnassociatedTotal
				SELECT 
					SFN.SFN
					, (CASE WHEN @OrgR IS NULL OR @OrgR LIKE '' OR @OrgR LIKE @AllTableNamePrefix OR @OrgR LIKE 'ADNO' THEN
							(SELECT COUNT(DISTINCT Accession) FROM [dbo].[ProjectSFN] AS PSFN WHERE PSFN.SFN = SFN.SFN AND PSFN.Amt > 0)
						ELSE 
							(SELECT COUNT(DISTINCT Accession) FROM [dbo].[ProjectSFN] AS PSFN WHERE PSFN.SFN = SFN.SFN AND PSFN.Amt > 0 
							AND PSFN.OrgR IN (SELECT OrgR FROM [dbo].[ReportingOrg] WHERE AdminClusterOrgR = @OrgR))
						END						
					) as ProjCount
					, (
						SELECT ROUND(ISNULL(SUM(FTE),0),1) 
						FROM Expenses 
						WHERE 
							isAssociated = 0 AND Expenses.FTE_SFN = SFN.SFN AND Expenses.OrgR LIKE
							CASE WHEN @OrgR IS NOT NULL AND @OrgR NOT LIKE '' AND @OrgR NOT LIKE @AllTableNamePrefix THEN @OrgR	
							ELSE
								'%'
							END
					) as UnassociatedTotal,
					0.00 as ProjectsTotal
				FROM SFN_Display SFN
				WHERE  SFN.LineTypeCode = 'FTE'
				ORDER BY SFN.GroupDisplayOrder, SFN.LineDisplayOrder
				
				--Now we need to update projects total based on the projects' orgs:
				DECLARE @SFN varchar(4) = '', @ProjectsTotals decimal(16,2) = 0.0
				
				DECLARE @Statement nvarchar(MAX)= ''
				DECLARE @Parameter_Definition NVARCHAR(MAX) = N'@NonAdminTable NonAdminTableType READONLY, @ProjectsTotal_OUT  decimal(16,2) OUTPUT'
				DECLARE SFN_UPDATE_CURSOR CURSOR FOR SELECT SFN FROM @SFN_UnassociatedTotal WHERE UnassociatedTotal > 0 FOR READ ONLY
				
				OPEN SFN_UPDATE_CURSOR
				
				FETCH NEXT FROM SFN_UPDATE_CURSOR INTO @SFN
				WHILE @@FETCH_STATUS <> -1 
					BEGIN
					
						IF @OrgR IS NULL OR @OrgR LIKE '' OR @OrgR LIKE @AllTableNamePrefix OR @OrgR LIKE 'ADNO'
							SELECT @Statement = '
								SELECT @ProjectsTotal_OUT = (
									select ISNULL(SUM([f' + @SFN + ']),0) from @NonAdminTable) 
'
						ELSE
							SELECT @Statement = '
								SELECT @ProjectsTotal_OUT = (
									select ISNULL(SUM([f' + @SFN + ']),0) from @NonAdminTable WHERE dept IN (SELECT OrgCd3Char FROM [dbo].[ReportingOrg] WHERE AdminClusterOrgR = ''' + @OrgR + '''))
'		
						IF @IsVerboseDebug = 1 PRINT @Statement;
							
						EXEC sp_executesql @statement, @Parameter_Definition , @NonAdminTable = @NonAdminTable, @ProjectsTotal_OUT = @ProjectsTotals OUTPUT
						UPDATE @SFN_UnassociatedTotal SET ProjectsTotal = @ProjectsTotals WHERE SFN = @SFN
						
						IF @IsDebug = 1 PRINT 'SFN: ' + @SFN + '; Projects total: ' + CONVERT(varchar(20),ISNULL(@ProjectsTotals,0))
							
						FETCH NEXT FROM SFN_UPDATE_CURSOR INTO @SFN
					END
					
				CLOSE SFN_UPDATE_CURSOR
				DEALLOCATE SFN_UPDATE_CURSOR
				
				IF @IncludeZeroExpenseRecords = 1
					SELECT * FROM @SFN_UnassociatedTotal
				ELSE
					SELECT * FROM @SFN_UnassociatedTotal WHERE UnassociatedTotal > 0
				
				-- Get rid of any SFNs where the unassociated total is zero:
				--DELETE from @SFN_UnassociatedTotal where UnassociatedTotal <= 0
END
