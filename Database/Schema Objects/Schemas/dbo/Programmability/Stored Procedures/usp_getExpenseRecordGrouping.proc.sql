------------------------------------------------------------------------
/*
PROGRAM: usp_getExpenseRecordGrouping
BY:	Scott Kirkland, Mike Ransom
USAGE:	
	Called by ASP.NET code in AD419 application

DESCRIPTION:
	[10/27/06]: Added Grouping 'None' to the bottom of the IF-ELSE
	-- Create date: 10/11/2006
	-- Description:	Returns the Expense record grouping for whatever grouping you pass in.
	-- Possible Values: Organization, Sub-Account, PI, Account, Employee

CURRENT STATUS:
NOTES:
CALLED BY:
	Called by ASP.NET code in AD419 application in Expense Associations page, for grid on left side.
CLIENTS/RELATED FILES/DEPENDENCIES:
TODO LIST:
MODIFICATIONS: see bottom
***************************/
------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[usp_getExpenseRecordGrouping] 
	-- Add the parameters for the stored procedure here
	@Grouping varchar(50),
	@OrgR char(4),
	@Associated bit,
	@Unassociated bit,
	@IsDebug bit = 0

AS
BEGIN
SET NOCOUNT ON
-----------------------------------------
/* parameter values for development: (comment out or delete later)
DECLARE @Grouping varchar(50)
DECLARE @OrgR char(4)
DECLARE @Associated bit
DECLARE @Unassociated bit
SET @Grouping = 'Organization'
SET @OrgR = 'AANS'
SET @Associated = 1
SET @Unassociated = 1
***************************/
-----------------------------------------

DECLARE @Both bit
	SET @Both = @Associated & @Unassociated

DECLARE @txtSQL varchar(2000)

-- If statements for which grouping to select
----------------------------------
-- Gather by PI Name:
IF @Grouping = 'PI'
	BEGIN
	SET @txtSQL =
	'
	SELECT 
		Chart,
		PI_Name AS Code, /*[10/19/06] MLR: We dont have a normalized table of PIs (comes from Accounts). Should probably do next year.*/
		PI_Name AS Description, 
		SUM(Expenses) AS Spent, 
		SUM(FTE) AS FTE, 
		COUNT(Expenses) AS Num, 
		isAssociated
	FROM Expenses AS E 
	WHERE E.isAssociable<>0 AND E.OrgR = ''' + @OrgR + '''
	'
	+ CASE
		WHEN @Both = 1 THEN
			''
		WHEN @Associated = 1 THEN
			' AND isAssociated <> 0 '
		WHEN @Unassociated = 1 THEN
			' AND isAssociated = 0 '
	END
	+
	'
	GROUP BY PI_Name, Chart, isAssociated
	ORDER BY PI_Name, Chart
	'
	END
----------------------------------
-- Gather by Org:
ELSE IF @Grouping = 'Organization'
	BEGIN
	SET @txtSQL =
	'
	SELECT
		E.Chart,
		O.Org AS Code,
		O.Name AS Description,
		E.isAssociated,
		SUM(Expenses) AS Spent,
		SUM(FTE) AS FTE,
		COUNT(Expenses) AS Num
	FROM Expenses AS E 
		LEFT OUTER JOIN FISDataMart.dbo.Organizations AS O ON 
			E.Org = O.Org
			AND E.Chart=O.Chart
			AND O.Year = 9999
			AND O.Period = ''--''
	WHERE E.isAssociable<>0 AND E.OrgR = ''' + @OrgR + '''
	'
	+ CASE
		WHEN @Both = 1 THEN
			''
		WHEN @Associated = 1 THEN
			' AND isAssociated <> 0 '
		WHEN @Unassociated = 1 THEN
			' AND isAssociated = 0 '
	END
	+
	'
	GROUP BY O.Org, E.Chart, O.Name, E.isAssociated, O.Name
	ORDER BY O.Org, E.Chart
	'
	END
