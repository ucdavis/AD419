
-- =============================================
-- Author:		Ken Taylor
-- Create date: August 14, 2017
-- Description:	Repopulate the ProjectPI table.
-- Notes: This removes the match with the expenses table because the AccountPi
--	now contains a more complete set of employees.  It also moves the UCD_PERSON
--	match up before the final two, as opposed to being the last one.
--
-- Prerequisites:
--	AccountPI must have been loaded.
--	OrgXOrgR must have been loaded.
--	UCDPerson must have updated.
-- Usage:
/*

USE [AD419]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[usp_RepopulateProjectPI_v2]
		@FiscalYear = 2020,
		@IsDebug = 0

--SELECT	'Return Value' = @return_value

GO

*/
-- Modifications:
--	20171026 by kjt: Added new UCD_Person matching on firstname, lastname, Plus decided to truncate table entriely upon reload,
--		as I was getting strange results on with merge, plus PI's may move departments and this would foul up the logic elsewhere.
--	20181112 by kjt: Revised logic to use udf_AD419ProjectsForFiscalYear for project data source as project table has yet to be loaded
--		at this point in the data helper process.
--	20191121 by kjt: Hardcoded fixes for 3 employees until I have an opportunuity to do additional
--		research in the correct ordering to set the correct EmployeeID programatically.
--	20191127 by kjt: Changed the hard-codes destination to the @ProiectsPI table so the results would be propigated to the ProjectPI
--		database table, which is what I had intended.
--		Reordered the logic so that the correct employee IDs would be assigned.  Removed the hard-coding since this was no longer necessary.
--	20201028 by kjt: Replaced join to UCD_PERSON with [PPSDataMart].[dbo].[RICE_UC_KRIM_PERSON]
--	20201104 by kjt: Added final two sections that match names which couldn't be found otherwise by
--		search old UCD_PERSON table for their PPS ID, and then cross-referencing to find UCP Emplid
--		using PS_UC_EXT_SYSTEM.
--	20201105 by kjt: Added FirstName to table fields.
--	20201116 by kjt: Fixed hard coding of date, whoops.
--	20201118 by kjt: Revised to more accrately populate employee IDs
-- 
-- =============================================
CREATE PROCEDURE [dbo].[usp_RepopulateProjectPI_v2]
	-- Add the parameters for the stored procedure here
	@FiscalYear int = 2020, 
	@IsDebug bit = 0
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

	DECLARE @ProjectPI TABLE (OrgR varchar(4), Inv1 varchar(50), PI varchar(50), LastName varchar(50), FirstInitial char(1), EmployeeID varchar(10),
	FirstName varchar(20))

	-- Step 1a: Insert Project PIs:
	INSERT INTO @ProjectPI (OrgR, Inv1, PI)
	SELECT DISTINCT OrgR,Inv1, REPLACE(REPLACE(Inv1, ''  '' , '' ''), '', '', '','') PI
    FROM [dbo].[udf_AD419ProjectsForFiscalYearWithIgnored] (' + CONVERT(varchar(4), @FiscalYear) + ')
	--(366 row(s) affected)

	-- Step 1b: Update FirstInitial and LastName:
	UPDATE @ProjectPI
	SET FirstInitial = SUBSTRING(PI, CHARINDEX('','', PI) + 1, 1),
	LastName = SUBSTRING(PI, 1, CHARINDEX('','', PI) - 1),
	FirstName = SUBSTRING(PI, CHARINDEX('','', PI) + 1, LEN(PI))
	--(366 row(s) affected)

	UPDATE @ProjectPI
	SET  EmployeeID = t2.UCP_EMPLID
	FROM @ProjectPI t1
	INNER JOIN ( 
	  SELECT DISTINCT ppi.PI, ppi.OrgR, EMP_ID UCP_EMPLID, EmployeeID 
	  FROM @ProjectPI ppi
	  INNER JOIN PPSDataMart.dbo.UCP_PersonJob t1 ON t1.Name like ppi.PI + ''%''
	  INNER JOIN @HomeDepartments t2 ON t1.JOB_DEPT = t2.HomeDeptNum
	  WHERE t1.Name like  ppi.PI + ''%''  AND ppi.OrgR = t2.Org 
	  AND (RIGHT(t1.JOBCODE,4) IN (
			Select DISTINCT TitleCode
			FROM PPSDataMart.dbo.Titles
			WHERE stafftype = ''1S''
	  ) OR (JOBCODE_DESC LIKE ''%AES%'')
	  ) AND ppi.EmployeeID IS NULL
	) t2 ON t1.PI = t2.PI AND t1.OrgR = t2.OrgR
	WHERE t1.EmployeeID IS NULL AND UCP_EMPLID IS NOT NULL

	 -- This get''s us more, but we end up with 2 entries for 
	UPDATE ProjectPI
	SET  EmployeeID = t2.UCP_EMPLID
	FROM @ProjectPI t1
	 INNER JOIN ( 
		  SELECT DISTINCT ppi.PI, ppi.OrgR, EMP_ID UCP_EMPLID, EmployeeID 
		  FROM @ProjectPI ppi
		  INNER JOIN PPSDataMart.dbo.UCP_PersonJob t1 ON t1.Name like ppi.PI + ''%''
		  INNER JOIN @HomeDepartments t2 ON t1.JOB_DEPT = t2.HomeDeptNum
		  WHERE t1.Name like  ppi.PI + ''%''  AND ppi.OrgR = t2.Org 
		  AND ppi.EmployeeID IS NULL AND t1.EMP_ID IS NOT NULL
	) t2 ON  t1.PI = t2.PI AND t1.OrgR = t2.OrgR
	 WHERE t1.EmployeeID IS NULL AND t2.UCP_EMPLID IS NOT NULL

	-- This sequence gives us correct results and no mis-matched employee IDs
	-- Step 2: Try to find employee IDs for PIs:
	UPDATE @ProjectPI
	SET EmployeeID = t2.EmployeeID
	FROM @ProjectPI t1
	INNER JOIN (
		SELECT distinct PI_Name, EmployeeID, LastName, FirstName, ShortName FROM AccountPI A
		INNER JOIN (
			SELECT LastName + '','' + LEFT(FirstName,1) ShortName FROM
			AccountPI
			GROUP BY LastName + '','' + LEFT(FirstName,1) having count(*) = 1
		) ti ON LastName +'','' +LEFT(FirstName,1) = ShortName
	  ) t2 ON t1.LastName +'','' +LEFT(t1.FirstName,1) = ShortName

	-- Gives us Culshaw-Maurer,Michael John; Booster,Nicholas A; and Demott,Logan M
	UPDATE @ProjectPI 
	SET EmployeeID = t2.EmployeeID
	FROM @ProjectPI t1
	INNER JOIN
	(
		SELECT DISTINCT t1.OrgR ProjectOrgR, t3.Org PersonOrgR, t1.PI , t2.Name FullName, t2.EMP_ID EmployeeID 
		FROM @ProjectPI t1
		INNER JOIN PPSDataMart.[dbo].[UCP_PersonJob] t2 ON t2.Name LIKE t1.PI +''%''
		INNER  JOIN @HomeDepartments t3 ON t2.JOB_DEPT = t3.HomeDeptNum
		WHERE t1.EmployeeID IS NULL
		GROUP BY t1.OrgR, t3.Org, t1.PI , t2.Name, t2.Emp_ID having t2.Emp_ID IS NOT NULL
	) t2 ON t1.PI = t2.PI --AND t1.OrgR = t2.PersonOrgR
	WHERE t1.EmployeeID IS NULL

	--  Gives us HENGEL, MATT J,
	--	MURPHY, KATHERINE M,
	--  HENDRICK HOLT, ROBERTA R
	--  ROSS IBARRA, JEFFREY S:
	UPDATE @ProjectPI
	SET EmployeeID = t2.Employee_ID
	FROM @ProjectPI t1
	INNER JOIN (
		SELECT t1.PERSON_NAME, t2.PERSON_NM, t2.Employee_ID  
		FROM @ProjectPI ppi
		INNER JOIN UCD_PERSON t1 ON PERSON_NAME LIKE ppi.PI + ''%''
		INNER JOIN [dbo].[RICE_UC_KRIM_PERSON] t2 ON t2.PPS_ID = t1.EMPLOYEE_ID
		WHERE ppi.EmployeeID IS NULL AND t2.EMPLOYEE_ID IS NOT NULL
		--WHERE PERSON_NAME LIKE ''Holt,Roberta%''
	) t2 ON t2.PERSON_NAME LIKE t1.PI + ''%''
	WHERE t1.EmployeeID IS NULL

	-- This appears to be the last piece:
	-- Gives us Jeoh,Tina; and St.Clair,Dina
	UPDATE @ProjectPI 
	SET EmployeeID = t2.EmployeeID
	FROM  @ProjectPI  t1
	INNER JOIN (
		SELECT P.PI, A.EmployeeId 
		FROM @ProjectPI P
		INNER JOIN [AccountPI] A ON (A.Lastname like ''%'' + REPLACE(REPLACE(P.lastname,'''''''', ''%''), ''.'', ''%'') + ''%'' OR A.MiddleName LIKE P.lastname + ''%'') 
			AND A.FirstMiddle LIKE ''%''+ P.FirstInitial + ''%'' 
		WHERE P.EmployeeID IS NULL
			AND P.OrgR NOT LIKE ''AINT''
	) t2 ON t1.PI = t2.PI
	WHERE t1.EmployeeID IS NULL

	-- Gives us Oteiza,P: 
	UPDATE @ProjectPI 
	SET EmployeeID = t2. EmployeeID
	FROM  @ProjectPI  t1
	INNER JOIN (
	   SELECT DISTINCT P.PI, A.EmployeeId 
	   FROM @ProjectPI P
	   INNER JOIN AccountPI A ON (A.Lastname like REPLACE(REPLACE(P.lastname,'''''''', ''%''), ''.'', ''%'') + ''%'' OR A.MiddleName LIKE P.lastname + ''%'') 
			AND A.FirstMiddle LIKE ''%''+ P.FirstInitial + ''%'' 
	   WHERE P.EmployeeID IS NULL
			AND P.OrgR  LIKE ''AINT''
	) t2 ON t1.PI = t2.PI
	WHERE t1.EmployeeID IS NULL

	-- This portion matches hypenated PI names, which do not have a hypenated employee names 
	-- like Ontai-Grzebik, L.
	UPDATE @ProjectPI
	SET EmployeeID = t2.EmployeeID
	FROM @ProjectPI t1
	INNER JOIN (
		SELECT  DISTINCT PI, Person_Name, EMPLID EmployeeID, EMPLOYEE_ID PPS_ID
		FROM UCD_PERSON t1
		INNER JOIN @ProjectPI tpi ON 
			PERSON_LAST_NAME LIKE LEFT(LastName , CHARINDEX(''-'',LastName, 1)-1) + ''%''AND
		    PERSON_FIRST_NAME LIKE FirstName + ''%'' 
		INNER JOIN PS_UC_EXT_SYSTEM t2 ON t1.EMPLOYEE_ID = t2.PPS_ID
		WHERE
			tpi.EmployeeID IS NULL 
			AND (CHARINDEX(''-'',LastName, 1)-1) > 0
		) t2 ON t1.PI = t2.PI
	WHERE t1.EmployeeID IS NULL
'
	
	-- 20171026 by kjt: Revised to truncate and reload in stead of merge:
	-- Step 3: Truncate and Reload the ProjectPI table:

	SELECT @TSQL += '
	TRUNCATE TABLE [dbo].[ProjectPI]
	INSERT INTO [dbo].[ProjectPI] (OrgR, Inv1, PI, LastName, FirstName, FirstInitial, EmployeeID)
	SELECT DISTINCT
		OrgR,
		Inv1,
		PI,
		LastName,
		FirstName, 
		FirstInitial,
		EmployeeID
	FROM @ProjectPI
	ORDER BY OrgR, PI 
'

	PRINT @TSQL
	IF @IsDebug <> 1
	BEGIN
		EXEC(@TSQL)
	END
;
  
END