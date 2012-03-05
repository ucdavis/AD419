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
*/
-------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[usp_Create AD419_FinalReportTables_20120115_bak]
	@ReportType int = 0, -- 0: Display the reports from already created tables (default); 1: Create/Recreate the report tables.
	@IsDebug bit = 0 -- Set to 1 to display debug text.
AS

/*
0: Display the reports from already created tables (default)
1: Create/Recreate the report tables.

declare @ReportType int = 0
declare @IsDebug bit = 0
*/

BEGIN -- Main program

-- Check the @ReportType variable: 0 for print AD419 reports; 1 for create AD419 Report tables:
IF @ReportType = 0
	BEGIN 
	-- Output the reports:
		IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[AD419_Non-Admin]') AND type in (N'U'))
			OR NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[AD419_UnassociatedTotals]') AND type in (N'U'))
			OR NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[AD419_Non-Admin_WithProratedAmounts]') AND type in (N'U'))
			OR NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[AD419_Admin]') AND type in (N'U'))
			BEGIN
				Select 'Run 
				EXEC [dbo].[usp_Create AD419_FinalReportTables] @ReportType = 1
				first before running option 0.';
				Return -1;
			END
		ELSE
			BEGIN --Else tables exist
				select 'Unassociated Totals Report: ' as 'Report Name:'
				select * from [AD419].[dbo].[AD419_UnassociatedTotals] 
				
				-- Output the AD419_Non-Admin Report:
				Select 'AD419_Non-Admin Report (from AD419_Non-Admin table): ' as 'Report Name:' 
				select * from [AD419].[dbo].[AD419_Non-Admin] 
					
				-- Output the AD419_Non-Admin_WithProratedAmounts table:
				select 'AD419_Non-Admin Report with Prorated Amounts (from AD419_Non-Admin_WithProratedAmounts table: ' as 'Report Name:'
				select * from [AD419].[dbo].[AD419_Non-Admin_WithProratedAmounts];
					
				-- Output the AD419_Admin Report:
				select 'AD419_Admin Report (from AD419_Admin table (already has prorated amounts added to appropriate SFNs)): ' as 'Report Name:'
				select * from [AD419].[dbo].[AD419_Admin];
			END --Else tables exist
	END --IF @ReportType = 0
