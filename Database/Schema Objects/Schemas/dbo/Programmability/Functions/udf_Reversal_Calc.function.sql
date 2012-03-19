------------------------------------------------------------------------
/*
UDF Name: udf_Reversal_Calc
BY:	Mike Ransom
USAGE:	

DESCRIPTION: 

CURRENT STATUS:
[10/28/05] Fri Created

NOTES:

*/
-------------------------------------------------------------------------
create FUNCTION [dbo].[udf_Reversal_Calc] 
	(
	@FIS_Sal  float, 
	@PPS_Sal float
	)  
RETURNS float
AS
-------------------------------------------------------------------------
BEGIN 
declare @ReversalAmount as money

--FIS positive, PPS negative: no reversal
if @FIS_Sal > 0 and @PPS_Sal <= 0
	begin
	select @ReversalAmount = @PPS_Sal
	return @ReversalAmount
	end
	
--FIS negative, PPS positive: no reversal (or PPS adjustment)
if @FIS_Sal < 0 and @PPS_Sal > 0
	begin
	select @ReversalAmount = 0
	return @ReversalAmount
	end

--Note: I used RETURN in the above cases so that the follwing code would not execute.

--Normal case: both positive (or negative)
	--reversal amount should equal up to PPS amount, but not exceed FIS amount
	-- (in either positive or negative direction)
if abs(@FIS_Sal) < abs(@PPS_Sal)
	select @ReversalAmount = @FIS_Sal
else
	select @ReversalAmount = @PPS_Sal 
return @ReversalAmount
END
-------------------------------------------------------------------------
/*
CALLED BY:
DEPENDENCIES: 
MODIFICATIONS:
*/
