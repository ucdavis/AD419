-- =============================================
-- Author:		Ken Taylor
-- Create date: Oct 1, 2010
-- Description:	Return a list of AccountPks that match the criteria for the FunctionCode provided.
-- Modifications:
-- 20110110 by kjt: Changed "OR" to "AND" due to "NOT" logic, i.e.,
--							from (A11AcctNum NOT like '62%' OR A11AcctNum NOT BETWEEN '40' AND '59')
--							to   (A11AcctNum NOT like '62%' AND A11AcctNum NOT BETWEEN '40' AND '59') 
--
-- =============================================
CREATE FUNCTION [dbo].[udf_GetAccountPKsForFunctionCodeProvided] 
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
	insert into @MyAccountFKs select DISTINCT AccountsFK from FISDataMart.dbo.TransV trans_v
	inner join Accounts accts on AccountsFK = accts.AccountPK
	where BalType in ('BB', 'BI', 'FT','FI')
		and SubFundGroupNum IN (select SubFundGroupNum from FISDataMart.dbo.BaseBudgetSubFundGroups)
		AND (HigherEdFuncCode NOT IN ('PBSV', 'INST', 'FINA', 'ORES')
		AND (A11AcctNum NOT like '62%' AND A11AcctNum NOT BETWEEN '40' AND '59'))
ELSE IF @FunctionCode LIKE @CE_FunctionCode

-- Cooperative Extension (CE):
	insert into @MyAccountFKs select DISTINCT AccountsFK from FISDataMart.dbo.TransV trans_v
	inner join Accounts accts on AccountsFK = accts.AccountPK
	where BalType in ('BB', 'BI', 'FT','FI')
		and SubFundGroupNum IN (select SubFundGroupNum from FISDataMart.dbo.BaseBudgetSubFundGroups)
		and (HigherEdFuncCode = 'PBSV' OR A11AcctNum like '62%')
ELSE IF @FunctionCode LIKE @IR_FunctionCode

-- Instruction (IR):
	insert into @MyAccountFKs select DISTINCT AccountsFK from FISDataMart.dbo.TransV trans_v
	inner join Accounts accts on AccountsFK = accts.AccountPK
	where BalType in ('BB', 'BI', 'FT','FI')
		and SubFundGroupNum IN (select SubFundGroupNum from FISDataMart.dbo.BaseBudgetSubFundGroups)
		and (HigherEdFuncCode IN ('INST', 'FINA') OR LEFT(A11AcctNum,2) BETWEEN '40' AND '43')
		
ELSE IF @FunctionCode LIKE @OR_FunctionCode

-- Organized Research (OR):
	insert into @MyAccountFKs select DISTINCT AccountsFK from FISDataMart.dbo.TransV trans_v
	inner join Accounts accts on AccountsFK = accts.AccountPK
	where BalType in ('BB', 'BI', 'FT','FI')
		and SubFundGroupNum IN (select SubFundGroupNum from FISDataMart.dbo.BaseBudgetSubFundGroups)
		and (HigherEdFuncCode = 'ORES' OR LEFT(A11AcctNum,2) BETWEEN '44' AND '59')
RETURN 
END