----------------------------------
-- Gather by Employee:
ELSE IF @Grouping = 'Employee'
	BEGIN
	SET @txtSQL =
	'
	SELECT 
		E.Chart,
		E.EID AS Code, 
		RTRIM(E.Employee_Name) + '' ('' + ISNULL(S.AD419_Line_Num,''---'') + '')'' AS Description, 
		SUM(E.Expenses) AS Spent, 
		SUM(E.FTE) AS FTE, 
		COUNT(E.Expenses) AS Num, 
		E.isAssociated
	FROM Expenses AS E 
		LEFT OUTER JOIN staff_type AS S ON 
			E.Staff_Grp_Cd = S.Staff_Type_Short_Name
	WHERE 
		E.isAssociable<>0 
		AND E.OrgR = ''' + @OrgR + '''
	'
	+ CASE
		WHEN @Both = 1 THEN
			''
		WHEN @Associated = 1 THEN
			' AND isAssociated <> 0 '
		WHEN @Unassociated = 1 THEN
			' AND isAssociated = 0 '
	END
	+
	'
	GROUP BY E.Employee_Name, E.Chart, E.EID, S.AD419_Line_Num, E.isAssociated
	ORDER BY S.AD419_Line_Num, E.Employee_Name, E.Chart
	'
	END
----------------------------------
-- Gather by Account:
ELSE IF @Grouping = 'Account'
	BEGIN
	SET @txtSQL =
	'
	SELECT 
		E.Chart,
		E.Account AS Code, 
		A.AccountName AS Description, 
		SUM(E.Expenses) AS Spent, 
		SUM(E.FTE) AS FTE, 
		COUNT(E.Expenses) AS Num, 
		E.isAssociated
	FROM Expenses AS E LEFT OUTER JOIN
		FISDataMart.dbo.Accounts AS A ON 
			E.Account = A.Account
			AND E.Chart = A.Chart
			AND A.Year = 9999 AND A.Period = ''--''
	WHERE E.isAssociable<>0 AND E.OrgR = ''' + @OrgR + '''
	'
	+ CASE
		WHEN @Both = 1 THEN
			''
		WHEN @Associated = 1 THEN
			' AND isAssociated <> 0 '
		WHEN @Unassociated = 1 THEN
			' AND isAssociated = 0 '
	END
	+
	'
	GROUP BY E.Account, E.Chart, A.AccountName, E.isAssociated
	ORDER BY E.Account, E.Chart
	'
	END
----------------------------------
-- Gather by Sub-Account:
ELSE IF @Grouping = 'Sub-Account'
	BEGIN
	SET @txtSQL =
	'
	SELECT
		E.Chart,
		E.SubAcct AS Code, 
		MIN(DISTINCT SA.SubAccountName) AS Description, 
		SUM(E.Expenses) AS Spent, 
		SUM(E.FTE) AS FTE, 
		COUNT(E.Expenses) AS Num, 
		E.isAssociated
	FROM Expenses AS E 
		LEFT OUTER JOIN FISDataMart.dbo.SubAccounts AS SA ON 
			E.Account = SA.Account 
			AND E.SubAcct = SA.SubAccount
			AND E.Chart = SA.Chart
			AND SA.Year = 9999 AND SA.Period = ''--''
	WHERE E.isAssociable<>0 AND E.OrgR = ''' + @OrgR + '''
	'
	+ CASE
		WHEN @Both = 1 THEN
			''
		WHEN @Associated = 1 THEN
			' AND isAssociated <> 0 '
		WHEN @Unassociated = 1 THEN
			' AND isAssociated = 0 '
	END
	+
	'
	GROUP BY E.Chart, E.SubAcct, E.isAssociated
	ORDER BY E.SubAcct, E.Chart
	'
	END
ELSE IF @Grouping = 'None'
	BEGIN
	SET @txtSQL =
	'
	SELECT
		E.Chart,
		E.ExpenseID AS Code, 
		E.Account + '' ['' + ISNULL(E.SubAcct,''----'') + '']: '' + ISNULL(E.Employee_Name,''----'') + '' ('' + ISNULL(E.Title_Code_Name,''----'') + '')'' AS Description, 
		SUM(E.Expenses) AS Spent, 
		SUM(E.FTE) AS FTE, 
		COUNT(E.Expenses) AS Num, 
		E.isAssociated
	FROM Expenses AS E
	WHERE E.isAssociable<>0 AND E.OrgR = ''' + @OrgR + '''
	'
	+ CASE
		WHEN @Both = 1 THEN
			''
		WHEN @Associated = 1 THEN
			' AND isAssociated <> 0 '
		WHEN @Unassociated = 1 THEN
			' AND isAssociated = 0 '
	END
	+
	'
	GROUP BY E.Chart, E.ExpenseID, E.Account, E.SubAcct, E.Employee_Name, E.Title_Code_Name, E.isAssociated
	ORDER BY E.Account, E.SubAcct, E.Employee_Name, E.Title_Code_Name, E.Chart
	'
	END
