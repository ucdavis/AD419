-- =============================================
-- Author:		Ken Taylor
-- Create date: 2011-12-23
-- Description:	Builds the SQL to create a AD419 admin table with pro-rated amounts table, and then executes the SQL and created the table
-- Modifications:
-- 2014-12-17 by kjt: Removed database specific database references so it sp can be run against
--	another AD419 database, i.e. AD419_2014, etc.
-- =============================================
CREATE FUNCTION [dbo].[udf_DropAndCreateAdminWithProratedAmountsTable] 
(	
	-- Add the parameters for the function here
	@TableName varchar(255) = 'NonAdminWithProratedAmountsTEST'
)
RETURNS int 
AS
--DECLARE @TableName varchar(200) = 'NonAdminWithProratedAmountsTEST'
BEGIN
DECLARE @i int
DECLARE @SFN_UnassociatedTotal TABLE
				(
					SFN varchar(4),
					ProjCount int,
					UnassociatedTotal decimal(16,2),
					ProjectsTotal decimal(16,2)
				)

INSERT INTO @SFN_UnassociatedTotal SELECT * FROM udf_GetSFN_UnassociatedTotal('', 0) 


DECLARE @SFN_order TABLE (SFN varchar(5))
INSERT INTO @SFN_order VALUES ('f219'), ('f209'), ('f310'), ('f308'), ('f311'), ('f316'), ('f312'),('f313'), ('f314'), ('f315'),('f318'), ('f332'),
('f220'),('f22F'), ('f221'), ('f222'),('f223'), ('f233'), ('f234'),
('f241'), ('f242'), ('f243'),('f244'), ('f350');



Declare @CreateTableSQL varchar(MAX) = 'CREATE TABLE [dbo].[' + @TableName + '] (
				--rownum int IDENTITY(1,1) Primary key not null,
				loc char(2),
				dept char(3),
				proj char(4),
				project varchar(24),
				accession char(7),
				PI varchar(30),
				f201 decimal(16,2),
				f202 decimal(16,2),
				f203 decimal(16,2),
				f204 decimal(16,2),
				f205 decimal(16,2),
				f231 decimal(16,2)
			  '
				
				DECLARE OuterCursor CURSOR for SELECT * FROM @SFN_order FOR READ ONLY;
				open OuterCursor
				declare @OrderedSFN varchar(4)
				fetch next from OuterCursor into @OrderedSFN
				while @@FETCH_STATUS <> -1
				BEGIN
					SELECT @CreateTableSQL += ', ' + @OrderedSFN + ' decimal(16,2)
			  '
				declare MyCursor Cursor for select SFN
					from @SFN_UnassociatedTotal where UnassociatedTotal > 0  for READ ONLY;
					
					open MyCursor
					declare @MySFN varchar(4)
					
					fetch next from MyCursor into @MySFN
					
					while @@FETCH_STATUS <> -1
						BEGIN
					
							IF 'f' + @MySFN = @OrderedSFN 
							BEGIN
								select @CreateTableSQL += ', f' + @MySFN + '_prorate decimal(16,2), [f' + @MySFN + '_plus_admin] decimal(16,2)
			  '
							END
							fetch next from MyCursor into @MySFN
						END 
						
					close MyCursor
					deallocate MyCursor
					
					fetch next from OuterCursor into @OrderedSFN
				END
				
				close OuterCursor
				deallocate OuterCursor
				
				select @CreateTableSQL += ');'
				
				IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[' + @TableName + ']') AND type in (N'U'))
					BEGIN 
						DECLARE @DropTableSQL varchar(255) = 'DROP TABLE [dbo].[' + @TableName + ']'
						--IF @IsDebug = 1 PRINT 'Table ' + @TableName + ' exists; ' + @DropTableSQL
						exec sp_executesql N'EXEC(@DropTableSQL)', N'@DropTableSQL varchar(255)', @DropTableSQL
					END
				
				--if @IsDebug = 1 Print @CreateTableSQL;
					
				exec sp_executesql N'EXEC(@CreateTableSQL)', N'@CreateTableSQL varchar(MAX), @ReturnVal int output', @CreateTableSQL, @i output
				
				RETURN @i
				
END