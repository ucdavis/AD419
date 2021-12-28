-- =============================================
-- Author:		Ken Taylor
-- Create date: August 10, 2017
-- Description:	Repopulate the ProjeectPI table.
-- Prerequisites:
--	AccounPI must have been loaded.
--	OrgXOrgR must have been loaded.
--	UCDPerson must have updated.
-- Usage:
/*

USE [AD419]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[usp_RepopulateProjectPI]
		@FiscalYear = 2016,
		@IsDebug = 0

--SELECT	'Return Value' = @return_value

GO

*/
-- Modifications:
--
-- =============================================
CREATE PROCEDURE usp_RepopulateProjectPI 
	-- Add the parameters for the stored procedure here
	@FiscalYear int = 2016, 
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @TSQL varchar(MAX) = ''

	SELECT @TSQL = '
	DECLARE @ProjectPI TABLE (OrgR varchar(4), Inv1 varchar(50), PI varchar(50), LastName varchar(50), FirstInitial char(1), EmployeeID varchar(10))

	-- Step 1a: Insert Project PIs:
	INSERT INTO @ProjectPI (OrgR, Inv1, PI)
	SELECT DISTINCT OrgR,Inv1, REPLACE(REPLACE(Inv1, ''  '' , '' ''), '', '', '','') PI
	FROM Project
	--(374 row(s) affected)

	-- Step 1b: Update FirstInitial and LastName:
	UPDATE @ProjectPI
	SET FirstInitial = SUBSTRING(PI, CHARINDEX('','', PI) + 1, 1),
	LastName = SUBSTRING(PI, 1, CHARINDEX('','', PI) - 1)
	--(374 row(s) affected)

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
	  ) t2 ON t2.PI_Name like PI + ''%'' 
	--(327 row(s) affected)

	UPDATE @ProjectPI
	SET EmployeeID = t2.EID
	FROM @ProjectPI t1
	INNER JOIN (
		SELECT distinct Employee_Name, EID, OrgR FROM Expenses 
		WHERE Employee_Name = PI_Name
	  ) t2 ON Employee_Name like PI + ''%'' 
	WHERE EmployeeID IS NULL
	--(11 row(s) affected)

	UPDATE @ProjectPI
	  SET EmployeeID = t2.EmployeeID
	  FROM @ProjectPI t1
	  INNER JOIN (
	  SELECT P.[OrgR]
		  ,P.[Inv1]
		  ,P.[PI]
		  ,P.[LastName]
		  ,P.[FirstInitial]
		  ,E.EmployeeId
	  FROM @ProjectPI P
	  LEFT OUTER JOIN [AccountPI] E ON P.PI = E.PI_Name
	  group by  P.[OrgR]
		  ,P.[Inv1]
		  ,P.[PI]
		  ,P.[LastName]
		  ,P.[FirstInitial]
		  ,E.EmployeeId
		  having E.EmployeeID IS NOT NULL
		  ) t2 ON t1.PI = t2.PI
		  WHERE t1.EmployeeID IS NOT NULL
	--(42 row(s) affected)

	UPDATE @ProjectPI 
	SET EmployeeID = t2.EmployeeID
	FROM @ProjectPI t1
	INNER JOIN
	(
		SELECT DISTINCT t1.OrgR ProjectOrgR, t3.OrgR PersonOrgR, t1.PI , t2.FullName, t2.EmployeeID 
		FROM @ProjectPI t1
		INNER JOIN PPSDataMart.[dbo].[APTDIS_V] t2 ON t2.FullName LIKE t1.PI +''%''
		INNER  JOIN OrgXOrgR t3 ON t2.OrgCode = t3.Org
		WHERE t1.EmployeeID IS NULL
		GROUP BY t1.OrgR, t3.OrgR, t1.PI , t2.FullName, t2.EmployeeID having t2.EmployeeID IS NOT NULL
	) t2 ON t1.PI = t2.PI AND t1.OrgR = t2.PersonOrgR
	WHERE t1.EmployeeID IS NULL
	--(23 row(s) affected)

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
	--(5 row(s) affected)

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
	--(2 row(s) affected)

	UPDATE @ProjectPI 
	SET EmployeeID = t2.EMPLOYEE_ID
	FROM @ProjectPI t1
	INNER JOIN UCD_PERSON t2 ON PERSON_NAME LIKE t1.PI + ''%''
	WHERE t1.EmployeeID IS NULL
	--(6 row(s) affected)

	-- Step 3: Merge the ProjectPI table:

	DECLARE @UpdateDate datetime2 = GETDATE()

	MERGE dbo.ProjectPI t1
	USING (
		SELECT DISTINCT
			OrgR,
			Inv1,
			PI,
			LastName,
			FirstInitial,
			EmployeeID
		FROM @ProjectPI
	) ProjectPI_Updates ON 
		t1.OrgR = ProjectPI_Updates.OrgR AND
		t1.EmployeeID = ProjectPI_Updates.EmployeeID AND
		t1.Inv1 = ProjectPI_Updates.Inv1 AND
		t1.PI = ProjectPI_Updates.PI AND
		t1.LastName = ProjectPI_Updates.LastName AND
		t1.FirstInitial = ProjectPI_Updates.FirstInitial

	WHEN MATCHED THEN UPDATE SET
		LastUpdateDate = CASE WHEN IsExistingRecord IS NULL OR IsExistingRecord = 0
			THEN @UpdateDate 
			ELSE LastUpdateDate
		END,
		IsExistingRecord = 1
	
	WHEN NOT MATCHED BY TARGET THEN INSERT VALUES
	(
		OrgR,
		Inv1,
		PI,
		LastName,
		FirstInitial,
		EmployeeID,
		0,
		@UpdateDate
	)
	--WHEN NOT MATCHED BY SOURCE THEN DELETE
;
'
	PRINT @TSQL
	IF @IsDebug <> 1
	BEGIN
		EXEC(@TSQL)
	END

  
END