------------------------------------------------------------------------
/*
PROGRAM: usp_GetExpensesBySFN
BY:	Mike Ransom, Scott Kirkland
--USAGE:	
	EXEC usp_GetExpensesBySFN [<OrgR>] [, <Accession] [, <intAssociationStatus>]
	--e.g.
	EXEC usp_GetExpensesBySFN 'AANS'
	EXEC usp_GetExpensesBySFN 'AANS', NULL, 1
	EXEC usp_GetExpensesBySFN 'AANS', NULL, 3
	EXEC usp_GetExpensesBySFN 'ALL', NULL, 3
	EXEC usp_GetExpensesBySFN 'ALL', '0080277', 4

DESCRIPTION: 


CURRENT STATUS:
[10/26/06] SRK:
		Changed udf_GetSFNTotalExpenses and udf_GetSFNAssociatedExpenses into temp tables so everything is in one SPROC.
		Added parameter @Accession, which defaults to null.  When intAssociationStatus = 4, that means
	that we are adding up the totals for a specific project, not the whole department.  Haven't yet implemented
	the project totals.

[10/5/06] Thu Working properly
	Converted to get data from a UDF. This will be easier for other sprocs to use this data, for instance when joins with other data are required, such as the associated expenses.
	Will probably want to create a more generic sproc that can return either Associate, Unassociated, or Total expenses.

NOTES:
CALLED BY:
CLIENTS/RELATED FILES/DEPENDENCIES:
TODO LIST:
	Need to add a AD419Valid flag field to Departments table to filter out old depts not in use.

MODIFICATIONS: see bottom
*/
-------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[usp_GetExpensesBySFN]
	@OrgR VARCHAR(4) = NULL,
	@Accession varchar(50) = NULL,
	@intAssociationStatus INT = NULL
AS
BEGIN
-------------------------------------------------------------------------
/* Sample parameter values for devel:
declare @OrgR char(4), @intAssociationStatus int
set @OrgR = 'APLS'
set @intAssociationStatus = 1
*/
-------------------------------------------------------------------------
--Set OrgR from parameter and check validity
DECLARE @OrgCt INT
DECLARE @Return INT

IF ISNULL(@OrgR,'ALL') = 'ALL'
	SET @OrgR = '%'
ELSE
	BEGIN
	SET @OrgCt = (SELECT COUNT(OrgR) FROM ReportingOrg WHERE OrgR = @OrgR AND IsActive <> 0)
	IF @OrgCt <> 1	
		BEGIN		
		SET @RETURN = -1
		RETURN
		END
	END

-------------------------------------------------------------------------------
------------ BEGIN SFNTotalExpenses and SFNAssociated Expenses tables ---------

DECLARE @TotalExpenses TABLE
	(
	GroupDisplayOrder tinyint, 
	LineDisplayOrder tinyint,
	LineTypeCode varchar(20),
	LineDisplayDescriptor varchar(48),
	SFN char(3),
	Total float
	)	

DECLARE @AssociatedExpenses TABLE
	(
	GroupDisplayOrder tinyint, 
	LineDisplayOrder tinyint,
	LineTypeCode varchar(20),
	LineDisplayDescriptor varchar(48),
	SFN char(3),
	Total float
	)	

IF @intAssociationStatus <> 4
BEGIN

INSERT INTO @TotalExpenses 
	(
	D.GroupDisplayOrder, 
	D.LineDisplayOrder, 
	LineTypeCode, 
	LineDisplayDescriptor, 
	SFN,
	Total
	)

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

-------------------------------------------------------------------------

INSERT INTO @AssociatedExpenses 
	(
	D.GroupDisplayOrder, 
	D.LineDisplayOrder, 
	LineTypeCode, 
	LineDisplayDescriptor, 
	SFN,
	Total
	)
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
		E.OrgR like @OrgR AND E.isAssociated = 1
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
		AND E.isAssociated = 1
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
				AND E.isAssociated = 1
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
				AND E.isAssociated = 1
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
				AND E.isAssociated = 1
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
			AND E.isAssociated = 1
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
				AND E.isAssociated = 1
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
----------------------------------------------------------
ELSE IF @intAssociationStatus = 4
BEGIN

