-- =============================================
-- Author:		Ken Taylor
-- Create date: April 13, 2010
-- Description:	Update the Accounts.FunctionCodeID according to their corresponding transactions
-- BalType, SubFundGroupNum, HigherEdFuncCode or A11AcctNum(aka OP Acct Num)
-- =============================================
CREATE PROCEDURE [dbo].[usp_UpdateAccountsFunctionCodeID] 
	-- Add the parameters for the stored procedure here
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

Declare @TSQL varchar(max) = ''

Select @TSQL = '
Update FISDataMart.dbo.Accounts set FunctionCodeID = null;

DECLARE @FunctionCode char(2)

SELECT @FunctionCode = ''CE''
Update FISDataMart.dbo.Accounts
set FunctionCodeID = (Select functioncodeID from FISDataMart.dbo.FunctionCode where FunctionCode = @FunctionCode)
  where AccountPK in (select * from udf_GetAccountPKsForFunctionCodeProvided(@FunctionCode))

SELECT @FunctionCode = ''IR''
Update FISDataMart.dbo.Accounts
set FunctionCodeID = (Select functioncodeID from FISDataMart.dbo.FunctionCode where FunctionCode = @FunctionCode)
  where AccountPK in (select * from udf_GetAccountPKsForFunctionCodeProvided(@FunctionCode))

SELECT @FunctionCode = ''OR''
Update FISDataMart.dbo.Accounts
set FunctionCodeID = (Select functioncodeID from FISDataMart.dbo.FunctionCode where FunctionCode = @FunctionCode)
  where AccountPK in (select * from udf_GetAccountPKsForFunctionCodeProvided(@FunctionCode))
  
SELECT @FunctionCode = ''OT''
Update FISDataMart.dbo.Accounts
set FunctionCodeID = (Select functioncodeID from FISDataMart.dbo.FunctionCode where FunctionCode = @FunctionCode)
  where AccountPK in (select * from udf_GetAccountPKsForFunctionCodeProvided(@FunctionCode))
'
-------------------------------------------------------------------------------------------
IF @IsDebug = 1
	Print @TSQL
ELSE
	EXEC (@TSQL)

	 
END
