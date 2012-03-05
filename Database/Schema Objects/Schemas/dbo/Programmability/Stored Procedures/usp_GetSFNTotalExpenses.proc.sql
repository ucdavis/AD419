------------------------------------------------------------------------
/*
PROGRAM: usp_GetSFNTotalExpenses
BY:	Mike Ransom
--USAGE:	
	EXEC usp_GetSFNTotalExpenses @OrgR = 'AANS'
	--or
	EXEC usp_GetSFNTotalExpenses @OrgR = 'ALL'

DESCRIPTION: 

The consuming data grid will also be used to display subtotals for associated or unassociated expenses.  Note that "total" expenses comes from the Expenses table and that "associated" expenses will need to come from the Associations table; the unassociated, I believe, will have to be the difference, and require both of the previous queries to calculate.

This query links to the Expenses table via the SFN_Display table in order to pick up display info for the presentation layer. It doesn't specify anything about the presentation except the display order.  Some rows contain headings for SFN groups, others the subtotals for SFN groups, and each SFN group has a heading line. The SFN_Display table does contain a row type attribute for the presentation layer to discover what row type it is, e.g. "Heading", "SFN", "GroupSum", and "GrandTotal."

Has a parameter @OrgR to use as a filter of Expenses.OrgR so expenses for just one reporting org are returned. Setting to 'ALL' switches result to sum of all departments.

Has an error trap for invalid OrgR code--does a lookup of OrgR codes from Departments table. Returns -1 in @Return if not found.

CURRENT STATUS:
[10/5/06] Thu
	Converting to a UDF.
	13:17 Success.

NOTES:
CALLED BY:
CLIENTS/RELATED FILES/DEPENDENCIES:
TODO LIST:

MODIFICATIONS: see bottom
*/
-------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[usp_GetSFNTotalExpenses]
(
	@OrgR VARCHAR(4) = 'ALL'
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
		SUM(E.Expenses) Total
	FROM
		SFN_Display D JOIN Expenses E ON
			 D.SFN = E.Exp_SFN
	WHERE 
		E.OrgR like @OrgR
	GROUP BY
		D.SFN
	--------------------------------------------------
	UNION /* NON-FEDERAL EMPLOYED STAFF SUPPORT (FTE) */
	SELECT 
		D.SFN,
		SUM(E.FTE) Total
	FROM
		SFN_Display D JOIN Expenses E ON
			 D.SFN = E.FTE_SFN
	WHERE	 
		SFN NOT LIKE '   '
		AND E.OrgR like @OrgR
	GROUP BY
		D.GroupDisplayOrder, 
		D.LineDisplayOrder,
		D.LineDisplayDescriptor,
		D.SFN,
		D.LineTypeCode
	--------------------------------------------------
	UNION /* CSREES FUNDS GROUP SUBTOTAL */
	SELECT 
		D.SFN,
		(
			SELECT SUM(E.Expenses) Total
			FROM  Expenses E
				JOIN SFN_Display D ON 
					D.SFN = E.Exp_SFN
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
			SELECT SUM(E.Expenses) Total
			FROM  Expenses E
				JOIN SFN_Display D ON 
					D.SFN = E.Exp_SFN
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
			SELECT SUM(E.Expenses) Total
			FROM  Expenses E
				JOIN SFN_Display D ON 
					D.SFN = E.Exp_SFN
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
			SELECT SUM(E.Expenses) Total
			FROM  Expenses E
			WHERE E.OrgR like @OrgR
		) Total
	FROM
		SFN_Display D 
		WHERE D.SFN = '234'
	--------------------------------------------------
	UNION /* TOTAL SUPPORT YEARS */
	SELECT 
		D.SFN,
		(
			SELECT SUM(E.FTE) Total
			FROM  Expenses E
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
END
/*
-------------------------------------------------------------------------
MODIFICATIONS:

[9/29/06] Fri
	Functional without parameters limiting reporting org.  Returns results from 2004-5 Expenses table (14,000) records in <1 second, which is really impressive, since it sums each expense record 3 times--once in SFN subtotal, 2nd in SFN Group subtotal, and 3rd in Grand total. (Actually 4th and 5th because of FTE subtotals and grand total.

[10/2/06] Mon
	Added parameter for Reporting Org (OrgR).
	Added condition testing for OrgR = 'ALL' to return sum of expenses for all departments (used 'ALL' due to DataOps not handling nulls).
	Added error trap for invalid OrgR code--does a lookup of OrgR codes from Departments table. Returns -1 in @Return if not found.
	In SFN_Display table, changed LineTypeCode to "FTE" and "FTETotal" so consumer can distinguish and not present in currency format.

[10/4/06] Wed
	Was getting result row with 49.something FTE but no other data due to blank value in Expenses.FTE_SFN.
	This is a problem with the FoxPro data set from last year that shouldn't have occurred.
	We need to guard both against this occurring, and against presenting any blank rows if they do exist.
	Preventing the row from output is done with the following line in the FTE section:
	SFN NOT LIKE '   '

[10/5/06] Thu
	Add a AD419Valid flag field to Departments table to filter out old depts not in use.

--------------------------------------------------

--USAGE:	
	EXEC usp_GetSFNTotalExpenses @OrgR = 'AANS'
	--or
	EXEC usp_GetSFNTotalExpenses @OrgR = 'ALL'

*/
