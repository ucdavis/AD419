-- =============================================
-- Author:		Ken Taylor
-- Create date: August 10, 2017
-- Description:	Populate the AccountPI table based on PI_Names pulled from expenses
-- Prerequisites:
--	We must have loaded the PPS and FIS expenses into the intermediate tables prior to runing this script.
--	Field Station Expenses must have also been loaded*
--	CES expeses must have been loaded*
--
--	*This may only be true if we were going to need these employee's names as well; however, I do not believe it's
--	is necessary because all of those expenses will already have the appropriate accession numbers when provided.
-- Usage
/*

USE [AD419]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[usp_RepopulateAccountPI]
		@FiscalYear = 2016,
		@IsDebug = 1

GO

*/
-- Modifications:
-- 2017-08-10 by kjt: Revised to use actual Expenses table.
-- =============================================
CREATE PROCEDURE [dbo].[usp_RepopulateAccountPI] 
	@FiscalYear int = 2016, -- Not actually used as this is just a place holder for API uniformity.
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	DECLARE @TSQL varchar(MAX) = ''

	SELECT @TSQL = '
	DECLARE @AccountPI TABLE (PI_Name varchar(100), LastName varchar(50), FirstMiddle varchar(50), FirstName varchar(25), MiddleName varchar(25), EmployeeID varchar(10))

	-- Populate table with data found in the current expenses:

	INSERT INTO @AccountPI(PI_Name, EmployeeID)
	SELECT DISTINCT 
		PI_NAME, 
		CASE WHEN Employee_Name LIKE PI_Name 
			THEN EID 
			ELSE NULL 
		END AS EmployeeID
	FROM [dbo].[Expenses] 
	WHERE PI_NAME IS NOT NULL
	ORDER BY 1

	-- Update all of the other name fields potentially used for matching:

	UPDATE @AccountPI
	SET LastName = SUBSTRING(PI_NAME, 1, CHARINDEX('','',PI_NAME)-1),
		FirstMiddle = SUBSTRING(PI_NAME, CHARINDEX('','',PI_NAME)+1, LEN(PI_NAME)-CHARINDEX('','',PI_NAME)) 

	UPDATE @AccountPI
	SET FirstName = t2.FirstName, MiddleName = t2.MiddleName
	FROM @AccountPI t1
	INNER JOIN PPSDataMart.dbo.Persons t2 ON t1.PI_Name = t2.FullName
	WHERE FullName IN (
		SELECT DISTINCT PI_NAME FROM @AccountPI
	)

	UPDATE @AccountPI
	SET FirstName = t2.FirstName
	FROM @AccountPI t1
	INNER JOIN (
		SELECT 
			CASE WHEN CHARINDEX('' '', FirstMiddle) > 0 
				THEN 
					SUBSTRING(FirstMiddle, 1, CHARINDEX('' '', FirstMiddle) -1)
				ELSE FirstMiddle 
			END AS FirstName,
			PI_Name
		FROM  @AccountPI
		) t2 ON t1.PI_Name = t2.PI_Name
	WHERE t1.FirstName IS NULL 

	UPDATE @AccountPI
	SET MiddleName = t2.MiddleName
	FROM @AccountPI t1
	INNER JOIN (
		SELECT 
			CASE WHEN CHARINDEX('' '', FirstMiddle) > 0 
				THEN SUBSTRING(FirstMiddle, CHARINDEX('' '', FirstMiddle) +1, LEN(FirstMiddle) - CHARINDEX('' '', FirstMiddle) +1) 
			END AS MiddleName,
			PI_Name
		FROM  @AccountPI
		WHERE MiddleName IS NULL AND  CHARINDEX('' '', FirstMiddle) > 0
		) t2 ON t1.PI_Name = t2.PI_Name
	WHERE t1.MiddleName IS NULL AND  CHARINDEX('' '', FirstMiddle) > 0

	-----------------------------------------------------------------------------------
	-- Matching process begins:
	
	-- 1. Try setting employee ID from our PPS Person''s table using a full name match:
	UPDATE @AccountPI
	SET EmployeeId = t2.EmployeeID
	FROM @AccountPI t1
	INNER JOIN (
		SELECT FullName, MAX(EmployeeID) EmployeeID
		FROM PPSDataMart.dbo.Persons
		WHERE FullName IN (
			SELECT DISTINCT PI_NAME FROM @AccountPI
		)
		GROUP BY FullName
	) t2 ON t1.PI_NAME = t2.FullName
	WHERE t1.EmployeeID IS NULL
	--(463 row(s) affected)

	-- 2. Try setting employee ID using AptDis_V on a partial name match AND OrgR match:

	UPDATE @AccountPI
	SET EmployeeId = t2.EmployeeID
	FROM @AccountPI t1
	INNER JOIN (
			SELECT DISTINCT FullName, t1.EmployeeID, PI_Name, t2.OrgR ExpenseOrgR, t3.OrgR OrgXOrgR
			FROM
			(
			   SELECT DISTINCt OrgR, UPPER(REPLACE(REPLACE(PI_NAME, '', '', '',''), '', '', '','')) PI_Name  
			   FROM Expenses 
			   WHERE 
					UPPER(REPLACE(REPLACE(PI_NAME, '', '', '',''), '', '', '','')) IN
					(
						SELECT PI_Name
						FROM @AccountPI 
						WHERE EmployeeID IS NULL
					)
		   ) t2 
		   LEFT OUTER JOIN PPSDataMart.dbo.AptDis_V  t1 ON t1.FullName LIKE PI_Name +''%''
		   LEFT OUTER JOIN OrgXOrgR t3 ON OrgCode = Org
		   GROUP BY FullName, t1.EmployeeID, PI_Name, t2.OrgR, t3.OrgR HAVING t2.OrgR = t3.OrgR
		  ) t2 ON t1.PI_Name = t2.PI_NAME WHERE t1.EmployeeID IS NULL
		--(17 row(s) affected)

	  -- 3. Try setting employee ID from AptDis_V FullName on a patrial name match without orgR match: 

	  UPDATE @AccountPI
	  SET EmployeeID = t2.EmployeeID
	  FROM @AccountPI t1
	  INNER JOIN
	  (
			SELECT DISTINCT t1.PI_Name, t2.EmployeeID
			FROM @AccountPI t1
			INNER JOIN (
				SELECT DISTINCT UPPER(REPLACE(REPLACE(PI_NAME, '', '', '',''), '', '', '','')) PI_Name, OrgR
				FROM Expenses
			) t3 ON t1.PI_Name = t3.PI_Name
			LEFT OUTER JOIN PPSDataMart.dbo.AptDis_V t2 ON t2.FullName LIKE t1.PI_Name + ''%''
			LEFT OUTER JOIN OrgXOrgR t4 ON t3.OrgR = t4.OrgR
			WHERE t1.EmployeeID IS NULL 
			GROUP BY t1.PI_Name, t2.EmployeeID  HAVING t2.EmployeeID IS NOT  NULL
		 ) t2 ON t1.PI_Name = t2.PI_Name 
		 WHERE t1.EmployeeID IS NULL
	--(1 row(s) affected)

	-- 4. Try setting employee ID from our PPS Person''s table using a partial name match:

	UPDATE @AccountPI
	SET EmployeeID =  t2.EmployeeID
	FROM @AccountPI t1
	INNER JOIN 
	(
		SELECT DISTINCT FullName, MAX(EmployeeID) EmployeeID
		FROM PPSDataMart.dbo.Persons 
		GROUP BY FullName
	) t2 ON t2.FullName LIKE t1.PI_Name +''%''
	WHERE t1.EmployeeID IS NULL
	--(1 row(s) affected)

	-- 5. Try setting employee ID from UCD PERSON''s table using a partial name match:

	UPDATE @AccountPI
	SET EmployeeID =  t2.EMPLOYEE_ID
	FROM @AccountPI t1
	INNER JOIN UCD_PERSON t2 ON t2.PERSON_NAME LIKE t1.PI_Name +''%''
	WHERE t1.EmployeeID IS NULL
	--(6 row(s) affected)

	-----------------------------------------------------------------------------------
	-- Merge AccountPI:
	
	DECLARE @UpdateDate datetime2 = GETDATE()

	MERGE dbo.AccountPI t1
	USING (
		SELECT DISTINCT
			PI_Name,
			LastName,
			FirstMiddle,
			FirstName,
			MiddleName,
			EmployeeID
		FROM @AccountPI
	) AccountPI_Updates ON 
		t1.EmployeeID = AccountPI_Updates.EmployeeID AND 
		t1.PI_Name = AccountPI_Updates.PI_Name AND
		t1.LastName = AccountPI_Updates.LastName AND
		t1.FirstMiddle = AccountPI_Updates.FirstMiddle 
	WHEN MATCHED THEN UPDATE SET 
		LastUpdateDate = CASE WHEN IsExistingRecord IS NULL OR IsExistingRecord = 0
			THEN @UpdateDate 
			ELSE LastUpdateDate
		END,
		IsExistingRecord = 1
	WHEN NOT MATCHED BY TARGET THEN INSERT VALUES
	(
		PI_Name,
		LastName,
		FirstMiddle,
		FirstName,
		MiddleName,
		EmployeeID,
		0,
		@UpdateDate
	)
	--WHEN NOT MATCHED BY SOURCE THEN DELETE
;

	-- Make sure that all of the Account PIs have been matched:
	SELECT * FROM AccountPI WHERE EmployeeID IS NULL
	-- (0 row(s) affected)

'
	PRINT @TSQL
	IF @IsDebug <> 1
	BEGIN
		EXEC(@TSQL)
		SET NOCOUNT OFF;
	END
    
END