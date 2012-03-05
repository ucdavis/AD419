-- =============================================
-- Author:		Ken Taylor
-- Create date: 02-Jun-2010
-- Description:	Returns a list of DocumentTypes and their
-- corresponding details for use with Report Builder, etc.
-- =============================================
CREATE PROCEDURE [dbo].[usp_GetDocumentTypesList] 
	-- Add the parameters for the stored procedure here
	@AddWildcard bit = 0, -- 0: Do NOT add wildcard ('%') (default); 1: Add wildcard.
	@ReturnInactiveAlso bit = 1 -- 1: Return ALL records (default); 0: Return only those records where the 
	-- LevelActiveInd = 'Y'.
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	DECLARE @MyTable TABLE (
		 DocumentTypeCode varchar(4), 
		 DocumentType varchar(50), 
		 DocumentTypeName varchar(40), 
         DocumentActiveInd char(1)
	)

	If @AddWildcard = 1
		BEGIN
			Insert into @MyTable (
				DocumentTypeCode, 
				DocumentType, 
				DocumentTypeName, 
				DocumentActiveInd
			) VALUES ('%', '%', '%', 'Y')
		END
		
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
	
	If @ReturnInactiveAlso = 1
		BEGIN
			Select * from @MyTable
		END
	Else
		BEGIN
			Select * from @MyTable where DocumentActiveInd = 'Y'
		END
END
