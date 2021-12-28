
-- =============================================
-- Author:		Ken Taylor
-- Create date: April 8, 2020
-- Description:	Return a list of AccountPks that match the criteria for the FunctionCode provided
--		against the FFY_____ORGANIZATION_ACCOUNT table.
-- Modifications:
-- 20110110 by kjt: Changed "OR" to "AND" due to "NOT" logic, i.e.,
--							from (A11AcctNum NOT like '62%' OR A11AcctNum NOT BETWEEN '40' AND '59')
--							to   (A11AcctNum NOT like '62%' AND A11AcctNum NOT BETWEEN '40' AND '59') 
--
-- =============================================
CREATE FUNCTION [dbo].[udf_GetORGANIZATION_HIERARCHY_AccountPKsForFunctionCodeProvided] 
(
	-- Add the parameters for the function here
	@FunctionCode varchar(2)
)
RETURNS 
@MyAccountFKs TABLE 
(
	-- Add the column definitions for the TABLE variable here
	AccountPK varchar(17)
)
AS
BEGIN
	DECLARE @CE_FunctionCode char(2) = 'CE'
	DECLARE @IR_FunctionCode char(2) = 'IR'
	DECLARE @OR_FunctionCode char(2) = 'OR'
	DECLARE @OT_FunctionCode char(2) = 'OT'

-- Insert statements for procedure here
IF @FunctionCode LIKE @OT_FunctionCode

-- Other (OT):
	insert into @MyAccountFKs select DISTINCT ACCOUNTS_FK from FISDataMart.dbo.FFY2020_TransV trans_v
	inner join FFY2020_ORGANIZATION_ACCOUNT accts on ACCOUNTS_FK = accts.ORGANIZATION_ACCOUNT_PK
	where BALANCE_TYPE_CODE in ('BB', 'BI', 'FT','FI')
		and SUB_FUND_GROUP_NUM IN (select SubFundGroupNum from FISDataMart.dbo.BaseBudgetSubFundGroups)
		AND (HIGHER_ED_FUNC_CODE NOT IN ('PBSV', 'INST', 'FINA', 'ORES')
		AND (A11_ACCT_NUM NOT like '62%' AND A11_ACCT_NUM NOT BETWEEN '40' AND '59'))
ELSE IF @FunctionCode LIKE @CE_FunctionCode

-- Cooperative Extension (CE):
	insert into @MyAccountFKs select DISTINCT ACCOUNTS_FK from FISDataMart.dbo.FFY2020_TransV trans_v
	inner join FFY2020_ORGANIZATION_ACCOUNT accts on ACCOUNTS_FK = accts.ORGANIZATION_ACCOUNT_PK
	where BALANCE_TYPE_CODE in ('BB', 'BI', 'FT','FI')
		and SUB_FUND_GROUP_NUM IN (select SubFundGroupNum from FISDataMart.dbo.BaseBudgetSubFundGroups)
		and (HIGHER_ED_FUNC_CODE = 'PBSV' OR A11_ACCT_NUM like '62%')
ELSE IF @FunctionCode LIKE @IR_FunctionCode

-- Instruction (IR):
	insert into @MyAccountFKs select DISTINCT ACCOUNTS_FK from FISDataMart.dbo.FFY2020_TransV trans_v
	inner join FFY2020_ORGANIZATION_ACCOUNT accts on ACCOUNTS_FK = accts.ORGANIZATION_ACCOUNT_PK
	where BALANCE_TYPE_CODE in ('BB', 'BI', 'FT','FI')
		and SUB_FUND_GROUP_NUM IN (select SubFundGroupNum from FISDataMart.dbo.BaseBudgetSubFundGroups)
		and (HIGHER_ED_FUNC_CODE IN ('INST', 'FINA') OR LEFT(A11_ACCT_NUM,2) BETWEEN '40' AND '43')
		
ELSE IF @FunctionCode LIKE @OR_FunctionCode

-- Organized Research (OR):
	insert into @MyAccountFKs select DISTINCT ACCOUNTS_FK from FISDataMart.dbo.FFY2020_TransV trans_v
	inner join FFY2020_ORGANIZATION_ACCOUNT accts on ACCOUNTS_FK = accts.ORGANIZATION_ACCOUNT_PK
	where BALANCE_TYPE_CODE in ('BB', 'BI', 'FT','FI')
		and SUB_FUND_GROUP_NUM IN (select SubFundGroupNum from FISDataMart.dbo.BaseBudgetSubFundGroups)
		and (HIGHER_ED_FUNC_CODE = 'ORES' OR LEFT(A11_ACCT_NUM,2) BETWEEN '44' AND '59')
RETURN 
END