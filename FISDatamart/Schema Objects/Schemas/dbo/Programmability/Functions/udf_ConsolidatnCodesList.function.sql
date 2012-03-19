-- =============================================
-- Author:		Ken Taylor
-- Create date: 02-Jun-2010
-- Description:	
-- =============================================
CREATE FUNCTION [dbo].[udf_ConsolidatnCodesList] 
(
	-- Add the parameters for the function here
	@AddWildcard bit = 0, -- Set to 1 to insert wildcard ('%') at front of list. 
	@ReturnInactiveAlso bit = 1 -- Set to 0 to only return records that are currently "Active".
)
RETURNS 
@MyTable TABLE 
(
	-- Add the column definitions for the TABLE variable here
	ConsolidatnCode varchar(4), 
	ConsolidatnName varchar(40),
	ConsolidatnShortName char(12), 
	ObjectConsolidation varchar(100),
	ConsolidatnActiveInd char(1)
)
AS
BEGIN
	-- Fill the table variable with the rows for your result set
	
	If @AddWildcard = 1
		BEGIN
			Insert into @MyTable (
				ConsolidatnCode, 
				ConsolidatnName, 
				ConsolidatnShortName, 
				ObjectConsolidation,
				ConsolidatnActiveInd
			) VALUES ('%', '%', '%', '%', 'Y')
		END
		
	If @ReturnInactiveAlso = 1
		BEGIN
			Insert into @MyTable (
			ConsolidatnCode, 
			ConsolidatnName, 
			ConsolidatnShortName, 
			ObjectConsolidation,
			ConsolidatnActiveInd
			)
			SELECT distinct 
				ConsolidatnCode, 
				ConsolidatnName, 
				ConsolidatnShortName, 
				(ConsolidatnCode + ' - ' + ConsolidatnName) AS ObjectConsolidation,
				ConsolidatnActiveInd  
			From dbo.Objects
			Where Year = 9999 
			Group by ConsolidatnCode, ConsolidatnName, ConsolidatnShortName, ConsolidatnActiveInd
			Order by ConsolidatnCode, ConsolidatnName, ConsolidatnShortName, ConsolidatnActiveInd
		END
	ELSE
		BEGIN
			Insert into @MyTable (
				ConsolidatnCode, 
				ConsolidatnName, 
				ConsolidatnShortName, 
				ObjectConsolidation,
				ConsolidatnActiveInd
				)
			SELECT distinct 
				ConsolidatnCode, 
				ConsolidatnName, 
				ConsolidatnShortName, 
				(ConsolidatnCode + ' - ' + ConsolidatnName) AS ObjectConsolidation,
				ConsolidatnActiveInd  
			From dbo.Objects
			Where Year = 9999 AND ConsolidatnActiveInd = 'Y'
			Group by ConsolidatnCode, ConsolidatnName, ConsolidatnShortName, ConsolidatnActiveInd
			Order by ConsolidatnCode, ConsolidatnName, ConsolidatnShortName, ConsolidatnActiveInd
		END
	RETURN 
END
