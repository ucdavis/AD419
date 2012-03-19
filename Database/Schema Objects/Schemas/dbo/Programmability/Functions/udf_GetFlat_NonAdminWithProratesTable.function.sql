-- =============================================
-- Author:		Ken Taylor
-- Create date: January 13, 2012
-- Description:	Given an admin unit, return the appropriate table values
-- =============================================
CREATE FUNCTION udf_GetFlat_NonAdminWithProratesTable
(
	-- Add the parameters for the function here
	@AdminUnit varchar(10) =  ''
)
RETURNS @Retval TABLE (
			loc char(2), 
			dept char(3), 
			proj char(4), 
			project varchar(24), 
			PI varchar(30), 
			accession char(7), 
			SFN varchar(20), 
			expense decimal(16,2), 
			position int, 
			isFTE bit
		)
AS 
BEGIN
	-- Fill the table variable with the rows for your result set
	
	IF  @AdminUnit LIKE 'All'  
		INSERT INTO @Retval SELECT * FROM [AD419].[dbo].[All_Flat_NonAdminWithProrates]
	ELSE IF @AdminUnit LIKE 'ADNO'  
		INSERT INTO @Retval SELECT * FROM [AD419].[dbo].[ADNO_Flat_NonAdminWithProrates]
	ELSE IF @AdminUnit LIKE 'ACL1'  
		INSERT INTO @Retval SELECT * FROM [AD419].[dbo].[ACL1_Flat_NonAdminWithProrates]
	ELSE IF @AdminUnit LIKE 'ACL2'  
		INSERT INTO @Retval SELECT * FROM [AD419].[dbo].[ACL2_Flat_NonAdminWithProrates]
	ELSE IF @AdminUnit LIKE 'ACL3'  
		INSERT INTO @Retval SELECT * FROM [AD419].[dbo].[ACL3_Flat_NonAdminWithProrates]
	ELSE IF @AdminUnit LIKE 'ACL4'  
		INSERT INTO @Retval SELECT * FROM [AD419].[dbo].[ACL4_Flat_NonAdminWithProrates]
	ELSE IF @AdminUnit LIKE 'ACL5'  
		INSERT INTO @Retval SELECT * FROM [AD419].[dbo].[ACL5_Flat_NonAdminWithProrates]
	ELSE
		INSERT INTO @Retval SELECT * FROM [AD419].[dbo].[AD419_Flat_NonAdminWithProrates] 

	RETURN 
END
