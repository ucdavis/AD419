
-- =============================================
-- Author:		Ken Taylor
-- Create date: January 21, 2021
-- Description:	Return the data that would have ultimately been present on the AD-419 
--  non-admin report so that it can be reviewed prior to actually running the report
--  generation process.
--  This way it will not be necessary to re-hide certain 204 projects with exenses < $100,
--  and re-run the entire report generation process should it be necessary to make
--  adjustments to the departments' associations.
--
-- Usage: 
/*

	USE [AD419]
	GO

	EXEC [dbo].[usp_GetNonAdminPreReport]

*/
-- Modifications:
--
-- =============================================
CREATE PROCEDURE [dbo].[usp_GetNonAdminPreReport]
AS 
BEGIN
	-- Fill the table variable with the rows for your result set

-- First we need to check to see that all non-excluded expenses have
-- been associated

	DECLARE	@return_value int = -1
	DECLARE @ErrorMessage varchar(1024) = 'WARNING: Not all departments fully associated'

	DECLARE @OrgRExclusions TABLE (OrgR varchar(4))
	INSERT INTO @OrgRExclusions --
	SELECT * FROM udf_GetOrgRExclusions() -- Use the function instead. VALUES ('ADNO'), ('ACL1'), ('ACL2'), ('ACL3'), ('ACL4'), ('ACL5')

	DECLARE @UnassociatedExpenseCount int = (
	SELECT     COUNT(*)
	FROM         Expenses
	WHERE     (isAssociated = 0) AND ( OrgR NOT IN (
		SELECT * FROM @OrgRExclusions) )
	)

	IF @UnassociatedExpenseCount > 0
		BEGIN 
			RAISERROR(@ErrorMessage, 16, 1)
			RETURN @return_value
		END

	DECLARE @ProjSFN TABLE
		(
			Project varchar(24),
			Accession char(7),
			OrgR char(4),
			inv1 varchar(150),
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
	--HAVING      (SUM(Associations.Expenses) > 0)  -- Show any credits.

	-- Populate this time with FTE data
	INSERT INTO @ProjSFN
	SELECT     Project.Project, Project.Accession, Associations.OrgR, Project.inv1, Expenses.FTE_SFN, ISNULL(ROUND(SUM(Associations.FTE), 1),0) AS Amt, 0
	FROM         Expenses INNER JOIN
						  ReportingOrg ON Expenses.OrgR = ReportingOrg.OrgR INNER JOIN
						  Associations ON Expenses.ExpenseID = Associations.ExpenseID INNER JOIN
						  Project ON Associations.Accession = Project.Accession
	GROUP BY Project.Project, Project.Accession, Associations.OrgR, Project.inv1, Expenses.FTE_SFN
	--HAVING      (SUM(Associations.FTE) > 0) -- Show any credits.

	-- Start populating the DAVIS_PROJECTS table with a record for each project
	DECLARE @ProjectsList TABLE
	(
		loc char(2),
		dept char(3),
		proj char(4),
		project varchar(24),
		accession char(7),
		PI varchar(150),
		proj_id int,
		is_interdepartmental bit
	)

	INSERT INTO @ProjectsList
		SELECT     'D' AS loc, ReportingOrg.OrgCd3Char AS dept, SUBSTRING(Project.Project, 10, 4) AS proj, Project.Project, Project.Accession, Project.inv1 AS PI, 
							  Project.idProject AS proj_id, Project.IsInterdepartmental AS is_interdepartmental
		FROM         Project INNER JOIN
								ReportingOrg ON Project.CRIS_DeptID = ReportingOrg.CRISDeptCd
							 INNER JOIN 
								ProjXOrgR ON Project.Accession = ProjXOrgR.Accession
		WHERE     (ReportingOrg.OrgCd3Char <> '8455')
		ORDER BY dept, proj

	-- Make sure XXX projects are in the XXX department
	UPDATE @ProjectsList
	SET dept = 'XXX'
	WHERE project like '%XXX%'

	--SELECT * FROM @ProjectsList
	
	BEGIN

		-- Base table for the report list
	DECLARE @ReportList TABLE
	(
		loc char(2),
		dept char(3),
		proj char(4),
		project varchar(24),
		accession char(7),
		PI varchar(150),
		IsInterdepartmental bit,
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
		SELECT DISTINCT
			loc
			, dept
			, proj
			, project
			, accession
			, PI
			, is_interdepartmental
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
			, (
				SELECT ISNULL(SUM(Amt), 0) 
				FROM @ProjSFN AS PSFN
				WHERE PList.Accession = PSFN.Accession AND SFN = '231' 
			) AS f231
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
			, (
				SELECT ISNULL(SUM(Amt), 0) 
				FROM @ProjSFN AS PSFN
				WHERE PList.Accession = PSFN.Accession AND SFN = '332' 
			) AS f332
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
			, (
				SELECT ISNULL(SUM(Amt), 0) 
				FROM @ProjSFN AS PSFN
				WHERE PList.Accession = PSFN.Accession AND SFN = '233' 
			) AS f233
			, (
				SELECT ISNULL(SUM(Amt), 0) 
				FROM @ProjSFN AS PSFN
				WHERE PList.Accession = PSFN.Accession AND SFN = '234' 
			) AS f234
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
			, (
				SELECT ISNULL(SUM(Amt), 0) 
				FROM @ProjSFN AS PSFN
				WHERE PList.Accession = PSFN.Accession AND SFN = '350' 
			) AS f350
		FROM @ProjectsList AS PList
		ORDER BY dept, proj

		-- Add the sub-totals and total:
		UPDATE @ReportList
		SET f231 = f201 + f202 + f203 + f204 + f205,
			f332 = f219 + f209 + f310 + f308 + f311 + f316 + f312 + f313 + f314 + f315 + f318,
			f233 = f220 + f22F + f221 + f222 + f223,
			f350 = f241 + f242 + f243 + f244

		-- This needs to be done here, after the sub-totals have baan saved.
		UPDATE  @ReportList
		set f234 = f231 + f332 + f233



		-- This is data is essentially what is on the non-admin report:
	SELECT 
		loc,
		dept,
		proj,
		project,
		accession,
		PI,		
		IsInterdepartmental,
		f201 AS [201 - Hatch],
		f202 AS [202 - Multi St],
		f203 AS [203 - McStenn],
		f204 AS [204 - NIFA CG],
		f205 AS [205 - Anm Hlth],
		f231 AS [231 - Total NIFA],
		f219 AS [219 - USDA],
		f209 AS [209 - NSF],
		f310 AS [310 - DOE],
		f308 AS [308 - AID],
		f311 AS [311 - DOD],
		f316 AS [316 - NIH],
		f312 AS [312 - PHS],
		f313 AS [313 - HHS],
		f314 AS [314 - NASA],
		f315 AS [315 - TVA],
		f318 AS [318 - Other Fed],
		f332 AS [332 - Total Fed],
		f220 AS [220 - State],
		f22F AS [22F - REC],
		f221 AS [221 - Self Sup],
		f222 AS [222 - Industry],
		f223 AS [223 - Other Non Fed],
		f233 AS [233 - Total Non Fed],
		f234 AS [234 - Total All Funds],
		f241 AS [241 - SCI FTE],
		f242 AS [242 - PROF FTE],
		f243 AS [243 - TECH FTE],
		f244 AS [244 - OTHER FTE],
		f350 AS [350 - Total FTE]
	 FROM @ReportList

	END
END