-- =============================================
-- Author:		Ken Taylor
-- Create date: May 11, 2021
-- Description:	Loads the various tables needed for and populates the MCCA results table.
-- Prerequsites: The UCPath_PersonJob table has been loaded from campus, plus the 
--	MCCA_ExcludedJobcodes table.
-- Notes: Periodically, the job codes present in the MCCA_ExcludedJobcodes table should
--	 be reviewed to determine correctness, plus new job codes added as appropriate, usually
--	 those prefixed with "CWR".
-- Usage:
/*

	USE [PPSDataMart]
	GO

	EXEC [dbo].[usp_LoadMccaTables] @IsDebug = 1
	GO

*/
-- Modifications:
-- 
-- =============================================
CREATE PROCEDURE usp_LoadMccaTables 

	@IsDebug bit = 0 -- Set to 1 to print SQL only; 0 to run the stored procedure.
AS
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @TSQL varchar(max) = ''
	SELECT @TSQL = '
	--------------------------------------------------------------------------------------
	-- Step 1:
	-- Main get all active employee and jobs records that are not in the excluded jobcoes table:

	TRUNCATE TABLE MCCA_AllNonExcludedEmployees

	INSERT INTO MCCA_AllNonExcludedEmployees
	SELECT t1.EMP_ID, t2.Name, t1.JOB_DEPT, t2.JOBCODE, t2.FTE, t1.EFF_DT, t1.EMP_RCD, t1.EFF_SEQ, t2.EMP_STAT 
	--INTO MCCA_AllNonExcludedEmployees
	FROM (
	SELECT DISTINCT 
     
		  [EMP_ID], [EMP_STAT], EMP_RCD, EFF_SEQ, EFF_DT, JOB_DEPT
    
	  FROM [PPSDataMart].[dbo].[UCPath_PersonJob] t1
	  WHERE 
	   t1.EFF_DT = (
		SELECT MAX(EFF_DT)  
		FROM [PPSDataMart].[dbo].[UCPath_PersonJob] t2
		WHERE t1.EMP_ID = t2.EMP_ID
			AND t1.EMP_RCD = t2.EMP_RCD
			AND t2.EFF_DT <= GETDATE()

	  ) AND t1.EFF_SEQ = (
		SELECT MAX(EFF_SEQ) 
		FROM  [PPSDataMart].[dbo].[UCPath_PersonJob] t3
		WHERE t1.EMP_ID = t3.EMP_ID AND 
			t1.EMP_RCD = t3.EMP_RCD AND 
			t1.EFF_DT = t3.EFF_DT
	  )

	  ) t1 
	  INNER JOIN  [PPSDataMart].[dbo].[UCPath_PersonJob] t2
	  ON t1.EMP_ID = t2.EMP_ID AND t1.EFF_DT = t2.EFF_DT AND t1.EMP_RCD = t2.EMP_RCD AND t1.EFF_SEQ = t2.EFF_SEQ
  
	  WHERE t1.[EMP_STAT] = ''A''  --This may need to be modified to include employees on paid leeave, depending on
									-- whether or not paid leave is just a temporary absence like vacation or sick leave
									-- and the employee will be returning to work after the leave is over.
	  AND t2.JOBCODE NOT IN (
		SELECT JOBCODE FROM [dbo].[MCCA_ExcludedJobcodes]
	  ) 

	ORDER BY t1.EMP_ID

	--------------------------------------------------------------------------------------
    -- Step 2:
	-- Remove all EMP_RCD with a 0 FTE If non-zero FTE records exist for the same employee so we don''t
	-- count employees more than once:

	/*
	-- Test to verify the SQL is correct:

	SELECT ID, EMP_ID, NAME, FTE, JOBCODE, EMP_RCD, JOB_DEPT
	FROM MCCA_AllNonExcludedEmployees t1
	WHERE EXISTS  (
			SELECT EMP_ID
			FROM MCCA_AllNonExcludedEmployees t2
			WHERE  t1.EMP_ID = t2.EMP_ID  AND t2.FTE > 0

	) AND t1.FTE = 0
	ORDER BY EMP_ID
	*/

	DELETE FROM MCCA_AllNonExcludedEmployees 
	WHERE ID IN  (
		SELECT  ID
		FROM MCCA_AllNonExcludedEmployees t1
		WHERE EXISTS  (
			SELECT EMP_ID
			FROM MCCA_AllNonExcludedEmployees t2
			WHERE  t1.EMP_ID = t2.EMP_ID  AND t2.FTE > 0
		) AND FTE = 0
	) 
