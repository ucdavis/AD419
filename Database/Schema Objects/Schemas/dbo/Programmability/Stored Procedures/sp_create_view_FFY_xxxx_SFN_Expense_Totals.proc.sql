-- =============================================
-- Author:		Ken Taylor
-- Create date: November 20, 2009
-- Description:	Virtual table of summed expenses by
-- accession number for use with sp_
-- =============================================
CREATE PROCEDURE [dbo].[sp_create_view_FFY_xxxx_SFN_Expense_Totals] 
(
	@FiscalYear char(4) = '2009',
	@IsDebug bit = 1
)
AS

BEGIN

declare @Viewname sysname
select @ViewName = 'FFY_' + @FiscalYear + '_SFN_EXPENSE_TOTALS_V'

declare @TableName sysname
select @TableName = '[dbo].[FFY_' + @FiscalYear + '_SFN_ENTRIES]'

declare @TSQL varchar(MAX) = 'IF EXISTS (SELECT * FROM sysobjects WHERE name = ''' + @ViewName + ''' AND type = ''V'')
	BEGIN
		DROP VIEW [dbo].[' + @Viewname + ']
	END
	GO';
	
IF @IsDebug = 1
	PRINT @TSQL
ELSE	
	EXEC (@TSQL)

Select @TSQL = 'CREATE VIEW [dbo].[' + @ViewName + '] AS
 select 
	   [Accession]
      ,[AwardNum]
      ,[SFN]
      ,[OrgR]
      ,Sum([ExpenseSum]) as Expenses
from ' + @TableName + '
where IsActive = 1
group by
       [Accession]
      ,[AwardNum]
      ,[SFN]
      ,[OrgR]
	';
	
IF @IsDebug = 1
	PRINT @TSQL
ELSE	
	EXEC (@TSQL)
	
END
