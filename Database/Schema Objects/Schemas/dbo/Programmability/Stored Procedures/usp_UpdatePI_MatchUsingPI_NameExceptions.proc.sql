-- =============================================
-- Author:		Ken Taylor
-- Create date: November 26, 2014
-- Description:	Update PI_Match table's lastname, middle initial.  
-- Then try to make matches using those values and PI_Name_Exceptions table
-- for any 241 employees whose PI_Match has yet to be populated.
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
	-- Set the Last name and First initial for the PI Match entries as we''ll use these for matching:
	UPDATE [dbo].PI_MATCH
	SET [LastName] = SUBSTRING(PI, 1, CHARINDEX('', '' ,PI,1 ) -1 ), 
	[FirstInitial] = SUBSTRING(PI, CHARINDEX('', '' ,PI,1 ) + 2, 1 )
	WHERE LastName IS NULL
	'

	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)


	SELECT @TSQL = '
	-- Try making matches using various combinations of names and PI_Name_Exceptions table.
	UPDATE PI_Match
	SET PI_Match = t1.PI_Match, EID = t1.EID
	FROM
	 (
		SELECT DISTINCT
			t1.OrgR, t1.Accession, 
			t1.[PI], 
			CASE WHEN t2.PI IS NULL THEN t3.ModifiedPIName ELSE t2.PI END PI_Match, 
			CASE WHEN t2.EID IS NULL THEN t3.EID ELSE t2.EID END AS EID
	  FROM [AD419].[dbo].[PI_Match] t1
	  LEFT OUTER JOIN [dbo].[PI_Names] t2 ON t1.OrgR = t2.OrgR 
			AND ((t1.LastName + '', '' + t1.FirstInitial) = t2.PI OR 
				 (REPLACE(t1.PI, '''''''', '''') = t2.PI)
				)
	  LEFT OUTER JOIN [dbo].[PI_Name_Exceptions] t3 ON t1.OrgR = t3.OrgR AND t1.PI_Match IS NULL AND
			((t1.PI = t3.ModifiedPIName) OR(t1.PI = (t3.FirstPortionOfLastName + '', '' + t3.FirstInitial))
			)
	  where PI_Match is NULL 
	  ) t1
	  INNER JOIN PI_Match t2 ON t1.Accession = t2.Accession
	  WHERE t1.PI_Match IS NOT NULL

	  -- Print out any 241 employees that are still unmatched:
	  SELECT ''Non-Matched 241 Employees:'' TableName
	  SELECT * FROM PI_Match
	  WHERE PI_Match IS NULL
	  ORDER BY PI, OrgR, Accession
	  '

	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)
    
	SET NOCOUNT OFF;
END