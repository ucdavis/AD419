-- =============================================
-- Author:		Ken Taylor
-- Create date: 17-Dec-2012
-- Description:	Returns a list of OP Fund Numbers and  
-- their corresponding Level for use with Report Builder, etc.
-- =============================================
CREATE FUNCTION [dbo].[udf_OpFundList] 
(
	-- Add the parameters for the function here
	@AddWildcard bit = 0-- 0: Do NOT add wildcard ('%') (default); 1: Add wildcard.
)
RETURNS 
@MyTable TABLE 
(
	-- Add the column definitions for the TABLE variable here
	FundNum varchar(6), 
	FundName varchar(40),
	OpFundNum varchar(100)
)
AS
BEGIN
	-- Fill the table variable with the rows for your result set
	
	If @AddWildcard = 1
		BEGIN
			Insert into @MyTable (
				FundNum, 
				FundName, 
				OpFundNum
				) VALUES ('%', '%', '%')
		END
		
		
		BEGIN
			Insert into @MyTable (FundNum, FundName, OpFundNum)
			Select distinct FundNum, FundName, (FundNum + ' - ' +  FundName) AS OpFundNum
			From dbo.OPFund
			Where Year = 9999 AND Period = '--'
			Group by FundNum, FundName
			Order by FundNum, FundName
		END
	
	RETURN 
END