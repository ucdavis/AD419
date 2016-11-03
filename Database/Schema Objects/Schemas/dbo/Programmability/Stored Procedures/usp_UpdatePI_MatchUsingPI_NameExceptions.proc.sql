-- =============================================
-- Author:		Ken Taylor
-- Create date: November 26, 2014
-- Description:	Update PI_Match table's lastname, middle initial.  
-- Then try to make matches using those values and PI_Name_Exceptions table
-- for any 241 employees whose PI_Match has yet to be populated.
-- Usage:
/*
	EXEC  [dbo].[usp_UpdatePI_MatchUsingPI_NameExceptions] @IsDebug = 1
*/
-- 20151102 by kjt: Added new logic to handle additional cleanup and name standardization.
-- 20160324 by kjt: Added new logic to update the few remaining non-matches.
-- 20160815 by kjt: Added yet a few more matching statements.
-- =============================================
CREATE PROCEDURE [dbo].[usp_UpdatePI_MatchUsingPI_NameExceptions] 
	@IsDebug bit = 0 -- Set to 1 to print SQL created by procedure only.
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @TSQL varchar(MAX) = ''

	SELECT @TSQL = '
	-- Replace double spaces with a single space
	UPDATE  [AD419].[dbo].[PI_Match]
	SET PI = REPLACE(PI, ''  '', '' '')

	-- Set the Last name and First initial for the PI Match entries as we''ll use these for matching:
	--UPDATE [dbo].PI_MATCH
	--SET [LastName] = SUBSTRING(PI, 1, CHARINDEX('', '' ,PI,1 ) -1 ), 
	--[FirstInitial] = SUBSTRING(PI, CHARINDEX('', '' ,PI,1 ) + 2, 1 ),
	--[FirstName] = SUBSTRING(PI, CHARINDEX('', '' ,PI,1 ) + 2, CHARINDEX('' '', PI, 1))
	--WHERE LastName IS NULL

	-- Update blank first initials with any present in the last name column
	--UPDATE [AD419].[dbo].[PI_Match]
	--SET FirstInitial = FirstName
	--WHERE FirstINitial IS NULL OR FirstInitial = '' '' OR FirstInitial = ''''

	 --update PI_NAME_EXCEPTIONS
	 --SET FirstName = t1.FIRSTNAME
	 --FROM (
	 --SELECT DISTINCT t1.FirstName, T2.PI, t1.OrgR FROM PI_MATCH t1 
	 --INNER JOIN PI_NAME_EXCEPTIONS t2 ON T1.LastName = t2.LastName and t1.FirstInitial = t2.FIrstInitial
	 --) t1
	 --WHERE t1.PI = PI_NAME_EXCEPTIONS.PI AND t1.OrgR = PI_NAME_EXCEPTIONS.OrgR
	'

	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)


	SELECT @TSQL = '
	-- Try making matches using various combinations of names and PI_Name_Exceptions table.
	UPDATE PI_Match
	SET PI_Match = t1.PI_Match, EID = t1.EID, IsProrated = 0 
	FROM
	 (
		SELECT DISTINCT
			t1.OrgR, t1.Accession, 
			t1.[PI], 
			CASE WHEN t2.PI IS NULL THEN t3.ModifiedPIName ELSE t2.PI END PI_Match, 
			CASE WHEN t2.EID IS NULL THEN t3.EID ELSE t2.EID END AS EID
	  FROM [AD419].[dbo].[PI_Match] t1
	  LEFT OUTER JOIN [dbo].[PI_Name_Exceptions] t3 ON t1.OrgR = t3.OrgR AND t1.PI_Match IS NULL AND
			((t1.PI = t3.ModifiedPIName) OR(t1.PI = (t3.FirstPortionOfLastName + '', '' + t3.FirstInitial))
			  OR (t1.PI = (t3.LastName + '', '' + t3.FirstName))
			)
	  LEFT OUTER JOIN [dbo].[PI_Names] t2 ON t1.OrgR = t2.OrgR 
			AND ((t3.LastName + '', '' + t3.FirstInitial) = t2.PI OR 
				 (REPLACE(t1.PI, '''''''', '''') = t2.PI)
	  )
	  where PI_Match is NULL AND (IsProrated IS NULL OR IsProrated = 0)
	  ) t1
	  INNER JOIN PI_Match t2 ON t1.Accession = t2.Accession
	  WHERE t1.PI_Match IS NOT NULL
	  '

	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)


	SELECT @TSQL = ' 
	-- This will update PI Match using the missing middle initials:
	UPDATE PI_Match
	SET EID = t2.EID, PI_Match = t2.PI, IsProrated = 0 
	FROM PI_Match t1
	INNER JOIN 
	PI_name_exceptions t2 ON t1.PI = t2.ModifiedPiName2
	WHERE t1.EID IS NULL AND (IsProrated IS NULL OR IsProrated = 0)
	'
	-- Handled all but OMAHONY, M A, because project PI is missing last initial, but PPS name has middle initial.

	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)

	SELECT @TSQL = '
	-- Update any EID using last name, first initial combinations with matching PI Names:
	UPDATE PI_Match
	SET EID = t2.EID, PI_Match = t2.PI, IsProrated = 0 
	FROM
	PI_Match t1
	INNER JOIN (
		SELECT REPLACE(t1.PI,'''''''','''') PI, t3.OrgR, Accession, t2.LastName, t2.FirstInitial, EmployeeName, t3.EID 
		FROM PI_Match t1
		INNER JOIN 
		(
			SELECT 
				t1.LastName, SUBSTRING(t1.FirstName, 1, 1) FirstInitial 
			FROM PPSDataMart.dbo.Persons t1
			INNER JOIN (
				SELECT DISTINCT LastName, FirstInitial 
				FROM (
					select PI, REPLACE(SUBSTRING(PI,1, CHARINDEX('','',PI,1) -1),'''''''','''') LastName, SUBSTRING(PI, CHARINDEX('','', PI, 1) + 2, 1 ) FirstInitial 
					from PI_Match 
					where EID is NUll AND (IsProrated IS NULL OR IsProrated = 0)
				) t1
			) t2 ON REPLACE(t1.LastName, '''''''', '''') = t2.LastName AND SUBSTRING(t1.FirstName, 1, 1) = t2.FirstInitial
			GROUP BY t1.LastName, SUBSTRING(t1.FirstName, 1, 1) having count(*) = 1
		) t2 ON REPLACE(t1.PI, '''''''','''') = t2.LastName + '', '' + t2.FirstInitial
		INNER JOIN PI_name_exceptions t3 ON t2.FirstInitial = t3.FirstInitial AND t2.LastName = t3.LastName
	) t2 ON REPLACE(t1.PI,'''''''','''') = t2.PI
'

	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)

	-- Next we want to handle ant matches that we couldn't match otherwise but can still automate:
SELECT @TSQL = '
	--Update PI_Match for PIs such as KAPLAN,KENNETH B, and SUBBARAO, KRISHNA
	UPDATE PI_Match 
	SET EID = t2.EID, PI_Match = t2.PI, IsProrated = 0 
	FROM PI_Match t1
	INNER JOIN PI_NAME_Exceptions t2 ON t1.PI = LEFT(t2.LastName + '', '' + t2.FirstName, LEN(t1.PI)) 
	AND t1.OrgR = t2.OrgR
	WHERE t1.PI_Match IS NULL AND (IsProrated IS NULL OR IsProrated = 0)
'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)


SELECT @TSQL = '
	-- Update PI_Match for PIs such as VAN DEYNZE,ALLEN, and VAN EENENNAAM,ALISON, and ST CLAIR,DINA ANN
	UPDATE PI_Match
	SET EID = t2.EID, PI_Match = t2.PI, IsProrated = 0 
	FROM PI_Match t1
	INNER JOIN PI_NAME_Exceptions t2 ON t1.PI = REPLACE(t2.LastName, '' '','''') + '', '' + t2.firstName
	AND t1.OrgR = t2.OrgR
	WHERE t1.PI_Match IS NULL AND (IsProrated IS NULL OR IsProrated = 0)
'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)


SELECT @TSQL = '
	-- Update PI_Match for PIs such as MCROBERTS,DOUGLAS NEIL
	UPDATE PI_Match
	SET EID = t2.EID, PI_Match = t2.PI, IsProrated = 0 
	FROM PI_Match t1
	INNER JOIN PI_NAME_Exceptions t2 ON t1.PI = t2.LastName + '', '' + SUBSTRING(t2.FirstMiddle, CHARINDEX('' '', t2.FirstMiddle)+1,LEN(t2.FirstMiddle) - CHARINDEX('' '', t2.FirstMiddle))
	AND t1.OrgR = t2.OrgR
	WHERE t1.PI_Match IS NULL AND (IsProrated IS NULL OR IsProrated = 0)
'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)


SELECT @TSQL = '
	-- Lastly, update any IsProrated flags to 0 where a match has been made previously, but not set:
	UPDATE PI_Match
	SET IsProrated = 0 
	WHERE PI_Match IS NOT NULL AND IsProrated IS NULL
'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)

SELECT @TSQL = '
	-- Print out any 241 employees that are still unmatched:
	  SELECT ''Non-Matched 241 Employees:'' TableName
	  SELECT * FROM PI_Match
	  WHERE PI_Match IS NULL AND (IsProrated IS NULL OR IsProrated = 0)
	  ORDER BY PI, OrgR, Accession
'

	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)
    
	SET NOCOUNT OFF;
END