
-- =============================================
-- Author:		Ken Taylor
-- Create date: August 9, 2017
-- Description:	Locate 241 Expenses and Auto-Associate.
-- This procedure uses the new Combined241EmployeesV2 view as it's data source
-- for determining the PI's, their projects and their corresponding OrgRs.
-- Prerequisites:
--	ProjXOrgR must be loaded
--	Expenses must be loaded
--	ProjectPi must be loaded 
--	PI_OrgR_Accession must be loaded
--	TitleCodesSelfCertify must be loaded if we're going to consider
--		title codes which may conditionally be a 241 if the employee is
--		also listed as an account PI in the expenses table and the FTE_SFN 
--		for their title code is not listed as 241.
-- Usage:
/*

USE [AD419]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[usp_InsertAssociationsFor241Expenses]
		@FiscalYear = 2016, -- Note: Fiscal Year is just used as a place holder.
		@IsDebug = 1

-- SELECT	'Return Value' = @return_value

GO

*/
/*
-- EXEC this SQL to delete the associations for testing, and reset the expenses' IsAssociated 
-- and IsAssociable flags:

DELETE FROM Associations
	WHERE ExpenseID IN (
		SELECT T1.ExpenseID
		FROM Expenses t1
		INNER JOIN PPSDataMart.DBO.Titles t2 ON t1.TitleCd = t2.TitleCode 
		INNER JOIN staff_type t3 ON t2.StaffType = t3.Staff_Type_Code AND AD419_Line_Num = '241'
		WHERE DataSource = 'PPS' AND t1.OrgR NOT IN (SELECT OrgR FROM udf_GetOrgRExclusions())

		UNION

		SELECT T1.ExpenseID
		FROM Expenses t1
		INNER JOIN PPSDataMart.DBO.Titles t2 ON t1.TitleCd = t2.TitleCode 
		INNER JOIN staff_type t3 ON t2.StaffType = t3.Staff_Type_Code AND AD419_Line_Num = '242'
		INNER JOIN ProjectPI t4 ON t1.EID = t4.EmployeeID
		WHERE DataSource = 'PPS' AND t1.OrgR NOT IN (SELECT OrgR FROM udf_GetOrgRExclusions())
	)

    UPDATE Expenses
	SET FTE_SFN = '241', IsAssociated = 0, IsAssociable = 1 
	FROM Expenses t1
	INNER JOIN (
		SELECT t1.OrgR, t1.Expenses, t1.FTE, t1.EID, T1.ExpenseID, isAssociated, t1.Employee_Name
		FROM Expenses t1
		INNER JOIN PPSDataMart.DBO.Titles t2 ON t1.TitleCd = t2.TitleCode 
		INNER JOIN staff_type t3 ON t2.StaffType = t3.Staff_Type_Code AND AD419_Line_Num = '241'
		WHERE DataSource = 'PPS' AND t1.OrgR NOT IN (SELECT OrgR FROM udf_GetOrgRExclusions())

		UNION

		SELECT t1.OrgR, t1.Expenses, t1.FTE, t1.EID, T1.ExpenseID, IsAssociated, t1.Employee_Name
		FROM Expenses t1
		INNER JOIN PPSDataMart.DBO.Titles t2 ON t1.TitleCd = t2.TitleCode 
		INNER JOIN staff_type t3 ON t2.StaffType = t3.Staff_Type_Code AND AD419_Line_Num = '242'
		INNER JOIN ProjectPI t4 ON t1.EID = t4.EmployeeID
		WHERE DataSource = 'PPS' AND t1.OrgR NOT IN (SELECT OrgR FROM udf_GetOrgRExclusions())
	) t2 ON t1.ExpenseID = t2.ExpenseID

-- Row count after restoring from backup:
--(11472 row(s) affected)
--(1051 row(s) affected)

-- Row count after running new logic:
--(15805 row(s) affected)
--(1051 row(s) affected)

*/

/*
-- EXEC this to restore the Expenses and Associations back to what they were
-- prior to testing:

DELETE FROM AllExpenses
DELETE FROM Associations
SET IDENTITY_INSERT AllExpenses ON
INSERT INTO AllExpenses([ExpenseID]
      ,[DataSource]
      ,[OrgR]
      ,[Chart]
      ,[Account]
      ,[SubAcct]
      ,[PI_Name]
      ,[Org]
      ,[EID]
      ,[Employee_Name]
      ,[TitleCd]
      ,[Title_Code_Name]
      ,[Exp_SFN]
      ,[Expenses]
      ,[FTE_SFN]
      ,[FTE]
      ,[isAssociated]
      ,[isAssociable]
      ,[isNonEmpExp]
      ,[Sub_Exp_SFN]
      ,[Staff_Grp_Cd])
SELECT * FROM AllExpenses_20170711_backup
SET IDENTITY_INSERT AllExpenses OFF

INSERT INTO Associations
SELECT * FROM Associations_20170711_backup

--(1070 row(s) affected)
*/
-- Modifications:
--	2017-08-14 by kjt: Added prerequsites.
--	2017-09-21 by kjt: Revised to use new 241 expenses view.
--	2021-12-20 by kjt: Commented out the auto-association of PIs whom
--		do not have projects as per Shannon.
--
-- =============================================
CREATE PROCEDURE [dbo].[usp_InsertAssociationsFor241Expenses] 
	@FiscalYear int = 2016, -- Note: Fiscal Year is just used as a place holder to maintain API uniformity.
	@IsDebug bit = 0
