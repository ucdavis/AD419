-- =============================================
-- Author:		Ken Taylor
-- Create date: May 12, 2021
-- Description:	Return the results from the MCCA_Results table.
-- Prerequisites: MCAA_Results table must have been loaded.
-- Usage:
/*
	
	USE [PPSDataMart]
	GO

	SELECT * FROM udf_MCCAResults (0)
	GO

*/
-- Modifications:
--
-- =============================================
CREATE FUNCTION udf_MCCAResults 
(
	-- Add the parameters for the function here
	@IncludeEmployeeInfo bit = 0 -- Set to 1 to include EMP_ID and Name.
)
RETURNS 
@Table_Var TABLE 
(
	[SCH/DIV] varchar(10), 
	[SCH/DIV_DESC] varchar(100),
	[JOB_DEPT] varchar(10),
	[DEPT_NAME] varchar(100),
	[EMP_ID] int,
	[Name] varchar(150),
	FTE decimal(6,2),
	MCCAPercent decimal (6,2)
)
AS
BEGIN
	IF @IncludeEmployeeInfo = 1
		INSERT INTO @Table_Var
		SELECT TOP(100000) [SCH/DIV], [SCH/DIV_DESC], t1.JOB_DEPT, DEPT_NAME, EMP_ID, Name, FTE, MCCAPercent
		FROM MCCA_Results t1
		LEFT OUTER JOIN 
		 (
			SELECT DISTINCT [SCH/DIV], [SCH/DIV_DESC], JOB_DEPT, DEPT_NAME
			FROM [dbo].[UCPath_PersonJob]
		 ) t2 ON t1.JOB_DEPT = t2.JOB_DEPT
		ORDER BY [SCH/DIV], [SCH/DIV_DESC], t1.JOB_DEPT, DEPT_NAME, EMP_ID, Name
	ELSE
		INSERT INTO @Table_Var ([SCH/DIV], [SCH/DIV_DESC], t1.JOB_DEPT, DEPT_NAME, EMP_ID, Name, FTE, MCCAPercent)
		SELECT TOP(100000) [SCH/DIV], [SCH/DIV_DESC], t1.JOB_DEPT, DEPT_NAME, NULL AS EMP_ID, NULL AS Name, SUM(FTE) AS FTE, SUM(MCCAPercent) AS MCCAPercent
		FROM MCCA_Results t1
		LEFT OUTER JOIN 
		 (
			SELECT DISTINCT [SCH/DIV], [SCH/DIV_DESC], JOB_DEPT, DEPT_NAME
			FROM [dbo].[UCPath_PersonJob]
		 ) t2 ON t1.JOB_DEPT = t2.JOB_DEPT
		GROUP BY [SCH/DIV], [SCH/DIV_DESC], t1.JOB_DEPT, DEPT_NAME
		ORDER BY [SCH/DIV], [SCH/DIV_DESC], t1.JOB_DEPT, DEPT_NAME
		
	RETURN 
END