-- =============================================
-- Author:		Ken Taylor
-- Create date: 02-Jun-2010
-- Description:	Returns a list of DocumentOriginCodes and their corresponding details for use with Report Builder, etc.
-- =============================================
CREATE FUNCTION [dbo].[udf_DocumentOriginCodesList] 
(
	-- Add the parameters for the function here
	@AddWildcard bit = 0 -- 0: Do NOT add wildcard ('%') (default); 1: Add wildcard.
	 
)
RETURNS 
@MyTable TABLE 
(
	-- Add the column definitions for the TABLE variable here
	DocumentOriginCode varchar(2), 
	OriginCodeDescription varchar(40),
	DocumentOrigin varchar(50),  
	DocumentOriginDatabaseName varchar(40), 
	DocumentOriginServerName varchar(40), 
	IsTP char(1)
)
AS
BEGIN
	-- Fill the table variable with the rows for your result set
	If @AddWildcard = 1
		BEGIN
			Insert into @MyTable (
				DocumentOriginCode, 
				OriginCodeDescription, 
				DocumentOrigin,  
				DocumentOriginDatabaseName, 
				DocumentOriginServerName, 
				IsTP
			) VALUES ('%', '%', '%', '%', '%', null)
		END
		
	Insert into @MyTable (
		DocumentOriginCode, 
		OriginCodeDescription, 
		DocumentOrigin,  
		DocumentOriginDatabaseName, 
		DocumentOriginServerName, 
		IsTP
		)
	SELECT distinct 
		 DocumentOriginCodes.DocumentOriginCode
		,DocumentOriginCodes.OriginCodeDescription
		,(DocumentOriginCodes.DocumentOriginCode + ' - ' + DocumentOriginCodes.OriginCodeDescription) AS DocumentOrigin
		,DocumentOriginCodes.DocumentOriginDatabaseName
		,DocumentOriginCodes.DocumentOriginServerName
		,CASE WHEN DocumentOriginCodes.DocumentOriginCode = '01' THEN 'Y' ELSE 'N' END AS IsTP
	FROM
		DocumentOriginCodes
	ORDER BY 
		OriginCodeDescription
	
	RETURN 
END
