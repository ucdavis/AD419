-- =============================================
-- Author:		Ken Taylor
-- Create date: January 8th, 2014
-- Description:	List of College PI's as requested by Tom Kaiser
-- Usage:
/*
	SELECT * FROM udf_CaesPrincipalInvestigatorNames(2013)
*/
-- =============================================
CREATE FUNCTION udf_CaesPrincipalInvestigatorNames
(
	-- Add the parameters for the function here
	@Year int
)
RETURNS 
@PrincipalInvestigatorTable TABLE 
(
	-- Add the column definitions for the TABLE variable here
	PrincipalInvestigatorName varchar(50)
)
AS
BEGIN
	-- Fill the table variable with the rows for your result set
	INSERT INTO @PrincipalInvestigatorTable
	SELECT DISTINCT PrincipalInvestigatorName
	FROM [dbo].[Accounts]
	WHERE isCAES = 1 AND Year = @Year and Chart in ('3','L') and PrincipalInvestigatorName IS NOT NULL
	ORDER BY 1
	
	RETURN 
END