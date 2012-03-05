------------------------------------------------------------------------
/*
PROGRAM: udf_GetSFNAssociatedExpenses
BY:	Mike Ransom
--USAGE:	
	select * from udf_GetSFNAssociatedExpenses('AANS')
	--or
	select * from udf_GetSFNAssociatedExpenses('ALL')

DESCRIPTION: 

See notes for UDF udf_GetSFNTotalExpenses. This function is similar except that it returns AD419 line number subtotals for Associated expenses.


CURRENT STATUS:
[10/11/06] Wed
	Working properly. Returns 34 rows in 4 seconds for all departments (from AgDean16), < 1 for AANS. (This includes 7 queries against about 120,000 Associations rows.)

	* Modified query to make the primary query a sub-query in the FROM clause that the SFN_Display table can be outer joined to. This was the simplest/best way to get rows returned for SFNs with no expenses.
	* Scott said there would be problems handling rows with expense totals of null. Added ISNULL() function to present as 0s.

NOTES: 
	Returns 34 rows in 4 seconds for all departments (from AgDean16), < 1 for AANS. (This includes 7 queries against about 120,000 Associations rows.)
CALLED BY:
CLIENTS/RELATED FILES/DEPENDENCIES:
TODO LIST:

MODIFICATIONS: see bottom
*/
-------------------------------------------------------------------------
create FUNCTION [dbo].[udf_GetSFNAssociatedExpenses] (@OrgR VARCHAR(4) = 'ALL')
	--NOTE: UDFs are odd in that parameters are NOT optional. Must use keyword DEFAULT when calling to get default value.
RETURNS @SFNTotals TABLE
	(
	GroupDisplayOrder tinyint, 
	LineDisplayOrder tinyint,
	LineTypeCode varchar(20),
	LineDisplayDescriptor varchar(48),
	SFN char(3),
	Total float
	)	
AS
BEGIN
-------------------------------------------------------------------------
DECLARE @OrgCt INT

IF ISNULL(@OrgR,'ALL') = 'ALL'
	SET @OrgR = '%'
ELSE
	BEGIN
	SET @OrgCt = (SELECT COUNT(OrgR) FROM ReportingOrg WHERE OrgR = @OrgR AND isActive<>0)
	IF @OrgCt <> 1
		RETURN
	END

--------------------------------------------------
INSERT INTO @SFNTotals 
	(
	D.GroupDisplayOrder, 
	D.LineDisplayOrder, 
	LineTypeCode, 
	LineDisplayDescriptor, 
	SFN,
	Total
	)
--------------------------------------------------
/*	Code to use during testing & devel. Delete when done.
declare @OrgR char(4)
set @OrgR = 'AANS'
*/
SELECT 
	/* Columns from SFN_Display */
	D.GroupDisplayOrder, 
	D.LineDisplayOrder,
	D.LineTypeCode,
	D.LineDisplayDescriptor,
	D.SFN,
	CASE LineTypeCode
		WHEN 'Heading' THEN null
		ELSE ISNULL(Totals.Total,0)
	END Total	/* (from large UNION sub-query below) */