INSERT INTO @TotalExpenses 
	(
	D.GroupDisplayOrder, 
	D.LineDisplayOrder, 
	LineTypeCode, 
	LineDisplayDescriptor, 
	SFN,
	Total
	)
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
	SELECT     D.SFN, SUM(A.Expenses) AS Total
	FROM         SFN_Display AS D INNER JOIN
						  Expenses AS E ON D.SFN = E.Exp_SFN INNER JOIN
						  Associations AS A ON E.ExpenseID = A.ExpenseID
	WHERE     (E.OrgR LIKE @OrgR) 
			AND (A.Accession = @Accession)
	GROUP BY D.SFN
	--------------------------------------------------
	UNION /* NON-FEDERAL EMPLOYED STAFF SUPPORT (FTE) */
	SELECT     D.SFN, SUM(A.FTE) AS Total
	FROM         SFN_Display AS D INNER JOIN
						  Expenses AS E ON D.SFN = E.FTE_SFN INNER JOIN
						  Associations AS A ON E.ExpenseID = A.ExpenseID
	WHERE   (D.SFN NOT LIKE '   ') 
			AND (E.OrgR LIKE @OrgR) 
			AND (A.Accession = @Accession)
	GROUP BY D.GroupDisplayOrder, 
			D.LineDisplayOrder, 
			D.LineDisplayDescriptor, 
			D.SFN, 
			D.LineTypeCode
	--------------------------------------------------
	UNION /* CSREES FUNDS GROUP SUBTOTAL */
	SELECT 
		D.SFN,
		(
			SELECT     SUM(A.Expenses) AS Total
			FROM         Expenses AS E INNER JOIN
								  SFN_Display AS D ON D.SFN = E.Exp_SFN INNER JOIN
								  Associations AS A ON E.ExpenseID = A.ExpenseID
			WHERE     (D.SumToLine = '231') 
					AND (E.OrgR LIKE @OrgR) 
					AND (A.Accession = @Accession)
			GROUP BY D.SumToLine
		) Total
	FROM
		SFN_Display D 
		WHERE D.SFN = '231'
	--------------------------------------------------
	UNION /* Total Other Federal Research Funds  */
	SELECT 
		D.SFN,
		(
			SELECT     SUM(A.Expenses) AS Total
			FROM         Expenses AS E INNER JOIN
								  SFN_Display AS D ON D.SFN = E.Exp_SFN INNER JOIN
								  Associations AS A ON E.ExpenseID = A.ExpenseID
			WHERE     (D.SumToLine = '332') 
					AND (E.OrgR LIKE @OrgR) 
					AND (A.Accession = @Accession)
			GROUP BY D.SumToLine
		) Total
	FROM
		SFN_Display D 
		WHERE D.SFN = '332'
	--------------------------------------------------
	UNION /* Total Non-Federal Research Funds */
	SELECT 
		D.SFN,
		(
			SELECT     SUM(A.Expenses) AS Total
			FROM         Expenses AS E INNER JOIN
								  SFN_Display AS D ON D.SFN = E.Exp_SFN INNER JOIN
								  Associations AS A ON E.ExpenseID = A.ExpenseID
			WHERE     (D.SumToLine = '233') 
					AND (E.OrgR LIKE @OrgR) 
					AND (A.Accession = @Accession)
			GROUP BY D.SumToLine
		) Total
	FROM
		SFN_Display D 
		WHERE D.SFN = '233'
	--------------------------------------------------
	UNION /* TOTAL ALL RESEARCH FUNDS */
	SELECT 
		D.SFN,
		(
			SELECT     SUM(A.Expenses) AS Total
			FROM         Expenses AS E INNER JOIN
								  Associations AS A ON E.ExpenseID = A.ExpenseID
			WHERE     (E.OrgR LIKE @OrgR) 
					AND (A.Accession = @Accession)
		) Total
	FROM
		SFN_Display D 
		WHERE D.SFN = '234'
	--------------------------------------------------
	UNION /* TOTAL SUPPORT YEARS */
	SELECT 
		D.SFN,
		(
			SELECT     SUM(A.FTE) AS Total
			FROM         Expenses AS E INNER JOIN
								  Associations AS A ON E.ExpenseID = A.ExpenseID
			WHERE     (E.FTE_SFN IS NOT NULL) 
					AND (E.OrgR LIKE @OrgR) 
					AND (A.Accession = @Accession)
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

---------------------------------------
INSERT INTO @AssociatedExpenses 
	(
	D.GroupDisplayOrder, 
	D.LineDisplayOrder, 
	LineTypeCode, 
	LineDisplayDescriptor, 
	SFN,
	Total
	)
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
	SELECT     D.SFN, SUM(A.Expenses) AS Total
	FROM         SFN_Display AS D INNER JOIN
						  Expenses AS E ON D.SFN = E.Exp_SFN INNER JOIN
						  Associations AS A ON E.ExpenseID = A.ExpenseID
	WHERE     (E.OrgR LIKE @OrgR) 
			AND (E.isAssociated = 1) 
			AND (A.Accession = @Accession)
	GROUP BY D.SFN
	--------------------------------------------------
	UNION /* NON-FEDERAL EMPLOYED STAFF SUPPORT (FTE) */
	SELECT     D.SFN, SUM(A.FTE) AS Total
	FROM         SFN_Display AS D INNER JOIN
						  Expenses AS E ON D.SFN = E.FTE_SFN INNER JOIN
						  Associations AS A ON E.ExpenseID = A.ExpenseID
	WHERE   (D.SFN NOT LIKE '   ') 
			AND (E.OrgR LIKE @OrgR) 
			AND (E.isAssociated = 1) 
			AND (A.Accession = @Accession)
	GROUP BY D.GroupDisplayOrder, 
			D.LineDisplayOrder, 
			D.LineDisplayDescriptor, 
			D.SFN, 
			D.LineTypeCode
	--------------------------------------------------
	UNION /* CSREES FUNDS GROUP SUBTOTAL */
	SELECT 
		D.SFN,
		(
			SELECT     SUM(A.Expenses) AS Total
			FROM         Expenses AS E INNER JOIN
								  SFN_Display AS D ON D.SFN = E.Exp_SFN INNER JOIN
								  Associations AS A ON E.ExpenseID = A.ExpenseID
			WHERE     (D.SumToLine = '231') 
					AND (E.OrgR LIKE @OrgR) 
					AND (E.isAssociated = 1) 
					AND (A.Accession = @Accession)
			GROUP BY D.SumToLine
		) Total
	FROM
		SFN_Display D 
		WHERE D.SFN = '231'
	--------------------------------------------------
	UNION /* Total Other Federal Research Funds  */
	SELECT 
		D.SFN,
		(
			SELECT     SUM(A.Expenses) AS Total
			FROM         Expenses AS E INNER JOIN
								  SFN_Display AS D ON D.SFN = E.Exp_SFN INNER JOIN
								  Associations AS A ON E.ExpenseID = A.ExpenseID
			WHERE     (D.SumToLine = '332') 
					AND (E.OrgR LIKE @OrgR) 
					AND (E.isAssociated = 1) 
					AND (A.Accession = @Accession)
			GROUP BY D.SumToLine
		) Total
	FROM
		SFN_Display D 
		WHERE D.SFN = '332'
	--------------------------------------------------
	UNION /* Total Non-Federal Research Funds */
	SELECT 
		D.SFN,
		(
			SELECT     SUM(A.Expenses) AS Total
			FROM         Expenses AS E INNER JOIN
								  SFN_Display AS D ON D.SFN = E.Exp_SFN INNER JOIN
								  Associations AS A ON E.ExpenseID = A.ExpenseID
			WHERE     (D.SumToLine = '233') 
					AND (E.OrgR LIKE @OrgR) 
					AND (E.isAssociated = 1) 
					AND (A.Accession = @Accession)
			GROUP BY D.SumToLine
		) Total
	FROM
		SFN_Display D 
		WHERE D.SFN = '233'
	--------------------------------------------------
	UNION /* TOTAL ALL RESEARCH FUNDS */
	SELECT 
		D.SFN,
		(
			SELECT     SUM(A.Expenses) AS Total
			FROM         Expenses AS E INNER JOIN
								  Associations AS A ON E.ExpenseID = A.ExpenseID
			WHERE     (E.OrgR LIKE @OrgR) 
					AND (E.isAssociated = 1) 
					AND (A.Accession = @Accession)
		) Total
	FROM
		SFN_Display D 
		WHERE D.SFN = '234'
	--------------------------------------------------
	UNION /* TOTAL SUPPORT YEARS */
	SELECT 
		D.SFN,
		(
			SELECT     SUM(A.FTE) AS Total
			FROM         Expenses AS E INNER JOIN
								  Associations AS A ON E.ExpenseID = A.ExpenseID
			WHERE     (E.FTE_SFN IS NOT NULL) 
					AND (E.OrgR LIKE @OrgR) 
					AND (E.isAssociated = 1) 
					AND (A.Accession = @Accession)
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
----------------------------------- End Tables --------------------------------

--------------------------------------------------
--Get "SFN" subtotals, group subtotals, and heading lines:
if @intAssociationStatus = 1 /* Total Expenses */
	SELECT * FROM @TotalExpenses
	ORDER BY
		GroupDisplayOrder, 
		LineDisplayOrder
else if @intAssociationStatus = 2 /* Associated Expenses */
	SELECT * FROM @AssociatedExpenses
	ORDER BY
		GroupDisplayOrder, 
		LineDisplayOrder
else if @intAssociationStatus = 3 /* Unassociated Expenses */
	BEGIN
	SELECT 
		/* Columns from SFN_Display */
		D.GroupDisplayOrder, 
		D.LineDisplayOrder,
		D.LineTypeCode,
		D.LineDisplayDescriptor,
		D.SFN,
		(T.Total - A.Total) Total
	FROM
		SFN_Display D LEFT JOIN 
			(
			SELECT * 
			FROM @TotalExpenses
			) T
			ON D.SFN = T.SFN
		LEFT JOIN 
			(
			SELECT * 
			FROM @AssociatedExpenses
			) A
			ON D.SFN = A.SFN
	ORDER BY
		D.GroupDisplayOrder, 
		D.LineDisplayOrder
	END
--else if @intAssociationStatus = 4 /* Project Expenses */
ELSE	/* Default to showing all 3 columns side by side. */
	BEGIN
	SELECT 
		/* Columns from SFN_Display */
		D.GroupDisplayOrder, 
		D.LineDisplayOrder,
		D.LineTypeCode,
		D.LineDisplayDescriptor,
		D.SFN,
		T.Total Total,
		A.Total Associated,
		(T.Total - A.Total) Unassociated
	FROM
		SFN_Display D LEFT JOIN 
			(
			SELECT * 
			FROM @TotalExpenses
			) T
			ON D.SFN = T.SFN
		LEFT JOIN 
			(
			SELECT * 
			FROM @AssociatedExpenses
			) A
			ON D.SFN = A.SFN
	ORDER BY
		D.GroupDisplayOrder, 
		D.LineDisplayOrder
	END
END

/*
-------------------------------------------------------------------------
MODIFICATIONS:
[9/27/06] Wed
	Begun.

[10/4/06] Wed
	Was getting result row with 49.something FTE but no other data due to blank value in Expenses.FTE_SFN.
	This is a problem with the FoxPro data set from last year that shouldn't have occurred.
	We need to guard both against this occurring, and against presenting any blank rows if they do exist.
	Preventing the row from output is done with the following line in the FTE section:
	SFN NOT LIKE '   '

[10/5/06] Thu
	Converted to get data from a UDF. This will be easier for other sprocs to use this data, for instance when joins with other data are required, such as the associated expenses.

[10/12/06] Thu
	* Added IF...ELSE branching to present Total, Associated, Unassociated, or (default) all three
	* Added a AD419Valid flag field to ReportingOrg table to filter out old depts not in use. (Changed from Departments to ReportingOrg also)

--------------------------------------------------

--USAGE:	
	EXEC usp_GetExpensesBySFN 'AANS'
	EXEC usp_GetExpensesBySFN 'AANS', 1
	EXEC usp_GetExpensesBySFN 'AANS', 3
	EXEC usp_GetExpensesBySFN 'ALL', 3

*/
