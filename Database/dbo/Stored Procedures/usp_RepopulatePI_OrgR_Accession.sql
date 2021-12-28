



-- =============================================
-- Author:		Ken Taylor
-- Create date: August 14, 2017
-- Description:	Repopulate the PI_OrgR_Accession table.
-- Notes: This table can be used for setting the AllProjects and Project
--	tables IsInterdepartmental flag once it's been loaded, plus 
--	also be used to load the ProjXOrgR table
--
-- Prerequisites:
-- AllProjectsNew must have been loaded.
-- ProjectPI must have been loaded.
-- OrgXOrgR must have been loaded.
-- DOSCodes must have been reviewed.
-- ARCCodes must have been reviewed.
--
-- Usage:
/*

USE [AD419]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[usp_RepopulatePI_OrgR_Accession]
		@FiscalYear = 2021,
		@IsDebug = 1

--SELECT	'Return Value' = @return_value

GO

*/
-- Modifications:
-- 20181112 by kjt: Revised prerequisites to indicate AllProjects table instead of Project table as project  is loaded in future step.
-- 20201105 by kjt: Rewrote to work with UC Path data.
-- 20211111 by kjt: Revised to use our PPS Persons table as datasource for second pass after populating with PIs from UCP.
--		Also removed EFFDT from WHERE clause as this was filtering out employees because of cutoff dates.
-- 20211117 by kjt: Added another join to make sure AIND OrgR was preserved.
-- 20211120 by kjt: Added filtering to include projects where isIgnored = 0 as we were ending up prorating across 
--		204 projects with zero (0) expenses.
--
-- =============================================
CREATE PROCEDURE [dbo].[usp_RepopulatePI_OrgR_Accession]
	@FiscalYear int = 2021, 
	@IsDebug bit = 1
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @TSQL varchar(MAX) = ''

	SELECT @TSQL = '
	DECLARE @HomeDepartments TABLE (HomeDeptNum varchar(10), Org varchar(6), DeptName varchar(50))
	INSERT INTO @HomeDepartments
	SELECT HomeDeptNum, Org, Name
		FROM (
			SELECT ROW_NUMBER() OVER (PARTITION BY HomeDeptNum ORDER BY NumOcc DESC) AS MyID, t1.*
			FROM (
				SELECT DISTINCT 
				COUNT(*) NumOcc, HomeDeptNum, CASE WHEN Org4 = ''AAES'' THEN Org6 ELSE Org5 END AS Org
				, CASE WHEN Org4 = ''AAES'' THEN Name6 ELSE Name5 END AS Name
					FROM [FISDataMart].[dbo].[Organizations_UFY_v]
					WHERE Chart = ''3'' AND
						Org4 IN (''AAES'', ''BIOS'') AND
						CASE WHEN Org4 = ''AAES'' THEN Org6 ELSE Org5 END IS NOT NULL AND
						ACTIVEIND = ''Y''
					GROUP by HomeDeptNum, 
						CASE WHEN Org4 = ''AAES'' THEN Org6 ELSE Org5 END, 
						CASE WHEN Org4 = ''AAES'' THEN Name6 ELSE Name5 END
				) t1
		) t2 
	WHERE MyID = 1
	ORDER BY HomeDeptNum

	DECLARE @InterdepartmentalPIs TABLE (
			EmployeeID varchar(10), 
			FullName varchar(100),
			JobDept varchar(10),
			DeptName varchar(50),
			EmployeeOrgR varchar(4),
			--JobcodeDesc varchar(50),  -- Can''t include because some PIs have more than 1 AES jobcode, and 
										-- adding this column makes them have more than 1 entry.
			FTE decimal (18,6),
			IsInterdepartmental bit
	)

	-- Add multi and single dept PIs:
	INSERT INTO @InterdepartmentalPIs 
	SELECT t1.EMP_ID, t1.Name ,t1.[JOB_DEPT], t1.[DEPT_NAME], 
	CASE WHEN t4.OrgR = ''AIND'' THEN t4.OrgR ELSE Org END AS Org,
	SUM(FTE) FTE, CASE WHEN NumDepts > 1 THEN 1 ELSE 0 END AS IsInterdepartmental
	FROM [PPSDataMart].[dbo].[UCP_PersonJob] t1 -- Note that this table must have been updated from OPENQUERY([FIS_BISTG_PRD (CAESAPP_HCMODS_APPUSER)],...) 
		--previously to running this sproc.  Therefore, may want to perform a check prior to running, and fail otherwise.
	INNER JOIN
	(
		SELECT DISTINCT EMP_ID, Name, JobCode, --EFF_DT, 
			COUNT(*) AS NumDepts
		FROM [PPSDataMart].[dbo].[UCP_PersonJob]
		-- 2021-11-11 by kjt: EFFDT was causing filtering of PIs because the dates were no longer useable.
		WHERE --EFF_DT BETWEEN ''' + CONVERT(varchar(4), @FiscalYear-1) + '-10-01' + ''' AND ''' + CONVERT(varchar(4), @FiscalYear) + '-09-30' + ''' AND
		 JobCode IN (
			SELECT DISTINCT [JOBCODE]
			FROM OPENQUERY([FIS_BISTG_PRD (CAESAPP_HCMODS_APPUSER)], ''
				SELECT * FROM CAESAPP_HCMODS.PS_JOBCODE_TBL_V jc
				WHERE DESCR LIKE ''''%AES%''''
				  AND EFF_STATUS = ''''A'''' AND
				  EFFDT = (
					SELECT MAX(EFFDT)
					FROM CAESAPP_HCMODS.PS_JOBCODE_TBL_V jc2
					WHERE jc.JOBCODE = jc2.JOBCODE AND
						jc.EFF_STATUS = jc2.EFF_STATUS AND
						jc2.EFFDT <= CURRENT_DATE AND 
						DML_IND <> ''''D''''
				  )
		   '')
		  ) AND [SCH/DIV] IN (''01'',''22'', ''300000'')
		GROUP BY EMP_ID, Name, JobCode --, EFF_DT
	) t2 ON t1.EMP_ID = t2.EMP_ID AND t1.JOBCODE = t2.JOBCODE --AND t1.EFF_DT = t2.EFF_DT
	LEFT OUTER JOIN @HomeDepartments t3 ON JOB_DEPT = HomeDeptNum
	LEFT OUTER JOIN ProjectPI t4 ON t1.EMP_ID = t4.employeeID
	GROUP BY t1.EMP_ID, t1.Name ,t1.[JOB_DEPT], t1.[DEPT_NAME], CASE WHEN t4.OrgR = ''AIND'' THEN t4.OrgR ELSE Org END, NumDepts
	ORDER BY NumDepts DESC, NAME, ORG

	-- 2021-11-11 by kjt: Second pass to get missing PIs which are present in ProjectPI tab;e, but missing from
	--  @InterdepartmentalPIs table.

	INSERT INTO @InterdepartmentalPIs (EmployeeID, FullName, JobDept, EmployeeOrgR, IsInterdepartmental )
	SELECT DISTINCT t1.EmployeeId, t2.FullName, 
		CASE WHEN t2.HomeDepartment LIKE ''03%'' OR t2.AlternateDepartment IS NULL THEN t2.HomeDepartment 
			 WHEN t2.AlternateDepartment LIKE ''03%'' THEN t2.AlternateDepartment  
			 ELSE  [AdministrativeDepartment] 
		END AS JobDept, t1.OrgR EmployeeOrgR, 0 AS IsInterdepartmental
	FROM ProjectPI t1
	LEFT OUTER JOIN PPSDataMart.dbo.Persons t2 ON t1.EmployeeId = t2.EmployeeID
	LEFT OUTER JOIN PPSDataMart.dbo.Departments t3 ON t2.HomeDepartment = t3.HomeDeptNo
	LEFT OUTER JOIN PPSDataMart.dbo.Departments t4 ON t2.AlternateDepartment = t4.HomeDeptNo
	LEFT OUTER JOIN PPSDataMart.dbo.Departments t5 ON t2.[AdministrativeDepartment] = t5.HomeDeptNo
	WHERE NOT EXISTS (
		SELECT DISTINCT EmployeeID 
		FROM @InterdepartmentalPIs t4
		WHERE t1.EmployeeID = t4.EmployeeID
	)
	
	UPDATE @InterdepartmentalPIs 
	SET EmployeeOrgR = t2.OrgR
	FROM @InterdepartmentalPIs t1
	INNER JOIN udf_AD419ProjectsForFiscalYearWithIgnored(' + CONVERT(varchar(4), @FiscalYear) + ') t2 ON t1.EmployeeID = t2.EmployeeId
	WHERE EmployeeOrgR IS NULL

	---
	-- Continuing on with original logic and populating temp table:

	DECLARE @PI_Accession_OrgR TABLE(PI varchar(50), EmployeeID varchar(10), Accession varchar(10), OrgR varchar(4), IsInterdepartmental bit)

	INSERT INTO @PI_Accession_OrgR 
	SELECT DISTINCT
		PI 
		, t1.EmployeeID 
		, t4.Accession
		, COALESCE(t5.AD419OrgR, t1.EmployeeOrgR) OrgR
		, t1.IsInterdepartmental
	FROM @InterdepartmentalPIs t1
	INNER JOIN [dbo].[ProjectPI] t3 ON t1.EmployeeID = t3.EmployeeID 
	INNER JOIN [dbo].[udf_AD419ProjectsForFiscalYearWithIgnored](' + CONVERT(char(4), @FiscalYear) + '
	) t4 ON t3.EmployeeID = t4.EmployeeID 
	LEFT OUTER JOIN [dbo].[ExpenseOrgR_X_AD419OrgR] t5 ON 
		t1.EmployeeOrgR = t5.ExpenseOrgR AND t5.Chart = ''3'' AND 
		COALESCE(t5.AD419OrgR, t1.EmployeeOrgR) <> ''ADNO'' -- Excludes an extra entry for Gary Trexler''s ADNO appointment. 
	WHERE t4.IsIgnored IS NULL OR t4.IsIgnored = 0
	GROUP BY t1.EmployeeID, t1.FullName, COALESCE(t5.AD419OrgR, t1.EmployeeOrgR),  
		PI, t4.Accession, t1.IsInterdepartmental

	-- Once we have this data, we can accurately populate the ProjXOrgR table, plus
	-- probably the PI Match and/or PI Names tables, etc.

	TRUNCATE TABLE PI_OrgR_accession
	INSERT INTO PI_OrgR_accession
	SELECT * 
	FROM @PI_Accession_OrgR
	ORDER BY IsInterdepartmental DESC, PI, Accession, OrgR
'
	PRINT @TSQL
	IF @IsDebug <> 1
	BEGIN
		EXEC(@TSQL)
	END

END