AS
BEGIN
	DECLARE @TSQL varchar(MAX) = ''

	-----------------------------------------------------------------------------------------------
	-- Handle the 241 expenses that must be prorated across all of a PI's projects:
	--
	SELECT @TSQL = '
SET NOCOUNT ON
BEGIN
	DECLARE @AssociationsTable TABLE (ExpenseID int, OrgR varchar(4), Accession varchar(50), Expenses float, FTE float, isProrated bit)
 
	INSERT INTO @AssociationsTable
	-- This gives us a list of project expenses that are both inside and outside of the PI''s home department:
	SELECT
		ExpenseID,
		E.OrgR AS OrgR,  
		Accession, 
		CAST(Expenses/NumProjects AS float) AS Expenses, 
		CAST(FTE/NumProjects AS float) AS FTE,
		IsProrated
	FROM dbo.TwoFortyOneExpensesV E
	INNER JOIN (
	  SELECT 
		t1.OrgR, 
		t1.EID, 
		t1.Accession, 
		COALESCE(NumProjects,0) AS NumProjects, 
		IsProrated
	  FROM Combined241EmployeesV2  T1
	  LEFT OUTER JOIN (
		SELECT  
			OrgR, 
			EID, 
			Count(*) AS NumProjects
		FROM Combined241EmployeesV2
		WHERE Accession IS NOT NULL
		GROUP BY OrgR, EID
		) T2 ON t1.OrgR = t2.OrgR AND T1.EID = t2.EID
	) PIA ON E.EID = PIA.EID AND NumProjects > 0
	WHERE E.OrgR NOT IN (
			SELECT OrgR
			FROM dbo.udf_GetOrgRExclusions()
		) AND IsAssociated = 0 
	-- This condition only gets the expenses where the Expense''s OrgR matches the project''s OrgR
		AND PIA.OrgR = E.OrgR
	GROUP BY E.OrgR, E.EID, Accession, NumProjects, ExpenseID, Expenses, FTE, IsProrated
	ORDER BY ExpenseID, OrgR, Accession, NumProjects, Expenses, FTE

	-- Associate the Project expenses for PIs inside or outside of their home departments:

	INSERT INTO Associations (ExpenseID, OrgR, Accession, Expenses, FTE)
	SELECT ExpenseID, OrgR, Accession, Expenses, FTE FROM @AssociationsTable

	UPDATE Expenses
	SET isAssociated = 1, 
		IsAssociable = CASE WHEN IsProrated = 1 THEN 0 ELSE 1 END
	FROM Expenses t1 
	INNER JOIN (
		SELECT DISTINCT ExpenseId, IsProrated
		FROM @AssociationsTable
		GROUP BY ExpenseID, OrgR, IsProrated
	) t2 ON t1.ExpenseID = t2.ExpenseID

	-- These are the expenses that were prorated outside of the PI''s home department
	-- that we set the IsAssociable flag to 0:
	SELECT ''Expenses outside of the PI''''s Home Department:'' AS Title
	SELECT * FROM Expenses 
	WHERE DataSource = ''PPS'' AND
		OrgR NOT IN (
			SELECT OrgR
			FROM dbo.udf_GetOrgRExclusions()
		) AND 
		IsAssociable = 0 AND 
		IsAssociated = 1 AND
		EID IN (
			SELECT DISTINCT EID
			FROM Combined241EmployeesV2
		)

	-- These are the expenses that were in the PI''s home department(s):
	SELECT ''Expenses inside the PI''''s Home Department:'' AS Title
	SELECT * 
	FROM Expenses 
	WHERE DataSource = ''PPS'' AND
		 OrgR NOT IN (
			SELECT OrgR
			FROM dbo.udf_GetOrgRExclusions()
		) AND 
		 IsAssociable = 1 AND 
		 IsAssociated = 1 AND
		 EID IN (
			SELECT DISTINCT EID
			FROM Combined241EmployeesV2
		)

	-- These are the associations made for the expenses that were outside of the PI''s home department
	-- where we set the IsAssociable flag to 0:

	SELECT ''Associations made for expenses outside the PI''''s Home Department:'' AS Title
	SELECT * FROM Associations
	WHERE ExpenseID IN (
		SELECT DISTINCT ExpenseID 
		FROM Expenses 
		WHERE DataSource = ''PPS'' AND
			OrgR NOT IN (
				SELECT OrgR
				FROM dbo.udf_GetOrgRExclusions()
			) AND 
			IsAssociable = 0 AND 
			IsAssociated = 1 AND
			EID IN (
				SELECT DISTINCT EID
				FROM Combined241EmployeesV2
			)
	)
'
	IF @IsDebug != 1
	BEGIN
		SELECT @TSQL += '
END
'
	END

	PRINT @TSQL
	IF @IsDebug != 1
	BEGIN
		EXEC (@TSQL)
	END

-- 2021-12-20 by kjt Commented out as per Shannon Tanguay as she wants to perform this portion
--	manually using the Unassociated241EmployeeExpenses report.
--	-----------------------------------------------------------------------------------------------
--	-- Handle the 241 expenses that must be prorated across all of a department's projects:
--	--
--	SELECT @TSQL = ''

--	IF @IsDebug != 1
--	BEGIN
--		SELECT @TSQL = '
--SET NOCOUNT ON
--BEGIN'
--	END

--	SELECT @TSQL += '
--	-- This should give us the list of all the expenses for ''241'' employees the do not have projects,
--	-- and the expenses will need to be prorated across all of the department''s projects:
--'
--	IF @IsDebug != 1
--	BEGIN
--		SELECT @TSQL += '
--	DECLARE @AssociationsTable TABLE (ExpenseID int, OrgR varchar(4), Accession varchar(50), Expenses float, FTE float, isProrated bit)
--'
--	END
--	ELSE
--	BEGIN
--		SELECT @TSQL += '
--	DELETE @AssociationsTable
--'
--	END

--	SELECT @TSQL += '
--	INSERT INTO @AssociationsTable (ExpenseID, OrgR, Accession, Expenses, FTE)
--	SELECT DISTINCT
--		ExpenseID, 
--		E.OrgR AS OrgR,
--		t3.Accession,
--		CAST(Expenses/NumProjects AS float) AS Expenses, 
--		CAST(FTE/NumProjects AS float) AS FTE
--	FROM dbo.TwoFortyOneExpensesV E
--	INNER JOIN (
--	  SELECT t1.OrgR, t1.EID, t1.Accession, IsProrated
--	  FROM Combined241EmployeesV2 T1 
--	) PIA ON E.EID = PIA.EID AND Accession IS NULL
--	INNER JOIN (
--		SELECT O.OrgR, O.Accession, NumProjects
--		FROM Project P
--		INNER JOIN ProjXOrgR O ON P.OrgR = O.OrgR 
--		INNER JOIN (
--			SELECT O.OrgR, COUNT(*) NumProjects FROM ProjXOrgR O
--			INNER JOIN project P ON O.Accession = P.Accession
--			GROUP BY O.OrgR
--		) C ON O.OrgR = C.OrgR	
--		GROUP BY O.OrgR, O.Accession, NumProjects
--	) t3 ON E.OrgR = t3.OrgR
--	WHERE E.OrgR NOT IN (
--			SELECT OrgR
--			FROM dbo.udf_GetOrgRExclusions()
--		) AND IsAssociated = 0 
--	GROUP BY E.OrgR, t3.Accession, ExpenseID, Expenses, FTE, NumProjects
--	ORDER BY ExpenseID, E.OrgR, t3.Accession, Expenses, FTE

--	-- Associate the expenses for ''241'' employees that do not have active projects
--	-- by prorating the expenses across all of the departments projects:

--	INSERT INTO Associations (ExpenseID, OrgR, Accession, Expenses, FTE)
--	SELECT ExpenseID, OrgR, Accession, Expenses, FTE 
--	FROM @AssociationsTable

--	UPDATE Expenses
--	SET IsAssociated = 1
--	WHERE ExpenseID IN (
--		SELECT DISTINCT ExpenseID
--		FROM @AssociationsTable 
--	)

--	-- Lastly, this is a sanity check for any expenses that are were not prorated, 
--	-- as there should be zero:
--	SELECT ''Non-Admin PPS Expenses that still need to be Associated:'' AS Title
--	SELECT * 
--	FROM Expenses
--	WHERE IsAssociated = 0 AND
--		DataSource = ''PPS'' AND 
--		OrgR NOT IN (
--			SELECT OrgR
--			FROM dbo.udf_GetOrgRExclusions()
--		)
--END
--SET NOCOUNT OFF
--'
--	PRINT @TSQL
--	IF @IsDebug != 1
--		EXEC (@TSQL)
END