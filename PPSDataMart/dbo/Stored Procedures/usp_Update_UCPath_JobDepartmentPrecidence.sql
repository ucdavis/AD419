-- =============================================
-- Author:		Ken Taylor
-- Create date: February 23, 2021
-- Description:	Truncates and Reloads the UCPath_JobDepartmentPrecidence table.
-- Prerequsites: The [dbo].[UCPath_PersonJob] must have been loaded first.
-- Usage:
/*
	USE [PPSDataMart]
	GO

	EXEC [dbo].[usp_Update_UCPath_JobDepartmentPrecidence]
	GO

*/
-- Modifications:
--
-- =============================================
CREATE PROCEDURE [dbo].[usp_Update_UCPath_JobDepartmentPrecidence] 
	-- Add the parameters for the stored procedure here
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

   -- Get employee's home department and all of their remaining departments for determining interdepartmental PIs

	-- Needed for new Person's table.
	-- Get Employee's home department and then all of their remaining departments in order of SUM(FTE) and/or Dept Name.

	  -- First load the  @JobDepartments table which will be used as a data source for the second step:
	  DECLARE @JobDepartments TABLE
	  (Name varchar(50), Emp_ID int, Emp_RCD int, Job_Dept varchar(10), FTE decimal(18,4), Job_Ind varchar(1))

	  INSERT INTO @JobDepartments
	  Select distinct name, emp_id, Emp_RCD, Job_Dept, FTE, Job_Ind
	  from  [dbo].[UCPath_PersonJob]
	  WHERE HR_STAT = 'A' AND EMP_STAT != 'T'
	  ORDER BY EMP_ID 

	  -- Secondly, identify all of an employee's unique departments, and sum of their FTE by department.
	  -- Note that some departments may be listed twice, as the employee may have more than 1 job in a 
	  -- particular department.  Therefore, we need some more sophiticated logic to only have each dept
	  -- listed a single time, but still retain the primary job precidence, and number them accordingly.  
	  -- That way we can more easily assign them to appropriate home, and alternate departments.
   
	DECLARE @myTable TABLE (RowID int, Name varchar(50), emp_id int, job_dept varchar(10), FTE decimal(18,4), JOB_IND varchar(1))
	INSERT INTO @myTable
	-- This external row numbering just add a row number to the precidence we've already determined.
	SELECT ROW_NUMBER() OVER (
		PARTITION BY EMP_ID
		ORDER BY CASE JOB_IND WHEN 'P' THEN 1 WHEN 'S' THEN 2 ELSE 3 END, FTE DESC, JOB_DEPT) AS MyID, t1.*
	FROM (
	-- Now that we have the unique list of departments, we can add up the FTE per department, as well as,
	-- add the remaining fields:
	-- Note that the rows will be ordered in the correct precidence, but will have yet to be prefixed with 
	-- numbered identifiers for subsequent queries.
		SELECT
			t1.Name, 
			t1.emp_id, 
			t1.job_dept, 
			SUM(t1.FTE) FTE, 
			t2.JOB_IND
		FROM @JobDepartments t1
		INNER JOIN  (
			-- This sub-query filters out any duplicate departments by only selecting those with an Row ID of 1.
			SELECT emp_id, job_dept, job_ind
			FROM (
				-- This sub-query returns a numbered list of Employee IDs, and job departments with their corresponding 
				-- job indicators.   Note that duplicate departments will be number sequentially by job indicator: P first, S second, and N last.
				SELECT ROW_NUMBER() OVER (PARTITION BY EMP_ID, JOB_DEPT ORDER BY CASE JOB_IND WHEN 'P' THEN 1 WHEN 'S' THEN 2 ELSE 3 END) AS MyID,
				emp_id, job_dept, job_ind
				FROM  @JobDepartments
				
			) t1
			WHERE MyID = 1
		) t2 ON t1.EMP_ID = t2.EMP_ID AND t1.JOB_DEPT = t2.JOB_DEPT
		GROUP BY  t1.Name, t1.emp_id, t1.job_dept, t2.JOB_IND
	) t1
	ORDER BY NAME, MyID

	-- CREATE TABLE JobDepartmentPrecidence (EMP_ID int, HomeDept varchar(10), 
	--AltDept1 varchar(10), AltDept2 varchar(10), AltDept3 varchar(10), AltDept4 varchar(10), AltDept5 varchar(10))

	-- Truncates and reloads table that has the employee's home department and then all of their remaining departments based on what was determind in the
	-- above query.

	TRUNCATE TABLE [dbo].UCPath_JobDepartmentPrecidence 

	INSERT INTO [dbo].UCPath_JobDepartmentPrecidence (EMPLID, HomeDept)
	SELECT emp_id, JOB_DEPT
	FROM @myTable 
	WHERE RowID = 1

	UPDATE  [dbo].UCPath_JobDepartmentPrecidence
	SET AltDept1 = t2.Job_Dept
	FROM  [dbo].UCPath_JobDepartmentPrecidence t1
	INNER JOIN (
		SELECT EMP_ID, JOB_DEPT
	FROM @myTable 
	WHERE RowID = 2
	) t2 ON t1.EMPLID = t2.EMP_ID

	UPDATE [dbo].UCPath_JobDepartmentPrecidence 
	SET AltDept2 = t2.Job_Dept
	FROM [dbo].UCPath_JobDepartmentPrecidence t1
	INNER JOIN (
		SELECT EMP_ID, JOB_DEPT
	FROM @myTable 
	WHERE RowID = 3
	) t2 ON t1.EMPLID = t2.EMP_ID

	UPDATE  [dbo].UCPath_JobDepartmentPrecidence 
	SET AltDept3 = t2.Job_Dept
	FROM  [dbo].UCPath_JobDepartmentPrecidence t1
	INNER JOIN (
		SELECT EMP_ID, JOB_DEPT
	FROM @myTable 
	WHERE RowID = 4
	) t2 ON t1.EMPLID = t2.EMP_ID

	UPDATE  [dbo].UCPath_JobDepartmentPrecidence
	SET AltDept4 = t2.Job_Dept
	FROM  [dbo].UCPath_JobDepartmentPrecidence t1
	INNER JOIN (
		SELECT EMP_ID, JOB_DEPT
	FROM @myTable 
	WHERE RowID = 5
	) t2 ON t1.EMPLID = t2.EMP_ID

	UPDATE  [dbo].UCPath_JobDepartmentPrecidence 
	SET AltDept5 = t2.Job_Dept
	FROM  [dbo].UCPath_JobDepartmentPrecidence t1
	INNER JOIN (
		SELECT EMP_ID, JOB_DEPT
	FROM @myTable 
	WHERE RowID = 6
	) t2 ON t1.EMPLID = t2.EMP_ID
END