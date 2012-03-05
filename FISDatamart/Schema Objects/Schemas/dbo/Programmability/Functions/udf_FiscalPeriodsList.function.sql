-- =============================================
-- Author:		Ken Taylor
-- Create date: 02-Jun-2010
-- Description:	Creates, populates, and returns a FiscalPeriod table
/*
-- Modifications:
2011-03-17 by kjt:
	Added the '00' period so that beginning balances could be
	selected on balance reports.
*/
-- =============================================
CREATE FUNCTION [dbo].[udf_FiscalPeriodsList] 
(
	-- Add the parameters for the function here
	@AddWildcard bit = 0 -- 0: Do NOT add wildcard ('%') (default); 1: Add wildcard.
)
RETURNS 
@MyTable TABLE 
(
	-- Add the column definitions for the TABLE variable here
	Period char(2), 
	FiscalPeriod varchar(20)
)
AS
BEGIN
	-- Fill the table variable with the rows for your result set
	If @AddWildcard = 1
		BEGIN
			Insert into @MyTable (
				Period, 
				FiscalPeriod
				) VALUES ('%', '%')
		END

	INSERT INTO @MyTable (
		Period, 
		FiscalPeriod
	) VALUES
	 ('00', 'Beginning'),
	 ('01', 'July'), 
	 ('02', 'August'), 
	 ('03','September'), 
	 ('04', 'October'), 
	 ('05', 'November'), 
	 ('06','December'), 
	 ('07','January'), 
	 ('08','February'), 
	 ('09','March'), 
	 ('10','April'), 
	 ('11','May'), 
	 ('12','June'), 
	 ('13','June Final')
	
	RETURN 
END
