-- =============================================
-- Author:		Ken Taylor
-- Create date: January 20, 2009
-- Description:	Automate inserting of the CABA associations
-- into Associations.  This procedure basically builds a set of
-- insert statements, with the associated parameter values to
-- automate the inserting the CABA project expense associations.
--
-- Notes: This procedure also zeros out and negative sums AND
-- changes the association OrgR from CABA to ABAE,
-- plus updates the corresponding expense's "isAssociated" bit to 1.
-- This sproc also deletes any unassociated expense that have an OrgR of ABML, AFDS, ALAB, and USDA.
-- We leave the ADNO expenses unassociated.
-- =============================================
CREATE PROCEDURE [dbo].[sp_INSERT_CABA_EXPENSES_INTO_ASSOCIATIONS] 
	-- Add the parameters for the stored procedure here
	@AssociationsAccession varchar(7) = '0067546', -- Typically all CABA expenses can be associated with a
												   -- single project.
	@ExpensesOrgR varchar(4) = 'CABA', -- This is the OrgR to search for in the expenses table.
	@AssociationsOrgR varchar(4) = 'ABAE', -- This is the OrgR to associate with the expense's association.
	@IsDebug bit = 0 -- Set this to 1 to print the SQL only.
AS
BEGIN

declare @TableName varchar(50) = 'dbo.Expenses'
declare @TSQL varchar(MAX) = null

-- Delete any unassociated expenses not in ADNO, CABA, or AGAD first:
select @TSQL = 'delete from Expenses where isAssociated = 0 AND OrgR in (''ABML'', ''AFDS'', ''ALAB'', ''USDA'') '
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
declare @TSQL varchar(MAX) = ''''

declare @Import table(
    rownum int identity Primary key not null,
	ExpenseID int ,
	Accession char(7),
	OrgR char(4),
	FTE decimal(16,4),
    Expenses decimal(16,2)
    )
    '
    
Select @TSQL += '
insert into @Import (ExpenseID, Accession, OrgR, FTE, Expenses)
SELECT	 ExpenseID
		,''' + @AssociationsAccession + ''' as Accession
		,''' + @AssociationsOrgR + ''' as OrgR
		,FTE,
		 (CASE WHEN Expenses < 0 THEN 0
		 ELSE 
			Expenses
		 END)
		 as Expenses
FROM ' + @TableName + '
WHERE OrgR = ''' + @ExpensesOrgR + ''' AND isAssociated = 0
group by
	[ExpenseID]
    ,OrgR
    ,FTE
    ,Expenses
order by 
	[ExpenseID]
	,Accession
    ,OrgR
    ,FTE
    ,Expenses
;
'

Select @TSQL += '
declare @RowCount int = 1
declare @MaxRows int
declare @IsDebug bit = ' + CONVERT(char(1), @IsDebug)+ '
declare @return_value int
select @MaxRows = count(*) from @Import
      
while @RowCount <= @MaxRows
	begin
		select @TSQL = ''
		insert into Associations (ExpenseID, Accession, OrgR, FTE, Expenses)
		values ('' + Convert(varchar(20), ExpenseID) + '', '''''' + Convert(char(7), Accession) + '''''', '''''' + Convert(char(4),OrgR) + '''''', '' + Convert(varchar(20),FTE) + '', '' + Convert(varchar(20),Expenses) + '');
		UPDATE Expenses SET isAssociated = 1 WHERE ExpenseID = '' + Convert(varchar(20), ExpenseID) + '';
		'' from @Import where rownum = @RowCount 

		If @IsDebug = 1
			print @TSQL
		Else
			BEGIN
				print @TSQL
				EXECUTE(@TSQL)
			END
			
		Select @RowCount = @RowCount + 1
	end
	
	'
	
	Print @TSQL
	EXEC (@TSQL)
END
