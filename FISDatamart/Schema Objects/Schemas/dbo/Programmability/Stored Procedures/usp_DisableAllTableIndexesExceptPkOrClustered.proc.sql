-- =============================================
-- Author:		Ken Taylor
-- Create date: January 20, 2011
-- Description:	Given a table name, disable all indexes on that single table
-- except for PK and clustered index.
--
-- Usage:
--
-- EXEC usp_DisableAllTableIndexesExceptPkOrClustered @TableName=<table_name>[, @IsDebug = 0/1]
--
-- =============================================
CREATE PROCEDURE [dbo].[usp_DisableAllTableIndexesExceptPkOrClustered] 
	-- Add the parameters for the stored procedure here
	@TableName varchar(255) = null, 
	@IsDebug bit = 0 --Set to 1 to only print SQL to be executed.
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @TSQL varchar(MAX) = ''
	DECLARE @tblName varchar(255), @IndexName varchar(255) = ''
	DECLARE MyCursor CURSOR FOR SELECT     o.name as TableName, i.name AS IndexName
	FROM         sysobjects o, sysindexes i
	WHERE   (o.id = i.id and o.name = @TableName) AND (i.status = 0)

	PRINT '--Disabling all indexes except PK or Clustered on Table: ' + @TableName + '
'
	OPEN MyCursor

	Fetch NEXT FROM MyCursor INTO @tblName, @IndexName

	WHILE (@@FETCH_STATUS <> -1)
		BEGIN
			SELECT @TSQL += 'ALTER INDEX [' + @IndexName + '] ON [dbo].[' + @TableName + '] DISABLE
'
			Fetch NEXT FROM MyCursor INTO @tblName, @IndexName
		END --WHILE

	CLOSE MyCursor
	DEALLOCATE MyCursor

	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC (@TSQL)

	END

GO
EXECUTE sp_addextendedproperty @name = N'@IsDebug', @value = N'Set to 1 to only print SQL which would be executed instead.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'PROCEDURE', @level1name = N'usp_DisableAllTableIndexesExceptPkOrClustered';


GO
EXECUTE sp_addextendedproperty @name = N'@TableName', @value = N'The name of the table to disable the indexes on.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'PROCEDURE', @level1name = N'usp_DisableAllTableIndexesExceptPkOrClustered';


GO
EXECUTE sp_addextendedproperty @name = N'Description', @value = N'Given a table name, disable all indexes on that single table except for PK and/or clustered index.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'PROCEDURE', @level1name = N'usp_DisableAllTableIndexesExceptPkOrClustered';

