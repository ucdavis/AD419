-- =============================================
-- Author:		Ken Taylor
-- Create date: January 13, 2012
-- Description:	Given an admin unit, return the appropriate table values
-- Usage:
-- select * from udf_GetAdminTable('ACL1')
-- select * from udf_GetAdminTable('ACL2')
-- select * from udf_GetAdminTable('ACL3')
-- select * from udf_GetAdminTable('ACL4')
-- select * from udf_GetAdminTable('ACL5')
-- select * from udf_GetAdminTable('ADNO')
-- select * from udf_GetAdminTable('All')
-- select * from udf_GetAdminTable('') --AD419
-- Modifications:
-- 2014-12-17 by kjt: Removed database specific database references so it sp can be run against
--	another AD419 database, i.e. AD419_2014, etc.
-- =============================================
CREATE FUNCTION [dbo].[udf_GetAdminTable]
(
	-- Add the parameters for the function here
	@AdminUnit varchar(10) =  ''
)
RETURNS @Retval TABLE (
						loc char(2),
						dept char(3),
						proj char(4),
						project varchar(24),
						accession char(7),
						PI varchar(30),
						f201 decimal(16,2) DEFAULT 0.0,
						f202 decimal(16,2) DEFAULT 0.0,
						f203 decimal(16,2) DEFAULT 0.0,
						f204 decimal(16,2) DEFAULT 0.0,
						f205 decimal(16,2) DEFAULT 0.0,
						f231 decimal(16,2) DEFAULT 0.0,
						f219 decimal(16,2) DEFAULT 0.0,
						f209 decimal(16,2) DEFAULT 0.0,
						f310 decimal(16,2) DEFAULT 0.0,
						f308 decimal(16,2) DEFAULT 0.0,
						f311 decimal(16,2) DEFAULT 0.0,
						f316 decimal(16,2) DEFAULT 0.0,
						f312 decimal(16,2) DEFAULT 0.0,
						f313 decimal(16,2) DEFAULT 0.0,
						f314 decimal(16,2) DEFAULT 0.0,
						f315 decimal(16,2) DEFAULT 0.0,
						f318 decimal(16,2) DEFAULT 0.0,
						f332 decimal(16,2) DEFAULT 0.0,
						f220 decimal(16,2) DEFAULT 0.0,
						f22F decimal(16,2) DEFAULT 0.0,
						f221 decimal(16,2) DEFAULT 0.0,
						f222 decimal(16,2) DEFAULT 0.0,
						f223 decimal(16,2) DEFAULT 0.0,
						f233 decimal(16,2) DEFAULT 0.0,
						f234 decimal(16,2) DEFAULT 0.0,
						f241 decimal(16,2) DEFAULT 0.0,
						f242 decimal(16,2) DEFAULT 0.0,
						f243 decimal(16,2) DEFAULT 0.0,
						f244 decimal(16,2) DEFAULT 0.0,
						f350 decimal(16,2) DEFAULT 0.0
						)
AS 
BEGIN
	-- Fill the table variable with the rows for your result set
	
	IF  @AdminUnit LIKE 'All'  
		INSERT INTO @Retval SELECT * FROM [dbo].[All_Admin]
	ELSE IF @AdminUnit LIKE 'ADNO'  
		INSERT INTO @Retval SELECT * FROM [dbo].[ADNO_Admin]
	ELSE IF @AdminUnit LIKE 'ACL1'  
		INSERT INTO @Retval SELECT * FROM [dbo].[ACL1_Admin]
	ELSE IF @AdminUnit LIKE 'ACL2'  
		INSERT INTO @Retval SELECT * FROM [dbo].[ACL2_Admin]
	ELSE IF @AdminUnit LIKE 'ACL3'  
		INSERT INTO @Retval SELECT * FROM [dbo].[ACL3_Admin]
	ELSE IF @AdminUnit LIKE 'ACL4'  
		INSERT INTO @Retval SELECT * FROM [dbo].[ACL4_Admin]
	ELSE IF @AdminUnit LIKE 'ACL5'  
		INSERT INTO @Retval SELECT * FROM [dbo].[ACL5_Admin]
	ELSE
		INSERT INTO @Retval SELECT * FROM [dbo].[AD419_Admin] 

	RETURN 
END
