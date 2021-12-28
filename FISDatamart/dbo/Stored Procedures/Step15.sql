
CREATE PROCEDURE [dbo].[Step15]
AS
BEGIN
	Update FISDataMart.dbo.Accounts set FunctionCodeID = null;

DECLARE @FunctionCode char(2)

SELECT @FunctionCode = 'CE'
Update FISDataMart.dbo.Accounts
set FunctionCodeID = (Select functioncodeID from FISDataMart.dbo.FunctionCode where FunctionCode = @FunctionCode)
  where AccountPK in (select * from udf_GetAccountPKsForFunctionCodeProvided(@FunctionCode))

SELECT @FunctionCode = 'IR'
Update FISDataMart.dbo.Accounts
set FunctionCodeID = (Select functioncodeID from FISDataMart.dbo.FunctionCode where FunctionCode = @FunctionCode)
  where AccountPK in (select * from udf_GetAccountPKsForFunctionCodeProvided(@FunctionCode))

SELECT @FunctionCode = 'OR'
Update FISDataMart.dbo.Accounts
set FunctionCodeID = (Select functioncodeID from FISDataMart.dbo.FunctionCode where FunctionCode = @FunctionCode)
  where AccountPK in (select * from udf_GetAccountPKsForFunctionCodeProvided(@FunctionCode))
  
SELECT @FunctionCode = 'OT'
Update FISDataMart.dbo.Accounts
set FunctionCodeID = (Select functioncodeID from FISDataMart.dbo.FunctionCode where FunctionCode = @FunctionCode)
  where AccountPK in (select * from udf_GetAccountPKsForFunctionCodeProvided(@FunctionCode))
END