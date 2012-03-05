-- =============================================
-- Author:		Ken Taylor
-- Create date: January 11, 2011
-- Description:	Create a view of the All_UnassociatedTotals table so that 
-- the AD419_UnassociatedTotals report will have a data source.
-- =============================================
CREATE PROCEDURE usp_CreateAD419_UnassociatedTotalsView 
	-- Add the parameters for the stored procedure here
	@AllTableNamePrefix varchar(10) = 'All',
	@UnassociatedTotalsTableName varchar(255) = 'UnassociatedTotals',
	@FinalReportTablesNamePrefix varchar(10) = 'AD419_',
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	DECLARE @TSQL varchar(MAX) = ''
    
   IF  EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[' + @FinalReportTablesNamePrefix + @UnassociatedTotalsTableName + ']'))
		BEGIN
			SELECT @TSQL = '
	DROP VIEW [dbo].[' + @FinalReportTablesNamePrefix + @UnassociatedTotalsTableName + ']
	'
			IF @IsDebug = 1 PRINT @TSQL
			
			EXEC(@TSQL)
		END

	SELECT @TSQL = '
	CREATE VIEW [dbo].[' + @FinalReportTablesNamePrefix + @UnassociatedTotalsTableName + ']
	AS
	SELECT     TOP (100) PERCENT SFN, ProjCount, UnassociatedTotal, ProjectsTotal
	FROM         [dbo].[' + @AllTableNamePrefix + '_' + @UnassociatedTotalsTableName + ']
	'
	
	IF @IsDebug = 1 PRINT @TSQL
	
	EXEC(@TSQL)
	
END