ELSE
	BEGIN -- ELSE @ReportType != 0
		-- First we need to check to see that all non-excluded expenses have
		-- been associated
		/*
		DECLARE @OrgRExclusions TABLE varchar(16)
		SET @OrgRExclusions = 'ADNO'
		*/
		
		DECLARE @OrgRExclusions  TABLE (OrgR char(4))
		INSERT INTO @OrgRExclusions VALUES ('ADNO'), ('ACL1'), ('ACL2'), ('ACL3'), ('ACL4'), ('ACL5')

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
				--RETURN -1
			END -- Check that all departments are fully associated.
		ELSE
			BEGIN -- Else all departments are fully associated so create/recreate tables.
				DECLARE @ProjSFN TABLE
					(
						Project varchar(24),
						Accession char(7),
						OrgR char(4),
						inv1 varchar(30),
						SFN char(3),
						Amt decimal(16,3),
						isExpense bit
					)

				-- Populate a temporary table with all non-zero expense data
				INSERT INTO @ProjSFN
				SELECT     Project.Project, Project.Accession, Associations.OrgR, Project.inv1, Expenses.Exp_SFN, ISNULL(ROUND(SUM(Associations.Expenses),0),0) AS Amt, 1
				FROM         Expenses INNER JOIN
									  ReportingOrg ON Expenses.OrgR = ReportingOrg.OrgR INNER JOIN
									  Associations ON Expenses.ExpenseID = Associations.ExpenseID INNER JOIN
									  Project ON Associations.Accession = Project.Accession
				GROUP BY Project.Project, Project.Accession, Associations.OrgR, Project.inv1, Expenses.Exp_SFN
				HAVING      (SUM(Associations.Expenses) > 0)

				-- Populate this time with FTE data
				INSERT INTO @ProjSFN
				SELECT     Project.Project, Project.Accession, Associations.OrgR, Project.inv1, Expenses.FTE_SFN, ISNULL(ROUND(SUM(Associations.FTE), 1),0) AS Amt, 0
				FROM         Expenses INNER JOIN
									  ReportingOrg ON Expenses.OrgR = ReportingOrg.OrgR INNER JOIN
									  Associations ON Expenses.ExpenseID = Associations.ExpenseID INNER JOIN
									  Project ON Associations.Accession = Project.Accession
				GROUP BY Project.Project, Project.Accession, Associations.OrgR, Project.inv1, Expenses.FTE_SFN
				HAVING      (SUM(Associations.FTE) > 0)

				-- Start populating the DAVIS_PROJECTS table with a record for each project
				DECLARE @ProjectsList TABLE
				(
					loc char(2),
					dept char(3),
					proj char(4),
					project varchar(24),
					accession char(7),
					PI varchar(30),
					proj_id int
				)

				INSERT INTO @ProjectsList
					SELECT     
						(CASE 
							WHEN SUBSTRING(Project.Project, 4, 2) NOT LIKE '%-' THEN  SUBSTRING(Project.Project, 4, 2)
							ELSE SUBSTRING(Project.Project, 4, 1)
						END) AS loc, 
						ReportingOrg.OrgCd3Char AS dept, 
						(CASE 
							WHEN SUBSTRING(Project.Project, 11, 4) NOT LIKE '%-' THEN  SUBSTRING(Project.Project, 11, 4)
							ELSE SUBSTRING(Project.Project, 10, 4)
						END) as proj,
						Project.Project, 
						Project.Accession, 
						Project.inv1 AS PI, 
						Project.idProject AS proj_id
					FROM         Project INNER JOIN
										  ReportingOrg ON Project.CRIS_DeptID = ReportingOrg.CRISDeptCd
					WHERE     (ReportingOrg.OrgCd3Char <> '8455')
					ORDER BY dept, proj

				-- Make sure XXX projects are in the XXX department
				UPDATE @ProjectsList
				SET dept = 'XXX'
				WHERE project like '%XXX%'

				-- Base table for the report list
				DECLARE @ReportList TABLE
				(
				--rownum int IDENTITY(1,1) Primary key not null,
					loc char(2),
					dept char(3),
					proj char(4),
					project varchar(24),
					accession char(7),
					PI varchar(30),
					f201 decimal(16,2),
					f202 decimal(16,2),
					f203 decimal(16,2),
					f204 decimal(16,2),
					f205 decimal(16,2),
					f231 decimal(16,2),
					f219 decimal(16,2),
					f209 decimal(16,2),
					f310 decimal(16,2),
					f308 decimal(16,2),
					f311 decimal(16,2),
					f316 decimal(16,2),
					f312 decimal(16,2),
					f313 decimal(16,2),
					f314 decimal(16,2),
					f315 decimal(16,2),
					f318 decimal(16,2),
					f332 decimal(16,2),
					f220 decimal(16,2),
					f22F decimal(16,2),
					f221 decimal(16,2),
					f222 decimal(16,2),
					f223 decimal(16,2),
					f233 decimal(16,2),
					f234 decimal(16,2),
					f241 decimal(16,2),
					f242 decimal(16,2),
					f243 decimal(16,2),
					f244 decimal(16,2),
					f350 decimal(16,2)
				)

				-- Insert in the base project amount expenses

				INSERT INTO @ReportList
				--NonAdmin report
				SELECT 
						loc
						, dept
						, proj
						, project
						, accession
						, PI
						, (
							SELECT ISNULL(SUM(Amt), 0) as Amt
							FROM @ProjSFN AS PSFN
							WHERE PList.Accession = PSFN.Accession AND SFN = '201' 
						) AS f201
						, (
							SELECT ISNULL(SUM(Amt), 0) 
							FROM @ProjSFN AS PSFN
							WHERE PList.Accession = PSFN.Accession AND SFN = '202' 
						) AS f202
						, (
							SELECT ISNULL(SUM(Amt), 0) 
							FROM @ProjSFN AS PSFN
							WHERE PList.Accession = PSFN.Accession AND SFN = '203' 
						) AS f203
						, (
							SELECT ISNULL(SUM(Amt), 0) 
							FROM @ProjSFN AS PSFN
							WHERE PList.Accession = PSFN.Accession AND SFN = '204' 
						) AS f204
						, (
							SELECT ISNULL(SUM(Amt), 0) 
							FROM @ProjSFN AS PSFN
							WHERE PList.Accession = PSFN.Accession AND SFN = '205' 
						) AS f205
						, /*(	
							SELECT ISNULL(SUM(Amt), 0) as Amt
							FROM @ProjSFN AS PSFN
							WHERE 
							(PList.Accession = PSFN.Accession AND SFN = '201') OR  
							(PList.Accession = PSFN.Accession AND SFN = '202') OR
							(PList.Accession = PSFN.Accession AND SFN = '203') OR
							(PList.Accession = PSFN.Accession AND SFN = '204') OR
							(PList.Accession = PSFN.Accession AND SFN = '205')
						)*/ 0 AS f231
						, (
							SELECT ISNULL(SUM(Amt), 0) 
							FROM @ProjSFN AS PSFN
							WHERE PList.Accession = PSFN.Accession AND SFN = '219' 
						) AS f219
						, (
							SELECT ISNULL(SUM(Amt), 0) 
							FROM @ProjSFN AS PSFN
							WHERE PList.Accession = PSFN.Accession AND SFN = '209' 
						) AS f209
						, (
							SELECT ISNULL(SUM(Amt), 0) 
							FROM @ProjSFN AS PSFN
							WHERE PList.Accession = PSFN.Accession AND SFN = '310' 
						) AS f310
						, (
							SELECT ISNULL(SUM(Amt), 0) 
							FROM @ProjSFN AS PSFN
							WHERE PList.Accession = PSFN.Accession AND SFN = '308' 
						) AS f308
						, (
							SELECT ISNULL(SUM(Amt), 0) 
							FROM @ProjSFN AS PSFN
							WHERE PList.Accession = PSFN.Accession AND SFN = '311' 
						) AS f311
						, (
							SELECT ISNULL(SUM(Amt), 0) 
							FROM @ProjSFN AS PSFN
							WHERE PList.Accession = PSFN.Accession AND SFN = '316' 
						) AS f316
						, (
							SELECT ISNULL(SUM(Amt), 0) 
							FROM @ProjSFN AS PSFN
							WHERE PList.Accession = PSFN.Accession AND SFN = '312' 
						) AS f312
						, (
							SELECT ISNULL(SUM(Amt), 0) 
							FROM @ProjSFN AS PSFN
							WHERE PList.Accession = PSFN.Accession AND SFN = '313' 
						) AS f313
						, (
							SELECT ISNULL(SUM(Amt), 0) 
							FROM @ProjSFN AS PSFN
							WHERE PList.Accession = PSFN.Accession AND SFN = '314' 
						) AS f314
						, (
							SELECT ISNULL(SUM(Amt), 0) 
							FROM @ProjSFN AS PSFN
							WHERE PList.Accession = PSFN.Accession AND SFN = '315' 
						) AS f315
						, (
							SELECT ISNULL(SUM(Amt), 0) 
							FROM @ProjSFN AS PSFN
							WHERE PList.Accession = PSFN.Accession AND SFN = '318' 
						) AS f318
						,/* (
							SELECT ISNULL(SUM(Amt), 0) 
							FROM @ProjSFN AS PSFN
							WHERE 
							(PList.Accession = PSFN.Accession AND SFN = '219') OR
							(PList.Accession = PSFN.Accession AND SFN = '209') OR
							(PList.Accession = PSFN.Accession AND SFN = '310') OR
							(PList.Accession = PSFN.Accession AND SFN = '308') OR
							(PList.Accession = PSFN.Accession AND SFN = '311') OR
							(PList.Accession = PSFN.Accession AND SFN = '316') OR
							(PList.Accession = PSFN.Accession AND SFN = '312') OR
							(PList.Accession = PSFN.Accession AND SFN = '313') OR
							(PList.Accession = PSFN.Accession AND SFN = '314') OR
							(PList.Accession = PSFN.Accession AND SFN = '315') OR
							(PList.Accession = PSFN.Accession AND SFN = '318')
						) */ 0 AS f332
						, (
							SELECT ISNULL(SUM(Amt), 0) 
							FROM @ProjSFN AS PSFN
							WHERE PList.Accession = PSFN.Accession AND SFN = '220' 
						) AS f220
						, (
							SELECT ISNULL(SUM(Amt), 0) 
							FROM @ProjSFN AS PSFN
							WHERE PList.Accession = PSFN.Accession AND SFN = '22F' 
						) AS f22F
						, (
							SELECT ISNULL(SUM(Amt), 0) 
							FROM @ProjSFN AS PSFN
							WHERE PList.Accession = PSFN.Accession AND SFN = '221' 
						) AS f221
						, (
							SELECT ISNULL(SUM(Amt), 0) 
							FROM @ProjSFN AS PSFN
							WHERE PList.Accession = PSFN.Accession AND SFN = '222' 
						) AS f222
						, (
							SELECT ISNULL(SUM(Amt), 0) 
							FROM @ProjSFN AS PSFN
							WHERE PList.Accession = PSFN.Accession AND SFN = '223' 
						) AS f223
						, /* (
							SELECT ISNULL(SUM(Amt), 0) 
							FROM @ProjSFN AS PSFN
							WHERE 
							(PList.Accession = PSFN.Accession AND SFN = '220') OR
							(PList.Accession = PSFN.Accession AND SFN = '22F') OR
							(PList.Accession = PSFN.Accession AND SFN = '221') OR
							(PList.Accession = PSFN.Accession AND SFN = '222') OR
							(PList.Accession = PSFN.Accession AND SFN = '223')
						)*/0 AS f233
						, /* (
							SELECT ISNULL(SUM(Amt), 0) 
							FROM @ProjSFN AS PSFN
							WHERE 
							(PList.Accession = PSFN.Accession AND SFN = '201') OR  
							(PList.Accession = PSFN.Accession AND SFN = '202') OR
							(PList.Accession = PSFN.Accession AND SFN = '203') OR
							(PList.Accession = PSFN.Accession AND SFN = '204') OR
							(PList.Accession = PSFN.Accession AND SFN = '205') OR
							(PList.Accession = PSFN.Accession AND SFN = '219') OR
							(PList.Accession = PSFN.Accession AND SFN = '209') OR
							(PList.Accession = PSFN.Accession AND SFN = '310') OR
							(PList.Accession = PSFN.Accession AND SFN = '308') OR
							(PList.Accession = PSFN.Accession AND SFN = '311') OR
							(PList.Accession = PSFN.Accession AND SFN = '316') OR
							(PList.Accession = PSFN.Accession AND SFN = '312') OR
							(PList.Accession = PSFN.Accession AND SFN = '313') OR
							(PList.Accession = PSFN.Accession AND SFN = '314') OR
							(PList.Accession = PSFN.Accession AND SFN = '315') OR
							(PList.Accession = PSFN.Accession AND SFN = '318') OR
							(PList.Accession = PSFN.Accession AND SFN = '220') OR
							(PList.Accession = PSFN.Accession AND SFN = '22F') OR
							(PList.Accession = PSFN.Accession AND SFN = '221') OR
							(PList.Accession = PSFN.Accession AND SFN = '222') OR
							(PList.Accession = PSFN.Accession AND SFN = '223')
						)*/ 0 AS f234
						, (
							SELECT ISNULL(SUM(Amt), 0) 
							FROM @ProjSFN AS PSFN
							WHERE PList.Accession = PSFN.Accession AND SFN = '241' 
						) AS f241
						, (
							SELECT ISNULL(SUM(Amt), 0) 
							FROM @ProjSFN AS PSFN
							WHERE PList.Accession = PSFN.Accession AND SFN = '242' 
						) AS f242
						, (
							SELECT ISNULL(SUM(Amt), 0) 
							FROM @ProjSFN AS PSFN
							WHERE PList.Accession = PSFN.Accession AND SFN = '243' 
						) AS f243
						, (
							SELECT ISNULL(SUM(Amt), 0) 
							FROM @ProjSFN AS PSFN
							WHERE PList.Accession = PSFN.Accession AND SFN = '244' 
						) AS f244
						, /*(
							SELECT ISNULL(SUM(Amt), 0) 
							FROM @ProjSFN AS PSFN
							WHERE 
							(PList.Accession = PSFN.Accession AND SFN = '241') OR
							(PList.Accession = PSFN.Accession AND SFN = '242') OR
							(PList.Accession = PSFN.Accession AND SFN = '243') OR
							(PList.Accession = PSFN.Accession AND SFN = '244')
						) */ 0 AS f350
				FROM @ProjectsList AS PList
				ORDER BY dept, proj
					
				IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[AD419_Non-Admin]') AND type in (N'U'))
					drop table [AD419].[dbo].[AD419_Non-Admin]
					
				select * into [AD419].[dbo].[AD419_Non-Admin] from @ReportList  
					
				-- Update the category sub-totals and report totals fields:
				Update [AD419].[dbo].[AD419_Non-Admin] set f231 = (f201 + f202 + f203 + f204 + f205)
				Update [AD419].[dbo].[AD419_Non-Admin] set f332 = (f219 + f209 + f310 + f308 + f311 + f316 + f312 + f313 + f314 + f315 + f318)
				Update [AD419].[dbo].[AD419_Non-Admin] set f233 = (f220 + f22F + f221 + f222 + f223)
				Update [AD419].[dbo].[AD419_Non-Admin] set f234 = (f231 + f332 + f233)
				Update [AD419].[dbo].[AD419_Non-Admin] set f350 = (f241 + f242 + f243 + f244)
	
	
				-- Create and populate table containing Admin report.
				-- The Admin report has the CAES, i.e. ADNO, amounts divided up amungst the 
				-- various projects and added to the affected fields, meaning f209 + f209 prorated amount = new f209 amount.
				-- This is done for each individual project.
				IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[AD419_Admin]') AND type in (N'U'))
					drop table [AD419].[dbo].[AD419_Admin]
					
				Select * into [AD419].[dbo].[AD419_Admin] from @ReportList 
				--Need to prorate unassocaited amounts through the correct SFNs in the @ReportList table
				
				--Unassociated amount not in 201-205 or summation SFNS
				--So prorate from SFN table where line type code is SFN or FTE
				DECLARE @SFN_UnassociatedTotal TABLE
				(
					SFN varchar(4),
					ProjCount int,
					UnassociatedTotal decimal(16,2),
					ProjectsTotal decimal(16,2)
				)
				
				-- These are the expense amounts that need to be progated across the various SFNs:
				Insert into @SFN_UnassociatedTotal
				SELECT 
					SFN.SFN
					, (
						SELECT COUNT(*) FROM @ProjSFN AS PSFN WHERE PSFN.SFN = SFN.SFN AND PSFN.Amt > 0
					) as ProjCount
					, (
						SELECT ISNULL(SUM(Expenses),0) FROM Expenses WHERE isAssociated = 0 AND Expenses.Exp_SFN = SFN.SFN
					) as UnassociatedTotal,
					0 as ProjectsTotal
					
				FROM SFN_Display SFN
				WHERE  SFN.LineTypeCode = 'SFN'
				ORDER BY SFN.GroupDisplayOrder, SFN.LineDisplayOrder
				
				-- These are the FTE amounts that need to be progated across the various SFNs:
				Insert into @SFN_UnassociatedTotal
				SELECT 
					SFN.SFN
					, (
						SELECT COUNT(*) FROM @ProjSFN AS PSFN WHERE PSFN.SFN = SFN.SFN AND PSFN.Amt > 0
					) as ProjCount
					, (
						SELECT ROUND(ISNULL(SUM(FTE),0),1) FROM Expenses WHERE isAssociated = 0 AND Expenses.FTE_SFN = SFN.SFN
					) as UnassociatedTotal,
					0.00 as ProjectsTotal
				FROM SFN_Display SFN
				WHERE  SFN.LineTypeCode = 'FTE'
				ORDER BY SFN.GroupDisplayOrder, SFN.LineDisplayOrder
				
				update @SFN_UnassociatedTotal set ProjectsTotal = (select ISNULL(SUM(f219),0) from [AD419].[dbo].[AD419_Non-Admin]) 
				where SFN = '219'
				update @SFN_UnassociatedTotal set ProjectsTotal = (select ISNULL(SUM(f209),0) from [AD419].[dbo].[AD419_Non-Admin]) 
				where SFN = '209' 
				update @SFN_UnassociatedTotal set ProjectsTotal = (select ISNULL(SUM(f310),0) from [AD419].[dbo].[AD419_Non-Admin]) 
				where SFN = '310'
				update @SFN_UnassociatedTotal set ProjectsTotal = (select ISNULL(SUM(f308),0) from [AD419].[dbo].[AD419_Non-Admin]) 
				where SFN = '308'
				update @SFN_UnassociatedTotal set ProjectsTotal = (select ISNULL(SUM(f311),0) from [AD419].[dbo].[AD419_Non-Admin]) 
				where SFN = '311' 
				update @SFN_UnassociatedTotal set ProjectsTotal = (select ISNULL(SUM(f316),0) from [AD419].[dbo].[AD419_Non-Admin]) 
				where SFN = '316'
				update @SFN_UnassociatedTotal set ProjectsTotal = (select ISNULL(SUM(f312),0) from [AD419].[dbo].[AD419_Non-Admin]) 
				where SFN = '312' 
				update @SFN_UnassociatedTotal set ProjectsTotal = (select ISNULL(SUM(f313),0) from [AD419].[dbo].[AD419_Non-Admin]) 
				where SFN = '313'
				update @SFN_UnassociatedTotal set ProjectsTotal = (select ISNULL(SUM(f314),0) from [AD419].[dbo].[AD419_Non-Admin]) 
				where SFN = '314'
				update @SFN_UnassociatedTotal set ProjectsTotal = (select ISNULL(SUM(f315),0) from [AD419].[dbo].[AD419_Non-Admin]) 
				where SFN = '315'
				update @SFN_UnassociatedTotal set ProjectsTotal = (select ISNULL(SUM(f318),0) from [AD419].[dbo].[AD419_Non-Admin]) 
				where SFN = '318' 
				update @SFN_UnassociatedTotal set ProjectsTotal = (select ISNULL(SUM(f220),0) from [AD419].[dbo].[AD419_Non-Admin]) 
				where SFN = '220'
				update @SFN_UnassociatedTotal set ProjectsTotal = (select ISNULL(SUM(f22F),0) from [AD419].[dbo].[AD419_Non-Admin]) 
				where SFN = '22F' 
				update @SFN_UnassociatedTotal set ProjectsTotal = (select ISNULL(SUM(f221),0) from [AD419].[dbo].[AD419_Non-Admin]) 
				where SFN = '221'
				update @SFN_UnassociatedTotal set ProjectsTotal = (select ISNULL(SUM(f222),0) from [AD419].[dbo].[AD419_Non-Admin]) 
				where SFN = '222'
				update @SFN_UnassociatedTotal set ProjectsTotal = (select ISNULL(SUM(f223),0) from [AD419].[dbo].[AD419_Non-Admin]) 
				where SFN = '223' 
				update @SFN_UnassociatedTotal set ProjectsTotal = (select ISNULL(SUM(f241),0) from [AD419].[dbo].[AD419_Non-Admin]) 
				where SFN = '241'
				update @SFN_UnassociatedTotal set ProjectsTotal = (select ISNULL(SUM(f242),0) from [AD419].[dbo].[AD419_Non-Admin]) 
				where SFN = '242' 
				update @SFN_UnassociatedTotal set ProjectsTotal = (select ISNULL(SUM(f243),0) from [AD419].[dbo].[AD419_Non-Admin]) 
				where SFN = '243'
				update @SFN_UnassociatedTotal set ProjectsTotal = (select ISNULL(SUM(f244),0) from [AD419].[dbo].[AD419_Non-Admin]) 
				where SFN = '244'
				
				--select 'Unassociated Totals: ' as 'Report Name:'
				--select * from @SFN_UnassociatedTotal where UnassociatedTotal > 0
				IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[AD419_UnassociatedTotals]') AND type in (N'U'))
					DROP TABLE [dbo].[AD419_UnassociatedTotals]
				
				select 
					SFN,
					ProjCount,
					UnassociatedTotal,
					ProjectsTotal 
				into [AD419].[dbo].[AD419_UnassociatedTotals]
				from @SFN_UnassociatedTotal where UnassociatedTotal > 0;
			
				-- Create a AD419_Non-Admin table with a prorated amount column for
				-- each SFN that has a value > 0 in the Unassociated Totals table:
				
				--Select * from @SFN_UnassociatedTotal where UnassociatedTotal > 0
				Declare @SFNAmount decimal(16,2) = 0.0
				
				IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[AD419_Non-Admin_WithProratedAmounts]') AND type in (N'U'))
					Drop TABLE [AD419].[dbo].[AD419_Non-Admin_WithProratedAmounts];
				
				Declare @CreateTableSQL varchar(MAX) = 'CREATE TABLE [AD419].[dbo].[AD419_Non-Admin_WithProratedAmounts] (
				--rownum int IDENTITY(1,1) Primary key not null,
				loc char(2),
				dept char(3),
				proj char(4),
				project varchar(24),
				accession char(7),
				PI varchar(30),
				f201 decimal(16,2),
				f202 decimal(16,2),
				f203 decimal(16,2),
				f204 decimal(16,2),
				f205 decimal(16,2),
				f231 decimal(16,2),
				f219 decimal(16,2),
				'
				
				Select @SFNAmount = (Select UnassociatedTotal from @SFN_UnassociatedTotal where SFN = '219')
				if @SFNAmount > 0
					select @CreateTableSQL += 'f219_prorate decimal(16,2), [f219_plus_admin] decimal(16,2),
				'
				
				select @CreateTableSQL += 'f209 decimal(16,2),
				'
				Select @SFNAmount = (Select UnassociatedTotal from @SFN_UnassociatedTotal where SFN = '209')
				if @SFNAmount > 0 
					select @CreateTableSQL += 'f209_prorate decimal(16,2), [f209_plus_admin] decimal(16,2),
				'
				
				select @CreateTableSQL += 'f310 decimal(16,2),
				'
				Select @SFNAmount = (Select UnassociatedTotal from @SFN_UnassociatedTotal where SFN = '310')
				if @SFNAmount > 0 
					select @CreateTableSQL += 'f310_prorate decimal(16,2), [f310_plus_admin] decimal(16,2),
				'
					
				select @CreateTableSQL += 'f308 decimal(16,2),
				'
				Select @SFNAmount = (Select UnassociatedTotal from @SFN_UnassociatedTotal where SFN = '308')
				if @SFNAmount > 0
					select @CreateTableSQL += 'f308_prorate decimal(16,2) ,[f308_plus_admin] decimal(16,2),
				'
				
				select @CreateTableSQL += 'f311 decimal(16,2),
				'
				Select @SFNAmount = (Select UnassociatedTotal from @SFN_UnassociatedTotal where SFN = '311')
				if @SFNAmount > 0 
					select @CreateTableSQL += 'f311_prorate decimal(16,2), [f311_plus_admin] decimal(16,2),
				'
				
				select @CreateTableSQL += 'f316 decimal(16,2),
				'
				Select @SFNAmount = (Select UnassociatedTotal from @SFN_UnassociatedTotal where SFN = '316')
				if @SFNAmount > 0 
					select @CreateTableSQL += 'f316_prorate decimal(16,2), [f316_plus_admin] decimal(16,2),
				'
				
				select @CreateTableSQL += 'f312 decimal(16,2),
				'
				Select @SFNAmount = (Select UnassociatedTotal from @SFN_UnassociatedTotal where SFN = '312')
				if @SFNAmount > 0 
					select @CreateTableSQL += 'f312_prorate decimal(16,2), [f312_plus_admin] decimal(16,2),
				'
					
				select @CreateTableSQL += 'f313 decimal(16,2),
				'
				Select @SFNAmount = (Select UnassociatedTotal from @SFN_UnassociatedTotal where SFN = '313')
				if @SFNAmount > 0 
					select @CreateTableSQL += 'f313_prorate decimal(16,2), [f313_plus_admin] decimal(16,2),
				'
					
				select @CreateTableSQL += 'f314 decimal(16,2),
				'
				Select @SFNAmount = (Select UnassociatedTotal from @SFN_UnassociatedTotal where SFN = '314')
				if @SFNAmount > 0 
					select @CreateTableSQL += 'f314_prorate decimal(16,2), [f314_plus_admin] decimal(16,2),
				'
				
				select @CreateTableSQL += 'f315 decimal(16,2),
				'
				Select @SFNAmount = (Select UnassociatedTotal from @SFN_UnassociatedTotal where SFN = '315')
				if @SFNAmount > 0 
					select @CreateTableSQL += 'f315_prorate decimal(16,2), [f315_plus_admin] decimal(16,2),
				'
				
				select @CreateTableSQL += 'f318 decimal(16,2),
				'
				Select @SFNAmount = (Select UnassociatedTotal from @SFN_UnassociatedTotal where SFN = '318')
				if @SFNAmount > 0 
					select @CreateTableSQL += 'f318_prorate decimal(16,2), [f318_plus_admin] decimal(16,2),
				'
					
				select @CreateTableSQL += 'f332 decimal(16,2),
				'
				
				select @CreateTableSQL += 'f220 decimal(16,2),
				'
				Select @SFNAmount = (Select UnassociatedTotal from @SFN_UnassociatedTotal where SFN = '220')
				if @SFNAmount > 0 
					select @CreateTableSQL += 'f220_prorate decimal(16,2), [f220_plus_admin] decimal(16,2),
				'
				
				select @CreateTableSQL += 'f22F decimal(16,2),
				'
				Select @SFNAmount = (Select UnassociatedTotal from @SFN_UnassociatedTotal where SFN = '22F')
				if @SFNAmount > 0 
					select @CreateTableSQL += 'f22F_prorate decimal(16,2), [f22F_plus_admin] decimal(16,2),
				'
					
				select @CreateTableSQL += 'f221 decimal(16,2),
				'
				Select @SFNAmount = (Select UnassociatedTotal from @SFN_UnassociatedTotal where SFN = '221')
				if @SFNAmount > 0 
					select @CreateTableSQL += 'f221_prorate decimal(16,2), [f221_plus_admin] decimal(16,2),
				'
					
				select @CreateTableSQL += 'f222 decimal(16,2),
				'
				Select @SFNAmount = (Select UnassociatedTotal from @SFN_UnassociatedTotal where SFN = '222')
				if @SFNAmount > 0 

					select @CreateTableSQL += 'f222_prorate decimal(16,2), [f222_plus_admin] decimal(16,2),
				'
					
				select @CreateTableSQL += 'f223 decimal(16,2),
				'
				Select @SFNAmount = (Select UnassociatedTotal from @SFN_UnassociatedTotal where SFN = '223')
				if @SFNAmount > 0 
					select @CreateTableSQL += 'f223_prorate decimal(16,2), [f223_plus_admin] decimal(16,2),
				'
					
				select @CreateTableSQL += 'f233 decimal(16,2),
				'
				
				select @CreateTableSQL += 'f234 decimal(16,2),
				'
				
				select @CreateTableSQL += 'f241 decimal(16,2),
				'
				Select @SFNAmount = (Select UnassociatedTotal from @SFN_UnassociatedTotal where SFN = '241')
				if @SFNAmount > 0 
					select @CreateTableSQL += 'f241_prorate decimal(16,2), [f241_plus_admin] decimal(16,2),
				'
					
				select @CreateTableSQL += 'f242 decimal(16,2),
				'
				Select @SFNAmount = (Select UnassociatedTotal from @SFN_UnassociatedTotal where SFN = '242')
				if @SFNAmount > 0 
					select @CreateTableSQL += 'f242_prorate decimal(16,2), [f242_plus_admin] decimal(16,2),
				'
					
				select @CreateTableSQL += 'f243 decimal(16,2),
				'
				Select @SFNAmount = (Select UnassociatedTotal from @SFN_UnassociatedTotal where SFN = '243')
				if @SFNAmount > 0 
					select @CreateTableSQL += 'f243_prorate decimal(16,2), [f243_plus_admin] decimal(16,2),
				'
					
				select @CreateTableSQL += 'f244 decimal(16,2),
				'
				Select @SFNAmount = (Select UnassociatedTotal from @SFN_UnassociatedTotal where SFN = '244')
				if @SFNAmount > 0 
					select @CreateTableSQL += 'f244_prorate decimal(16,2), [f244_plus_admin] decimal(16,2),
				'
					
				select @CreateTableSQL += 'f350 decimal(16,2)
				);'
				
				if @IsDebug = 1 
					Print @CreateTableSQL;
					
				Exec(@CreateTableSQL);
				
				Insert into [AD419].[dbo].[AD419_Non-Admin_WithProratedAmounts]
				(
					loc,
					dept,
					proj,
					project,
					accession,
					PI,
					f201,
					f202,
					f203,
					f204,
					f205,
					f231,
					f219,
					f209,
					f310,
					f308,
					f311,
					f316,
					f312,
					f313,
					f314,
					f315,
					f318,
					f220,
					f22F,
					f221,
					f222,
					f223,
					f241,
					f242,
					f243,
					f244
				)	
				SELECT 
					loc,
					dept,
					proj,
					project,
					accession,
					PI,
					f201,
					f202,
					f203,
					f204,
					f205,
					f231,
					f219,
					f209,
					f310,
					f308,
					f311,
					f316,
					f312,
					f313,
					f314,
					f315,
					f318,
					f220,
					f22F,
					f221,
					f222,
					f223,
					f241,
					f242,
					f243,
					f244
				FROM [AD419].[dbo].[AD419_Non-Admin];
				
