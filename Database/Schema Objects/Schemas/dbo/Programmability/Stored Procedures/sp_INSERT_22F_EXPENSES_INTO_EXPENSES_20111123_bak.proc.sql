﻿-- =============================================
-- Author:		Ken Taylor
-- Create date: December 21, 2009
-- Description:	Automate inserting of the 22F expenses
-- into Expenses and Associations.  This procedure basically builds a set of
-- EXEC usp_insertProjectExpense statements, with the associated parameter values to
-- automate the inserting the 201, 202, and 205 project expenses.
--
-- Notes: This procedure also zeros out and negative sums AND
-- deletes any 20x associations and expenses with a datasource of '20x'.
-- Lastly, this procedure selects a list of the rows that were not successfully inserted.
--
--[12/17/2010] by kjt: Revised to use AllExpenses, table (formerly Expenses) instead of new Expenses view.
--
-- =============================================
CREATE PROCEDURE [dbo].[sp_INSERT_22F_EXPENSES_INTO_EXPENSES_20111123_bak] 
	-- Add the parameters for the stored procedure here
	@FiscalYear int = 2009, 
	@IsDebug bit = 0
AS
BEGIN

declare @TableName varchar(50) = 'dbo.Expenses_Field_Stations'
declare @TSQL varchar(MAX) = null

-- Delete any existing 22F associations and expenses first:
select @TSQL = 'delete from Associations where ExpenseID in (select ExpenseID from Expenses where DataSource = ''22F'')'
If @IsDebug = 1
			print @TSQL
		Else
			BEGIN
				print @TSQL
				EXECUTE(@TSQL)
			END
select @TSQL = 'delete from AllExpenses where DataSource = ''22F'' '
If @IsDebug = 1
			print @TSQL
		Else
			BEGIN
				print @TSQL
				EXECUTE(@TSQL)
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
    Expenses decimal(16,2),
    PI_Name varchar(50)
    )
    '
    
Select @TSQL += '
insert into @Import (Accession, SFN, OrgR, PI_Name, Expenses)
SELECT	 [Accession]
		,''22F'' as SFN
		,[Org_R] OrgR
		,Project_Leader as PI_Name,
		 (CASE WHEN Sum(Expense) < 0 THEN 0
		 ELSE 
			Sum(Expense)
		 END)
		 as Expenses
FROM ' + @TableName + '
group by
	[Accession]
    ,Org_R
    ,Project_Leader
order by 
	 [Accession]
    ,Org_R
    ,Project_Leader
;
'

Select @TSQL += '
declare @Proc varchar(255) = ''usp_insert22FProjectExpense''
declare @RowCount int = 1
declare @MaxRows int
declare @IsDebug bit = ' + CONVERT(char(1), @IsDebug)+ '
declare @return_value int
select @MaxRows = count(*) from @Import
      
while @RowCount <= @MaxRows
	begin
		select @TSQL = ''
		EXEC '' + @Proc + '' '''''' + Convert(varchar(4), SFN) + '''''', '''''' + Convert(char(4),OrgR) + '''''', '''''' + Convert(char(7),Accession) + '''''', '''''' + Convert(varchar(50),PI_Name) + '''''', '' + Convert(varchar(20),Expenses) + '' '' from @Import where rownum = @RowCount 
		
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
			select ExpenseID from Expenses where DataSource = ''22F''))
	'
	
	Print @TSQL
	EXEC (@TSQL)
END