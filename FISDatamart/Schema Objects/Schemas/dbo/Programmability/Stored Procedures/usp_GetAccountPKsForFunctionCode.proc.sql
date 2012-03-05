-- =============================================
-- Author:		Ken Taylor
-- Create date: Oct 1, 2010
-- Description:	usp to return list of account PKs matching the Function Code provided
-- =============================================
CREATE PROCEDURE [dbo].[usp_GetAccountPKsForFunctionCode]
-- Add the parameters for the stored procedure here
@FunctionCode varchar(2) = ''
AS
BEGIN
DECLARE @CE_FunctionCode char(2) = 'CE'
DECLARE @IR_FunctionCode char(2) = 'IR'
DECLARE @OR_FunctionCode char(2) = 'OR'
DECLARE @OT_FunctionCode char(2) = 'OT'

-- SET NOCOUNT ON added to prevent extra result sets from
-- interfering with SELECT statements.
SET NOCOUNT ON;

-- Insert statements for procedure here
IF @FunctionCode LIKE @OT_FunctionCode

-- Other (OT):
	select DISTINCT AccountsFK from FISDataMart.dbo.TransV trans_v
	inner join Accounts accts on AccountsFK = accts.AccountPK
	where BalType in ('BB', 'BI', 'FT','FI')
		and SubFundGroupNum IN (select SubFundGroupNum from FISDataMart.dbo.BaseBudgetSubFundGroups)
		AND (HigherEdFuncCode NOT IN ('PBSV', 'INST', 'FINA', 'ORES')
		AND (A11AcctNum NOT like '62%' OR A11AcctNum NOT BETWEEN '40' AND '59'))
ELSE IF @FunctionCode LIKE @CE_FunctionCode

-- Cooperative Extension (CE):
	select DISTINCT AccountsFK from FISDataMart.dbo.TransV trans_v
	inner join Accounts accts on AccountsFK = accts.AccountPK
	where BalType in ('BB', 'BI', 'FT','FI')
		and SubFundGroupNum IN (select SubFundGroupNum from FISDataMart.dbo.BaseBudgetSubFundGroups)
		and (HigherEdFuncCode = 'PBSV' OR A11AcctNum like '62%')
ELSE IF @FunctionCode LIKE @IR_FunctionCode

-- Instruction (IR):
	select DISTINCT AccountsFK from FISDataMart.dbo.TransV trans_v
	inner join Accounts accts on AccountsFK = accts.AccountPK
	where BalType in ('BB', 'BI', 'FT','FI')
		and SubFundGroupNum IN (select SubFundGroupNum from FISDataMart.dbo.BaseBudgetSubFundGroups)
		and (HigherEdFuncCode IN ('INST', 'FINA') OR LEFT(A11AcctNum,2) BETWEEN '40' AND '43')
		
ELSE IF @FunctionCode LIKE @OR_FunctionCode

-- Organized Research (OR):
	select DISTINCT AccountsFK from FISDataMart.dbo.TransV trans_v
	inner join Accounts accts on AccountsFK = accts.AccountPK
	where BalType in ('BB', 'BI', 'FT','FI')
		and SubFundGroupNum IN (select SubFundGroupNum from FISDataMart.dbo.BaseBudgetSubFundGroups)
		and (HigherEdFuncCode = 'ORES' OR LEFT(A11AcctNum,2) BETWEEN '44' AND '59')
ELSE Return -1
END