--------------------------------------------------------------------------------------------------------------
				BEGIN --Section: Prorate admin amounts:
					declare MyCursor Cursor for select SFN, UnassociatedTotal, ProjectsTotal 
					from @SFN_UnassociatedTotal where UnassociatedTotal > 0  for READ ONLY;
					
					open MyCursor
					declare @MySFN varchar(4), @MyUnassociatedTotal decimal(16,2), @ProjectsTotal decimal(16,0), @ProrateAmount decimal(16,2)
					
					fetch next from MyCursor into @MySFN, @MyUnassociatedTotal, @ProjectsTotal
					
					while @@FETCH_STATUS <> -1
						BEGIN --while have more unassociated SFNs to prorate
							declare @TSQL varchar(max) = ''
							if @MySFN not in ('241','242','243','244')
								begin  --if @MySFN not in ('241','242','243','244')
									select @TSQL = 
									'update [AD419].[dbo].[AD419_Non-Admin_WithProratedAmounts] set f' + @MySFN + '_prorate    = (f' + @MySFN + ') / (' + CONVERT(varchar(50), @ProjectsTotal) + ') * ' + CONVERT(varchar(50), @MyUnassociatedTotal) + ';
									update [AD419].[dbo].[AD419_Non-Admin_WithProratedAmounts] set f' + @MySFN + '_plus_admin = (f' + @MySFN + ') + (f' + @MySFN + '_prorate);
									update [AD419].[dbo].[AD419_Admin] set f' + @MySFN +  '= (f' + @MySFN + ') + ((f' + @MySFN + ') / (select SUM(f' + @MySFN + ') from [AD419].[dbo].[AD419_Admin]) * ' + CONVERT(varchar(50), @MyUnassociatedTotal) + ');
									'
									if @IsDebug = 1
										print @TSQL
										
									EXEC (@TSQL)
								end --if @MySFN not in ('241','242','243','244') 
							else 
								begin -- else @MySFN in ('241','242','243','244') 
									if @IsDebug = 1
										select 'Now updating SFN: ' + @MySFN
										
									select @TSQL = '
									update [AD419].[dbo].[AD419_Non-Admin_WithProratedAmounts] set f' + @MySFN + '_prorate = ROUND((f' + @MySFN + ') / (' + CONVERT(varchar(50), @ProjectsTotal) + ') * ' + CONVERT(varchar(20), @MyUnassociatedTotal) + ',1);
									update [AD419].[dbo].[AD419_Non-Admin_WithProratedAmounts] set f' + @MySFN + '_plus_admin = (f' + @MySFN + ') + (f' + @MySFN + '_prorate);
									update [AD419].[dbo].[AD419_Admin] set f' + @MySFN +  '= (f' + @MySFN + ') +             ROUND((f' + @MySFN + ') / (' + CONVERT(varchar(50), @ProjectsTotal) + ') * ' + CONVERT(varchar(20), @MyUnassociatedTotal) + ',1);
									' 
									if @IsDebug = 1
										print @TSQL
									
									EXEC (@TSQL)
								    
									IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[TableValuesToProrate]') AND type in (N'U'))
										Drop TABLE [AD419].[dbo].[TableValuesToProrate];
										
									create TABLE [AD419].[dbo].[TableValuesToProrate] (accession varchar(7), amt decimal(16,2), prorate decimal(16,2))
								 
									select @TSQL = '
									select
									accession, f' + @MySFN + ', f' + @MySFN + '_prorate as prorate from [AD419].[dbo].[AD419_Non-Admin_WithProratedAmounts] where f' + @MySFN + ' > 0 order by f' + @MySFN + ' desc'
									if @IsDebug = 1
										print @TSQL
										
									insert into TableValuesToProrate (accession, amt, prorate) EXEC(@TSQL)
								
								if @IsDebug = 1
									BEGIN
										select 'Table values to prorate:'
										select * from TableValuesToProrate
									END
								 
								declare @RemainingAmountToApply decimal(16,2) = @MyUnassociatedTotal - (select SUM(prorate) from TableValuesToProrate)
								
								if @IsDebug = 1
									select 'Remaining amount to apply: ' + CONVERT(varchar(30),@RemainingAmountToApply )
									
								declare @RecordsToApplyTo int = abs(round(@RemainingAmountToApply/0.1,1))
								declare @AmountApplied decimal(16,2) = 0
								declare @RecordsAppliedTo int = 0
								declare MyCursor2 Cursor for select accession, amt, prorate
								from TableValuesToProrate for READ ONLY
								 
								open MyCursor2
								 
								declare @accession varchar(7), @amt decimal(16,2), @prorate decimal(16,2)
								
								fetch next from MyCursor2 into @accession, @amt, @prorate
								while @@FETCH_STATUS <> -1 AND @RecordsAppliedTo < @RecordsToApplyTo
									begin --while have outstanding unassociated amount to prorate for the given SFN
										declare @NewProrateAmount decimal(16,2) = 0
							
										if @RemainingAmountToApply < 0
											BEGIN
												select @NewProrateAmount = @prorate - 0.1
											END
										else
											BEGIN
												select @NewProrateAmount = @prorate + 0.1
											END
							
										Select @TSQL = '	
										update [AD419].[dbo].[AD419_Non-Admin_WithProratedAmounts] set f' + @MySFN + '_prorate = ' + Convert(varchar(50), @NewProrateAmount)
										+ ', f' + @MySFN + '_plus_admin = ' + Convert(varchar(50), @NewProrateAmount + @amt) + ' where accession = ' + Convert(varchar(7), @accession) + ';
									
										update [AD419].[dbo].[AD419_Admin] set f' + @MySFN + ' = ' + Convert(varchar(50), @NewProrateAmount + @amt) + ' where accession = ' + Convert(varchar(7), @accession) + ';
										'
						
										if @IsDebug = 1
											Print @TSQL
											
										EXEC(@TSQL)
						
										Select @AmountApplied = @AmountApplied + @NewProrateAmount
										Select @RecordsAppliedTo = @RecordsAppliedTo + 1
						
										fetch next from MyCursor2 into @accession, @amt, @prorate
									end --while have outstanding unassociated amount to prorate for the given SFN
								drop TABLE [AD419].[dbo].[TableValuesToProrate]
								
								if @IsDebug = 1
									select 'Amount: ' + Convert(varchar(50), @MyUnassociatedTotal) + '; Applied: ' + CONVERT(varchar(50), @AmountApplied)
								
								close MyCursor2
								deallocate MyCursor2	 
							end -- else @MySFN in ('241','242','243','244') 
							
						fetch next from MyCursor into @MySFN, @MyUnassociatedTotal, @ProjectsTotal
							
						END --while have more unassociated SFNs to prorate
						
					close MyCursor
					deallocate MyCursor
				
					-- Update the totals in the Category and Sub-Category Totals and Sub-totals
					-- in the AD419_Admin and AD419_Non-Admin tables:
					
					Update [AD419].[dbo].[AD419_Admin] set f231 = (f201 + f202 + f203 + f204 + f205)
					Update [AD419].[dbo].[AD419_Admin] set f332 = (f219 + f209 + f310 + f308 + f311 + f316 + f312 + f313 + f314 + f315 + f318)
					Update [AD419].[dbo].[AD419_Admin] set f233 = (f220 + f22F + f221 + f222 + f223)
					Update [AD419].[dbo].[AD419_Admin] set f234 = (f231 + f332 + f233)
					Update [AD419].[dbo].[AD419_Admin] set f350 = (f241 + f242 + f243 + f244)
					
					Update [AD419].[dbo].[AD419_Non-Admin_WithProratedAmounts] set f231 = (f201 + f202 + f203 + f204 + f205)
					Update [AD419].[dbo].[AD419_Non-Admin_WithProratedAmounts] set f332 = (select f332 from [AD419].[dbo].[AD419_Admin] t2 where t2.accession = [AD419].[dbo].[AD419_Non-Admin_WithProratedAmounts].accession) 
					Update [AD419].[dbo].[AD419_Non-Admin_WithProratedAmounts] set f233 = (select f233 from [AD419].[dbo].[AD419_Admin] t2 where t2.accession = [AD419].[dbo].[AD419_Non-Admin_WithProratedAmounts].accession)
					Update [AD419].[dbo].[AD419_Non-Admin_WithProratedAmounts] set f234 = (select f234 from [AD419].[dbo].[AD419_Admin] t2 where t2.accession = [AD419].[dbo].[AD419_Non-Admin_WithProratedAmounts].accession)
					Update [AD419].[dbo].[AD419_Non-Admin_WithProratedAmounts] set f350 = (select f350 from [AD419].[dbo].[AD419_Admin] t2 where t2.accession = [AD419].[dbo].[AD419_Non-Admin_WithProratedAmounts].accession)

				END --Section: Prorate admin amounts.
				
				BEGIN --Section: Create a flat table for the Report Server's Non-Admin with Proated Values Report,
					  --so that it can have a dynamic number of SFN prorate and SFN plus prorate columns:
				
					IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[AD419_Flat_NonAdminWithProrates]') AND type in (N'U'))
						DROP TABLE [dbo].[AD419_Flat_NonAdminWithProrates]
					
					create table [dbo].[AD419_Flat_NonAdminWithProrates]
					(loc char(2), dept char(3), proj char(4), project varchar(24), PI varchar(30), accession char(7), SFN varchar(20), expense decimal(16,2), position int, isFTE bit)

					-- get the name of the fields we're dealing with:
					declare MyFieldCursor Cursor for SELECT   COLUMN_NAME, ORDINAL_POSITION 
						FROM     INFORMATION_SCHEMA.COLUMNS WHERE     TABLE_NAME = 'AD419_Non-Admin_WithProratedAmounts' 
						AND COLUMN_NAME not in ('loc', 'dept', 'proj', 'project', 'accession', 'PI')
						ORDER BY ORDINAL_POSITION ASC FOR READ ONLY; 
					
						open MyFieldCursor
						declare @ColumnName varchar(50), @Position int
					
						fetch next from MyFieldCursor into @ColumnName, @Position
					
					while @@FETCH_STATUS <> -1
						BEGIN --while have more SFNs to add to flat table
							-- create a new row for each column in the table, for each project:
							declare MyCursor Cursor for select loc, dept, proj, project, accession, PI
							from dbo.[AD419_Non-Admin_WithProratedAmounts] order by accession  for READ ONLY;
					
							open MyCursor
							declare @loc char(2), @dept char(3), @proj char(4), @project varchar(24), @PI varchar(30) --, @accession char(7)
					
							fetch next from MyCursor into @loc, @dept, @proj, @project, @accession, @PI
					
							while @@FETCH_STATUS <> -1  
								BEGIN --while have more projects to add for given SFN
									Select @TSQL = 'insert into AD419_Flat_NonAdminWithProrates(loc, dept, proj, project, PI, accession, SFN, expense, position, isFTE)
									values (''' + @loc + ''', ''' +  @dept + ''', ''' +  @proj + ''', ''' +  @project + ''', ''' +   REPLACE(@PI, '''', '''''')  + ''', ''' + @accession + ''', ''' + @ColumnName + ''', 
									(select ' + @ColumnName +' from dbo.[AD419_Non-Admin_WithProratedAmounts] where accession = ''' + @accession + '''), ' + CONVERT(varchar(20), @Position) 
									
									-- This sets the isFTE bit so that the report server can format the
									-- field with 0.00 for expense amounts and 0.0 for FTE amounts. 
									If @ColumnName not like 'f24%' AND @ColumnName != 'f350'
										BEGIN
											-- Expense
											Select @TSQL += ', 0)'
										END
									ELSE
										BEGIN
											-- FTE
											Select @TSQL += ', 1)'
										END
										
									If @IsDebug = 1
										print @TSQL
										
									exec(@TSQL)
								
									fetch next from MyCursor into @loc, @dept, @proj, @project, @accession, @PI
								END --while have more projects to add for given SFN
								
							close MyCursor
							deallocate MyCursor
							
							fetch next from MyFieldCursor into @ColumnName, @Position
							
						END --while have more SFNs add to flat table
						
					close MyFieldCursor
					deallocate MyFieldCursor
						
				END --Section: Create a flat table for the Non-Admin with Proated Balues Report:
				
			end --Else all departments are fully associated so create/recreate tables.
			
	END --ELSE @ReportType != 0
	
END -- Main Program
