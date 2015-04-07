-- =============================================
-- Author:		Ken Taylor
-- Create date: January 13, 2012
-- Description:	Return the list of possible AD419 report admin units
-- 2014-12-17 by kjt: Removed database specific database references so it sp can be run against
--	another AD419 database, i.e. AD419_2014, etc.
-- =============================================
CREATE FUNCTION [dbo].[udf_GetAD419ReportAdminUnits] 
(
	-- Add the parameters for the function here
)
RETURNS 
@AdminUnitsTable TABLE 
(
	-- Add the column definitions for the TABLE variable here
	AdminUnit varchar(10)
)
AS
BEGIN
	-- Fill the table variable with the rows for your result set
	INSERT INTO @AdminUnitsTable
	
	SELECT [ParamValue]  AS AdminUnit
 	FROM [dbo].[ParamNameAndValue]
	WHERE [ParamName] = 'FinalReportTablesNamePrefix'
	  
	UNION ALL
	  
	SELECT [ParamValue]
	FROM [dbo].[ParamNameAndValue] AS AdminUnit
	WHERE [ParamName] = 'AllTableNamePrefix'
	  
	UNION ALL
	  
	SELECT 'ADNO' AS AdminUnit
	  
	UNION ALL
	    
	SELECT [OrgR] AS AdminUnit
	FROM [dbo].ReportingOrg
	WHERE [IsAdminCluster] = 1 AND [IsActive] = 1
	
	RETURN 
END