FROM
	SFN_Display D LEFT OUTER JOIN 
	/* Columns from large block of UNIONed queries returning expense and FTE SUMs */
	(
	--------------------------------------------------
	/* SFN SUBTOTALS */
	SELECT 
		D.SFN,
		SUM(A.Expenses) Total
	FROM
		SFN_Display D JOIN Expenses E ON
			 D.SFN = E.Exp_SFN
		JOIN Associations A ON
			E.ExpenseID = A.ExpenseID
	WHERE E.OrgR like @OrgR
	GROUP BY
		D.SFN,
		D.LineTypeCode
	--------------------------------------------------
	UNION /* NON-FEDERAL EMPLOYED STAFF SUPPORT (FTE) */
	SELECT 
		D.SFN,
		SUM(A.FTE) Total
	FROM
		SFN_Display D JOIN Expenses E ON
			 D.SFN = E.FTE_SFN
		JOIN Associations A ON
			E.ExpenseID = A.ExpenseID
	WHERE	 
		SFN NOT LIKE '   '
		AND E.OrgR like @OrgR
	GROUP BY
		D.SFN,
		D.LineTypeCode
	--------------------------------------------------
	UNION /* CSREES FUNDS GROUP SUBTOTAL */
	SELECT 
		D.SFN,
		(
			SELECT SUM(A.Expenses) Total
			FROM  Expenses E
				JOIN SFN_Display D ON 
					D.SFN = E.Exp_SFN
			JOIN Associations A ON
				E.ExpenseID = A.ExpenseID
			WHERE 
				D.SumToLine = '231'
				AND E.OrgR like @OrgR
			GROUP BY SumToLine
		) Total
	FROM
		SFN_Display D 
		WHERE D.SFN = '231'
	--------------------------------------------------
	UNION /* Total Other Federal Research Funds  */
	SELECT 
		D.SFN,
		(
			SELECT SUM(A.Expenses) Total
			FROM  Expenses E
				JOIN SFN_Display D ON 
					D.SFN = E.Exp_SFN
			JOIN Associations A ON
				E.ExpenseID = A.ExpenseID
			WHERE 
				D.SumToLine = '332'
				AND E.OrgR like @OrgR
			GROUP BY SumToLine
		) Total
	FROM
		SFN_Display D 
		WHERE D.SFN = '332'
	--------------------------------------------------
	UNION /* Total Non-Federal Research Funds */
	SELECT 
		D.SFN,
		(
			SELECT SUM(A.Expenses) Total
			FROM  Expenses E
				JOIN SFN_Display D ON 
					D.SFN = E.Exp_SFN
			JOIN Associations A ON
				E.ExpenseID = A.ExpenseID
			WHERE 
				D.SumToLine = '233'
				AND E.OrgR like @OrgR
			GROUP BY SumToLine
		) Total
	FROM
		SFN_Display D 
		WHERE D.SFN = '233'
	--------------------------------------------------
	UNION /* TOTAL ALL RESEARCH FUNDS */
	SELECT 
		D.SFN,
		(
			SELECT SUM(A.Expenses) Total
			FROM  Expenses E
				JOIN Associations A ON
					E.ExpenseID = A.ExpenseID
			WHERE E.OrgR like @OrgR
			--GROUP BY SumToLine
		) Total
	FROM
		SFN_Display D 
		WHERE D.SFN = '234'
	--------------------------------------------------
	UNION /* TOTAL SUPPORT YEARS */
	SELECT 
		D.SFN,
		(
			SELECT SUM(A.FTE) Total
			FROM  Expenses E
				JOIN Associations A ON
					E.ExpenseID = A.ExpenseID
			WHERE 
				E.FTE_SFN IS NOT NULL
				AND E.OrgR like @OrgR
		) Total
	FROM
		SFN_Display D 
	WHERE 
		D.SFN = '350'
	--------------------------------------------------
	UNION /* HEADING ROWS */
	SELECT 
		D.SFN,
		NULL Total
	FROM
		SFN_Display D 
	WHERE D.LineDisplayOrder = '0'
	--------------------------------------------------
	) Totals ON
		D.SFN = Totals.SFN
ORDER BY
	D.GroupDisplayOrder, 
	D.LineDisplayOrder


RETURN
END
/*
-------------------------------------------------------------------------
MODIFICATIONS:
[10/11/06] Wed
	Working properly. Returns 34 rows in 4 seconds for all departments (from AgDean16), < 1 for AANS. (This includes 7 queries against about 120,000 Associations rows.)

	* Modified query to make the primary query a sub-query in the FROM clause that the SFN_Display table can be outer joined to. This was the simplest/best way to get rows returned for SFNs with no expenses.
	* Scott said there would be problems handling rows with expense totals of null. Added ISNULL() function to present as 0s.
	* Had to do latter as CASE statement, due to not wanting 0s for Heading rows.

[10/10/06] Tue
	Starting. Based on udf_GetSFNTotalExpenses. Will modify one unioned query at a time, converting to be based on Associations table.



--------------------------------------------------

--USAGE:	
	SELECT * FROM udf_GetSFNAssociatedExpenses('AANS')
	--or
	SELECT * FROM udf_GetSFNAssociatedExpenses('ALL')

*/
