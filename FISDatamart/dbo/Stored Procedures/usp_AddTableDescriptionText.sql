-- =============================================
-- Author:		Ken Taylor
-- Create date: March 13, 2013
-- Description:	Allows for parameterized updates or additions to the given table's description
/*
-- Usage:
EXEC	@return_value = [dbo].[usp_AddTableDescriptionText]
		@TableName = N'Accounts',
		@DescriptionText = N'This is my account desc.',
		@IsDebug = 1
*/
-- =============================================
CREATE PROCEDURE [dbo].[usp_AddTableDescriptionText]
	-- Add the parameters for the stored procedure here
	@DatabaseName varchar(100)= 'FISDataMart',
	@SchemaName varchar(50) = 'dbo', 
	@TableName varchar(256) = '',
	@ColumnName varchar(256) = '',
	@DescriptionText varchar(2048) = '',
	@IsDebug bit = 0 --1 to print generated SQL only; 0 to execute generated SQL statement.
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @TSQL varchar(MAX) = '
EXEC ' + @DatabaseName + '.sys.sp_addextendedproperty
     @name = N''MS_Description''
     , @value = N''' + @DescriptionText + '''
     , @level0type = N''SCHEMA''
     , @level0name = N''' +  @SchemaName + '''
     , @level1type = N''TABLE''
     , @level1name = N''' + @TableName + '''
'
 
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC (@TSQL)
END