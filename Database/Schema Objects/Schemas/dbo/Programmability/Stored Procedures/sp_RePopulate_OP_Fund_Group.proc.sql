------------------------------------------------------------------------
-- PROGRAM: sp_RePopulate_OP_Fund_Group.SQL
-- BY:	Mike Ransom	[4/13/05] Wed
-- USAGE:	EXEC sp_RePopulate_OP_Fund_Group.SQL

-- DESCRIPTION: 
-- Drops all rows from OP_Fund_Group table, repopulates with pass-thru query against Oracle source FIS_DS_PROD

-- CURRENT STATUS:
-- 

-- NOTES:
-- CALLED BY:
-- DEPENDENCIES: 
-- MODIFICATIONS: see bottom
-------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[sp_RePopulate_OP_Fund_Group]
--PARAMETERS: none
	
AS
-------------------------------------------------------------------------
--Drop existing rows:
DELETE FROM FIS.OP_Fund_Group

--Repopulate:
INSERT INTO FIS.OP_Fund_Group
	(
	OP_FUND_GROUP_CODE, 
	OP_FUND_GROUP_NAME
	)
SELECT * FROM
	OPENQUERY 
		(FIS_DS_PROD,
		'
SELECT DISTINCT 
	OP_FUND_GROUP_CODE, 
	OP_FUND_GROUP_NAME
FROM FINANCE.OP_FUND
WHERE
	FISCAL_PERIOD = ''--''
ORDER BY 
	OP_FUND_GROUP_CODE
		')

-------------------------------------------------------------------------
-- MODIFICATIONS:
-- [4/13/05] Wed created
