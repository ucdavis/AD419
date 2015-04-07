
-- =============================================
-- Author:		Ken Taylor
-- Create date: Novenber 23, 2009
-- Description:	Automate inserting of the 201, 202, and 205 expense sums
-- into Expenses and Associations.  This procedure basically builds a set of
-- EXEC usp_insertProjectExpense statements, with the associated parameter values to
-- automate the inserting the 201, 202, and 205 project expenses.
--
-- Notes: This procedure also zeros out and negative sums AND
-- deletes any 20x associations and expenses with a datasource of '20x'.
-- Lastly, this procedure selects a list of the rows that were not successfully inserted.
--
-- [12/17/2010] by kjt: Revised to use AllExpenses, table (formerly Expenses) instead of new Expenses view.
-- [10/29/2014] by kjt: Revised to handle passing of account numbers so that AD-Hoc reports would work properly.
--
-- =============================================
CREATE PROCEDURE [dbo].[sp_INSERT_20x_EXPENSE_SUMS_INTO_EXPENSES] 
	-- Add the parameters for the stored procedure here
	@FiscalYear int = 2009, 
	@IsDebug bit = 0
AS
BEGIN

declare @TableName varchar(50) = 'dbo.FFY_' + Convert(char(4), @FiscalYear) + '_SFN_ENTRIES'
declare @TSQL varchar(MAX) = null

-- Delete any existing 201, 202 or 205 associations and expenses first:
SELECT @TSQL = 'delete from Associations where ExpenseID in (select ExpenseID from Expenses where DataSource = ''20x'')
delete from AllExpenses where DataSource = ''20x''
'

	IF @IsDebug = 1
		Print @TSQL
	ELSE
		BEGIN
			Print @TSQL
			EXEC (@TSQL)
		END

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	Select @TSQL = '
declare @TSQL varchar(255) = ''''

declare @Import table(
	rownum int IDENTITY(1,1) Primary key not null,
	Accession char(7),
	SFN varchar(4),
	OrgR char(4),
	Account varchar(7),
    Expenses decimal(16,2)
    )
    '
    
Select @TSQL += '
insert into @Import (Accession, SFN, OrgR, Account, Expenses)
SELECT	 [Accession]
		,[SFN]
		,[OrgR]
		,[Account]
		,(CASE WHEN Sum(ExpenseSum) < 0 THEN 0
		 ELSE 
			Sum(ExpenseSum)
		 END)
		 as Expenses
FROM ' + @TableName + '
group by
	[Accession]
    ,[SFN]
    ,OrgR
	,Account
order by 
	 [Accession]
    ,[SFN]
    ,OrgR
	,Account
;
'

Select @TSQL += '
declare @Proc varchar(255) = ''usp_insertProjectExpenseWithAccount''
declare @RowCount int = 1
declare @MaxRows int
declare @IsDebug bit = ' + CONVERT(char(1), @IsDebug)+ '
declare @return_value int
select @MaxRows = count(*) from @Import
      
while @RowCount <= @MaxRows
	begin
		select @TSQL = ''
		EXEC '' + @Proc + '' '''''' + Convert(varchar(4), SFN) + '''''', '''''' + Convert(char(4),OrgR) + '''''', '''''' +  Convert(varchar(7),Account) + '''''', '''''' + Convert(char(7),Accession) + '''''', '' + Convert(varchar(20),Expenses) + '' '' from @Import where rownum = @RowCount 
		
		If @IsDebug = 1
			print @TSQL
		Else
			BEGIN
				print @TSQL
				EXECUTE(@TSQL)
			END
			
		Select @RowCount = @RowCount + 1
	end
	
	select * from @Import where Accession not in (
		select accession from Associations where ExpenseID in (
			select ExpenseID from Expenses where DataSource = ''20x''))
	'
	Print @TSQL
	EXEC (@TSQL)
	
END
