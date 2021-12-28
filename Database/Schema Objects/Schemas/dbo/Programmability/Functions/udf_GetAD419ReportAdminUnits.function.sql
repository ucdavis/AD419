-- =============================================
-- Author:		Ken Taylor
-- Create date: January 13, 2012
-- Description:	Return the list of possible AD419 report admin units
-- 2014-12-17 by kjt: Removed database specific database references so it sp can be run against
--	another AD419 database, i.e. AD419_2014, etc.
--
-- Notes:
-- Returns a list similar to:
-- AdminUnit:
-- AD419
-- All
-- ADNO
-- ACL1
-- ACL2
-- ACL3
-- ACL4
-- ACL5 
--
-- Usage:
/*

SELECT * FROM udf_GetAD419ReportAdminUnits()

*/
-- Modifications:
--	20171004 by kjt: Added new "Admin" unit to allow pulling of reports with
--		credits zeroed out.
-- =============================================
CREATE FUNCTION [dbo].[udf_GetAD419ReportAdminUnits] 
(
	-- Add the parameters for the function here
)
RETURNS 
@AdminUnitsTable TABLE 
(
	-- Add the column definitions for the TABLE variable here
	AdminUnit varchar(25)
)
AS
BEGIN
	-- Fill the table variable with the rows for your result set
	INSERT INTO @AdminUnitsTable
	SELECT [ParamValue]  AS AdminUnit
 	FROM [dbo].[ParamNameAndValue]
	WHERE [ParamName] = 'ANR_FinalReportPrefix'

	INSERT INTO @AdminUnitsTable
	SELECT [ParamValue]  AS AdminUnit
 	FROM [dbo].[ParamNameAndValue]
	WHERE [ParamName] = 'FinalReportTablesNamePrefix'
	  
	INSERT INTO @AdminUnitsTable  
	SELECT [ParamValue]
	FROM [dbo].[ParamNameAndValue] AS AdminUnit
	WHERE [ParamName] = 'AllTableNamePrefix'
	  
	INSERT INTO @AdminUnitsTable  
	SELECT 'ADNO' AS AdminUnit
	  
	INSERT INTO @AdminUnitsTable    
	SELECT [OrgR] AS AdminUnit
	FROM [dbo].ReportingOrg
	WHERE [IsAdminCluster] = 1 AND [IsActive] = 1
	
	RETURN 
END
