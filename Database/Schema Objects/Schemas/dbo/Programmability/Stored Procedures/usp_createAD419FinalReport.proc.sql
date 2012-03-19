-- =============================================
-- Author:		Scott Kirkland
-- Create date: 1/3/07
-- Description:	Creates the AD419 Final reports
-- showing the expense/FTE distribution across all
-- SFNs.  This includes processing the prorated admin
-- report
-- ============================================= 

CREATE PROCEDURE [dbo].[usp_createAD419FinalReport]
	@ReportType int = 0 -- 0 for NonAdmin report, 1 for Admin Report
	
AS
BEGIN

-- First we need to check to see that all non-excluded expenses have
-- been associated
DECLARE @OrgRExclusions varchar(16)
SET @OrgRExclusions = 'ADNO'

SELECT     OrgR, SUM(Expenses) AS Spent, SUM(FTE) AS FTE
FROM         Expenses
WHERE     (isAssociated = 0) AND ( OrgR NOT IN (@OrgRExclusions) )
GROUP BY OrgR
ORDER BY OrgR

IF @@ROWCOUNT <> 0
	BEGIN 
		PRINT 'WARNING: Not all departments fully associated'
		--RETURN -1
	END

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
	SELECT     'D*' AS loc, ReportingOrg.OrgCd3Char AS dept, SUBSTRING(Project.Project, 11, 4) AS proj, Project.Project, Project.Accession, Project.inv1 AS PI, 
						  Project.idProject AS proj_id
	FROM         Project INNER JOIN
						  ReportingOrg ON Project.CRIS_DeptID = ReportingOrg.CRISDeptCd
	WHERE     (ReportingOrg.OrgCd3Char <> '8455')
	ORDER BY dept, proj

-- Make sure XXX projects are in the XXX department
UPDATE @ProjectsList
SET dept = 'XXX'
WHERE project like '%XXX%'

--SELECT * FROM @ProjectsList
	
-- Check the @ReportType variable, 0 for NonAdmin report, 1 for Admin Report
IF @ReportType = 0
BEGIN
/*
	-- Base table for the report list
DECLARE @ReportList TABLE
(
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
*/
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
	
END
ELSE
BEGIN	
	--Need to prorate unassocaited amounts through the correct SFNs in the @ReportList table
	
	--Unassociated amount not in 201-205 or summation SFNS
	--So prorate from SFN table where line type code is SFN or FTE
	
	SELECT 
		SFN.SFN
		, (
			SELECT COUNT(*) FROM @ProjSFN AS PSFN WHERE PSFN.SFN = SFN.SFN AND PSFN.Amt > 0
		) as ProjCount
		, (
			SELECT ISNULL(SUM(Expenses),0) FROM Expenses WHERE isAssociated = 0 AND Expenses.Exp_SFN = SFN.SFN
		) as UnassociatedTotal
	FROM SFN_Display SFN
	WHERE  SFN.LineTypeCode = 'SFN'
	ORDER BY SFN.GroupDisplayOrder, SFN.LineDisplayOrder
	
	SELECT 
		SFN.SFN
		, (
			SELECT COUNT(*) FROM @ProjSFN AS PSFN WHERE PSFN.SFN = SFN.SFN AND PSFN.Amt > 0
		) as ProjCount
		, (
			SELECT ISNULL(SUM(FTE),0) FROM Expenses WHERE isAssociated = 0 AND Expenses.FTE_SFN = SFN.SFN
		) as UnassociatedTotal
	FROM SFN_Display SFN
	WHERE  SFN.LineTypeCode = 'FTE'
	ORDER BY SFN.GroupDisplayOrder, SFN.LineDisplayOrder
	
	--SELECT * FROM @ProjSFN
END

END
