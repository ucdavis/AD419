-- =============================================
-- Author:		Ken Taylor
-- Create date: 2011-12-23
-- Description:	Builds the SQL to create a AD419 admin table with pro-rated amounts table, 
-- and then executes the SQL to drop and create the table
-- =============================================
CREATE PROCEDURE  usp_DropAndCreateAdminWithProratedAmountsTable 
	-- Add the parameters for the stored procedure here
	@OutputTableName varchar(255) = 'NonAdminWithProratedAmountsTemp', -- Output table name
	@NonAdminTableName varchar(255) = 'NonAdminTable', -- Input table name
	@NonAdminTable NonAdminTableType READONLY,
	@SFN_UnassociatedTotal SFN_UnassociatedTotalsType READONLY,
	@IsDebug bit = 1
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

DECLARE @SFN_order TABLE (SFN varchar(5))
INSERT INTO @SFN_order VALUES ('f219'), ('f209'), ('f310'), ('f308'), ('f311'), ('f316'), ('f312'),('f313'), ('f314'), ('f315'),('f318'), ('f332'),
('f220'),('f22F'), ('f221'), ('f222'),('f223'), ('f233'), ('f234'),
('f241'), ('f242'), ('f243'),('f244'), ('f350');

Declare @CreateTableSQL varchar(MAX) = 'CREATE TABLE [AD419].[dbo].[' + @OutputTableName + '] (
				--rownum int IDENTITY(1,1) Primary key not null,
				loc char(2),
				dept char(3),
				proj char(4),
				project varchar(24),
				accession char(7),
				PI varchar(30),
				f201 decimal(16,2) DEFAULT 0,
				f202 decimal(16,2) DEFAULT 0,
				f203 decimal(16,2) DEFAULT 0,
				f204 decimal(16,2) DEFAULT 0,
				f205 decimal(16,2) DEFAULT 0,
				f231 decimal(16,2) DEFAULT 0
			  '
				
				DECLARE OuterCursor CURSOR for SELECT * FROM @SFN_order FOR READ ONLY;
				open OuterCursor
				declare @OrderedSFN varchar(4)
				fetch next from OuterCursor into @OrderedSFN
				while @@FETCH_STATUS <> -1
				BEGIN
					SELECT @CreateTableSQL += ', ' + @OrderedSFN + ' decimal(16,2) DEFAULT 0
			  '
				declare MyCursor Cursor for select SFN
					from @SFN_UnassociatedTotal for READ ONLY;
					
					open MyCursor
					declare @MySFN varchar(4)
					
					fetch next from MyCursor into @MySFN
					
					while @@FETCH_STATUS <> -1
						BEGIN
					
							IF 'f' + @MySFN = @OrderedSFN 
							BEGIN
								select @CreateTableSQL += ', f' + @MySFN + '_prorate decimal(16,2) DEFAULT 0, [f' + @MySFN + '_plus_admin] decimal(16,2) DEFAULT 0
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
				
				IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[' + @OutputTableName + ']') AND type in (N'U'))
					BEGIN 
						DECLARE @DropTableSQL varchar(255) = 'DROP TABLE [dbo].[' + @OutputTableName + ']'
						IF @IsDebug = 1 PRINT 'Table [' + @OutputTableName + '] exists; ' + @DropTableSQL
						exec sp_executesql N'EXEC(@DropTableSQL)', N'@DropTableSQL varchar(255)', @DropTableSQL
					END
				
				if @IsDebug = 1 Print @CreateTableSQL;
					
				exec sp_executesql N'EXEC(@CreateTableSQL)', N'@CreateTableSQL varchar(MAX)', @CreateTableSQL
				
				SELECT @CreateTableSQL = 'Insert into [' + @OutputTableName + ']
				(
					loc,
					dept,
					proj,
					project,
					accession,
					PI,
					f201,
					f202,
					f203,
					f204,
					f205,
					f231,
					f219,
					f209,
					f310,
					f308,
					f311,
					f316,
					f312,
					f313,
					f314,
					f315,
					f318,
					f220,
					f22F,
					f221,
					f222,
					--f223,
					f241,
					f242,
					f243,
					f244
				)	
				SELECT 
					loc,
					dept,
					proj,
					project,
					accession,
					PI,
					f201,
					f202,
					f203,
					f204,
					f205,
					f231,
					f219,
					f209,
					f310,
					f308,
					f311,
					f316,
					f312,
					f313,
					f314,
					f315,
					f318,
					f220,
					f22F,
					f221,
					f222,
					--f223,
					f241,
					f242,
					f243,
					f244
				FROM [' + @NonAdminTableName + '];'
				
				if @IsDebug = 1 Print @CreateTableSQL;
				
				exec sp_executesql N'EXEC(@CreateTableSQL)', N'@CreateTableSQL varchar(MAX)', @CreateTableSQL
END
