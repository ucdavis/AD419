-- =============================================
-- Author:		Ken Taylor
-- Create date: January 12, 2012
-- Description:	Given an admin unit, return the appropriate table values
-- Usage: 
-- select * from udf_GetUnassociatedTotalsTable('ACL1')
-- select * from udf_GetUnassociatedTotalsTable('ACL2')
-- select * from udf_GetUnassociatedTotalsTable('ACL3')
-- select * from udf_GetUnassociatedTotalsTable('ACL4')
-- select * from udf_GetUnassociatedTotalsTable('ACL5')
-- select * from udf_GetUnassociatedTotalsTable('ADNO')
-- select * from udf_GetUnassociatedTotalsTable('All')
-- select * from udf_GetUnassociatedTotalsTable('') --AD419
-- =============================================
CREATE FUNCTION udf_GetUnassociatedTotalsTable
(
	-- Add the parameters for the function here
	@AdminUnit varchar(10) =  ''
)
RETURNS @Retval TABLE (
							SFN varchar(4),
							ProjCount int DEFAULT 0,
							UnassociatedTotal decimal(16,2) DEFAULT 0.0,
							ProjectsTotal decimal(16,2) DEFAULT 0.0
						)
AS 
BEGIN
	-- Fill the table variable with the rows for your result set
	
	IF  @AdminUnit LIKE 'All'  
		INSERT INTO @Retval SELECT * FROM [AD419].[dbo].[All_UnassociatedTotals]
	ELSE IF @AdminUnit LIKE 'ADNO'  
		INSERT INTO @Retval SELECT * FROM [AD419].[dbo].[ADNO_UnassociatedTotals]
	ELSE IF @AdminUnit LIKE 'ACL1'  
		INSERT INTO @Retval SELECT * FROM [AD419].[dbo].[ACL1_UnassociatedTotals]
	ELSE IF @AdminUnit LIKE 'ACL2'  
		INSERT INTO @Retval SELECT * FROM [AD419].[dbo].[ACL2_UnassociatedTotals]
	ELSE IF @AdminUnit LIKE 'ACL3'  
		INSERT INTO @Retval SELECT * FROM [AD419].[dbo].[ACL3_UnassociatedTotals]
	ELSE IF @AdminUnit LIKE 'ACL4'  
		INSERT INTO @Retval SELECT * FROM [AD419].[dbo].[ACL4_UnassociatedTotals]
	ELSE IF @AdminUnit LIKE 'ACL5'  
		INSERT INTO @Retval SELECT * FROM [AD419].[dbo].[ACL5_UnassociatedTotals]
	ELSE
		INSERT INTO @Retval SELECT * FROM [AD419].[dbo].[AD419_UnassociatedTotals] 

	
	RETURN 
END