'

	IF @IsDebug = 1 
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)


	SELECT @TSQL = '
	--------------------------------------------------------------------------------------
	-- Step 3:
	/*
		At this point we should have the following:
		1. Zero or greater FTE with a single department: promote FTE to 1
		2. Zero FTE in multiple departments: promote FTE to 1/num departments, so that total FTE for employee is 1
		3. Greater than zero FTE in multiple departments: Calculate percentage based on 
		((((1-FTE)/FTE)*SUM(department.[FTE]))+SUM(department.[FTE])), so as only having a max sum of 1 FTE per employee.
 
	*/

	--CREATE TABLE MCCA_2021_Results (EMP_ID int, Name varchar(150), JOB_DEPT varchar(10), FTE Decimal(10,8), MCCAPercent Decimal(4,2))
	IF EXISTS (SELECT 1 
				FROM INFORMATION_SCHEMA.TABLES 
				WHERE TABLE_TYPE=''BASE TABLE'' 
				AND TABLE_NAME=''MCCA_Results_bak'') 
		BEGIN
		-- Check if the MCCA_Results has data 
		-- If yes, then truncate it, if no, then keep the existing data.

			IF (SELECT COUNT(*) FROM MCCA_Results) > 0
			BEGIN
				PRINT ''MCCA_Results table contains Data'';

				TRUNCATE TABLE MCCA_Results_bak
				INSERT INTO MCCA_Results_bak
				SELECT * 
				FROM MCCA_Results
				ORDER BY EMP_ID, JOB_DEPT 
			END
		
			ELSE 
			BEGIN
				Print ''MCCA_Results table is Empty - Skipping''
			END
	
		END

		ELSE 
		BEGIN
			-- Table does not exist, so we can just copy over the data
			PRINT ''MCCA_Results table does not exist, copying data...''
			SELECT * INTO MCCA_Results_bak
			FROM MCCA_Results
			ORDER BY EMP_ID, JOB_DEPT 
		END

	-- Actually truncate and reload the MCCA_Results table:

	TRUNCATE TABLE MCCA_Results
	---------------------------------------------------------------------------------
	-- 1. Single Department FTE >= 0

	INSERT INTO MCCA_Results
	SELECT DISTINCT  pj.EMP_ID, pj.Name, pj.JOB_DEPT, lo.FTE, 1 AS MCCAPercent

	FROM MCCA_AllNonExcludedEmployees pj
	INNER JOIN (
		SELECT EMP_ID, SUM(FTE) AS FTE
		FROM MCCA_AllNonExcludedEmployees
		GROUP BY EMP_ID
		HAVING COUNT(DISTINCT JOB_DEPT) = 1 --AND SUM(FTE) >0 --AND EMP_ID = 10157200

	) lo ON pj.EMP_ID = lo.EMP_ID
	--WHERE EMP_ID = 10233320
	GROUP BY  pj.EMP_ID, pj.Name, pj.JOB_DEPT, lo.FTE

	ORDER BY  pj.EMP_ID, pj.Name, pj.JOB_DEPT, lo.FTE

	----------------------------------------------------------------
	-- 2. Muptiple Departments FTE = 0:

	INSERT INTO MCCA_Results
	SELECT  DISTINCT pj.EMP_ID, pj.Name, pj.JOB_DEPT, SUM(pj.FTE) FTE, (1/Convert(decimal(4,2),NumJobDepts)) MCCAPercent
	FROM MCCA_AllNonExcludedEmployees pj
	INNER JOIN (
		SELECT EMP_ID, COUNT(DISTINCT JOB_DEPT) NumJobDepts
		FROM MCCA_AllNonExcludedEmployees
		GROUP BY EMP_ID
		HAVING COUNT(DISTINCT JOB_DEPT) > 1 AND SUM(FTE) = 0

	) lo ON pj.EMP_ID = lo.EMP_ID
	GROUP BY  pj.EMP_ID, pj.Name, pj.JOB_DEPT, (1/Convert(decimal(4,2),NumJobDepts))

	----------------------------------------------------------------
	-- Muptiple Departments FTE >0:

	INSERT INTO MCCA_Results
	SELECT pj.EMP_ID, pj.Name, pj.JOB_DEPT, pj.FTE,
	((((1-lo.FTE)/lo.FTE)*SUM(pj.[FTE]))+SUM(pj.[FTE]))  AS MCCAPercent

	FROM MCCA_AllNonExcludedEmployees pj
	INNER JOIN (
		SELECT EMP_ID, SUM(FTE) FTE
		FROM MCCA_AllNonExcludedEmployees
		GROUP BY EMP_ID
		HAVING COUNT(DISTINCT JOB_DEPT) > 1 AND SUM(FTE) >0 --AND EMP_ID = 10233320

	) lo ON pj.EMP_ID = lo.EMP_ID
	--WHERE pj.EMP_ID = 10233320
	GROUP BY  pj.EMP_ID, pj.Name, pj.JOB_DEPT, pj.FTE, lo.FTE
'

	IF @IsDebug = 1 
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)


END