ELSE
	RETURN -1
/* *************************
*/
----------------------------------
--Execute the query:
IF @IsDebug = 1
	PRINT @txtSQL
ELSE
	EXEC (@txtSQL)

END	--sproc
/****************************

-------------------------------------------------------------------------
MODIFICATIONS:

[10/18/06] Wed MLR:
	Recoded to avoid repeating blocks of code that could potentially get out of sync.
	Sample of older code:
ELSE IF @Grouping = 'Employee'
	BEGIN
		IF @Both = 1
		BEGIN
			SELECT     E.Employee_Name AS Code, S.AD419_Line_Num AS Description, SUM(E.Expenses) AS Spent, SUM(E.FTE) AS FTE, COUNT(E.Expenses) 
							  AS Num, E.isAssociated
			FROM         Expenses AS E INNER JOIN
								  staff_type AS S ON E.Staff_Grp_Cd = S.Staff_Type_Short_Name
			WHERE     (E.OrgR = @OrgR) AND (E.Employee_Name <> '')
			GROUP BY E.Employee_Name, S.AD419_Line_Num, E.isAssociated
			ORDER BY E.Employee_Name
		END
		ELSE IF @Associated = 1
		BEGIN
			SELECT     E.Employee_Name AS Code, S.AD419_Line_Num AS Description, SUM(E.Expenses) AS Spent, SUM(E.FTE) AS FTE, COUNT(E.Expenses) 
							  AS Num, E.isAssociated
			FROM         Expenses AS E INNER JOIN
								  staff_type AS S ON E.Staff_Grp_Cd = S.Staff_Type_Short_Name
			WHERE     (E.OrgR = @OrgR) AND (E.isAssociated = 1) AND (E.Employee_Name <> '')
			GROUP BY E.Employee_Name, S.AD419_Line_Num, E.isAssociated
			ORDER BY E.Employee_Name
		END
		ELSE IF @Unassociated = 1
		BEGIN
			SELECT     E.Employee_Name AS Code, S.AD419_Line_Num AS Description, SUM(E.Expenses) AS Spent, SUM(E.FTE) AS FTE, COUNT(E.Expenses) 
							  AS Num, E.isAssociated
			FROM         Expenses AS E INNER JOIN
								  staff_type AS S ON E.Staff_Grp_Cd = S.Staff_Type_Short_Name
			WHERE     (E.OrgR = @OrgR) AND (E.isAssociated = 0) AND (E.Employee_Name <> '')
			GROUP BY E.Employee_Name, S.AD419_Line_Num, E.isAssociated
			ORDER BY E.Employee_Name
		END
	END

[10/19/06] Thu
	There have been quite a few changes now.
	* Added Chart to both the query and returned output--it was required to uniquely identify grouping expenses and get right sum for the grouping.
	* Edited all output to not convert nulls to anything "friendlier"--leave that to the presentation layer
		* --with the exception of AD419_Line_Num, which is concatenated with Employee_Name
	* Changed the output column names to Code and Description (rather than Grouping, Grouping2)

[10/24/06] Tue
	Getting wrong number with PI grouping.
		* Query for PI contained join to sub-accounts table, which was not needed and inappropriate.
-------------------------------------------------------------------------
--UNIT TESTING:
EXEC usp_getExpenseRecordGrouping 'PI', 'AANS', 1, 1
EXEC usp_getExpenseRecordGrouping 'Organization', 'AANS', 1, 1
EXEC usp_getExpenseRecordGrouping 'Account', 'AANS', 1, 1
EXEC usp_getExpenseRecordGrouping 'Sub-Account', 'AANS', 1, 1
EXEC usp_getExpenseRecordGrouping 'Employee', 'AANS', 1, 1

EXEC usp_getExpenseRecordGrouping 'Organization', 'AANS', 0, 1
EXEC usp_getExpenseRecordGrouping 'Sub-Account', 'AANS', 1, 0
EXEC usp_getExpenseRecordGrouping 'None', 'AANS', 1, 0

*/
