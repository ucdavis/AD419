-- =============================================
-- Author:		Ken Taylor
-- Create date: 02-Jun-2010
-- Description:	Returns a list of DocumentTypes and their corresponding details for use with Report Builder, etc.
-- Modifications: 
-- 2012-12-05 by kjt: Manual addition of 'BA' transaction type since it is missing from DocumentTypes table.
-- =============================================
create FUNCTION [dbo].[udf_DocumentTypesList] 
(
	-- Add the parameters for the function here
	@AddWildcard bit = 0, -- 0: Do NOT add wildcard ('%') (default); 1: Add wildcard., 
	@ReturnInactiveAlso bit = 1 -- 1: Return ALL records (default); 0: Return only those records where the LevelActiveInd = 'Y'. bit
)
RETURNS 
@MyTable TABLE 
(
	-- Add the column definitions for the TABLE variable here
	DocumentTypeCode varchar(4), 
	DocumentType varchar(50), 
	DocumentTypeName varchar(100), 
    DocumentActiveInd char(1)
)
AS
BEGIN
	-- Fill the table variable with the rows for your result set
	If @AddWildcard = 1
		BEGIN
			Insert into @MyTable (
				DocumentTypeCode, 
				DocumentType, 
				DocumentTypeName, 
				DocumentActiveInd
			) VALUES ('%', '%', '%', 'Y')
		END
		
	-- 2012-12-05 by kjt: Manual addition of 'BA' transaction type since it is missing from DocumentTypes table:
	Insert into @MyTable (
				DocumentTypeCode, 
				DocumentType, 
				DocumentTypeName, 
				DocumentActiveInd
			) VALUES ('BA', 'BA - Budget Adjustment', '(BB or CB) Budget Adjustment', 'Y')

	-- 2013-06-26 by kjt: Manual addition of 'YEBA' transaction type since it is missing from DocumentTypes table:
	Insert into @MyTable (
				DocumentTypeCode, 
				DocumentType, 
				DocumentTypeName, 
				DocumentActiveInd
			) VALUES ('YEBA', 'YEBA - Budget Adjustment', '(YEBB or YECB) Year End Budget Adjustment', 'Y')
		
	If @ReturnInactiveAlso = 1
		BEGIN
			Insert into @MyTable (
				DocumentTypeCode, 
				DocumentType, 
				DocumentTypeName, 
				DocumentActiveInd
			)
		SELECT
			DocumentTypes.DocumentType AS DocumentTypeCode,
		   (DocumentTypes.DocumentType + ' - ' + DocumentTypes.DocumentTypeName) AS DocumentType,
			DocumentTypes.DocumentTypeName,
			DocumentActiveIndicator
		FROM
			DocumentTypes
		END
	Else
		BEGIN
			Insert into @MyTable (
				DocumentTypeCode, 
				DocumentType, 
				DocumentTypeName, 
				DocumentActiveInd
			)
			SELECT
				DocumentTypes.DocumentType AS DocumentTypeCode,
			   (DocumentTypes.DocumentType + ' - ' + DocumentTypes.DocumentTypeName) AS DocumentType,
				DocumentTypes.DocumentTypeName,
				DocumentActiveIndicator
			FROM
				DocumentTypes 
			WHERE DocumentActiveIndicator = 'Y'
		END	
	
	RETURN 
END
