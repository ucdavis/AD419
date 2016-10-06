﻿-- =============================================
-- Author:		Ken Taylor
-- Create date: December 22, 2009
-- Description:	Automate inserting of the CES expenses
-- into CESXProjects.  This procedure basically builds a set of
-- EXEC usp_insertCES statements, with the associated parameter values to
-- automate the inserting the CE project expenses.
-- Usage:
/*
USE [AD419]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[sp_INSERT_CE_EXPENSES_INTO_CESXProjects]
		@FiscalYear = 2015,
		@TableName = N'CES_List_V',
		@IsDebug = 0

SELECT	'Return Value' = @return_value

GO
*/
-- Modifications:
-- 2016-08-02 by kjt: Added logic to also set Chart, Account and SubAccount. 
-- 2016-08-21 by kjt: Added EXCEPT so rows wouldn't get reinserted upon running
-- procedure after the first time.
-- =============================================
CREATE PROCEDURE [dbo].[sp_INSERT_CE_EXPENSES_INTO_CESXProjects] 
	-- Add the parameters for the stored procedure here
	@FiscalYear int = 2009, 
	@TableName varchar(50) = 'dbo.CES_List_V', -- This is the name of the table from which
												  -- you want to "import" the CES list data from.
	@IsDebug bit = 0
AS
BEGIN

declare @TSQL varchar(MAX) = null

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	Select @TSQL = '
declare @TSQL varchar(255) = ''''

declare @Import table(
	rownum int IDENTITY(1,1) Primary key not null,
	EmployeeID varchar(9),
	PI_FullName varchar(50),
	TitleCode varchar(4),
	Accession char(7),
	Chart varchar(2),
	OrgR char(4),
	Account varchar(7),
	SubAccount varchar(5),
	PctEffort float,
    CESSalaryExpenses float,
    PctFTE tinyint
    )
    '
    
Select @TSQL += '
insert into @Import (EmployeeID, PI_FullName, TitleCode, Accession, Chart, OrgR, Account, SubAccount, PctEffort, CESSalaryExpenses, PctFTE)
SELECT	 [EmployeeID]
		,PI_FullName
		,TitleCode
		,Accession
		,Chart
		,OrgR
		,Account
		,SubAccount
		,PctEffort
		,CESSalaryExpenses
		,PctFTE
FROM ' + @TableName + '
group by
	[EmployeeID]
    ,Accession
	,Chart
    ,OrgR
	,Account
	,SubAccount
    ,PI_FullName
    ,TitleCode
    ,PctEffort
	,CESSalaryExpenses
	,PctFTE
EXCEPT
	SELECT
	    t1.EID [EmployeeID]
		,AccountPIName PI_FullName
		,Title_Code TitleCode
		,Accession
		,Chart
		,OrgR
		,Account
		,SubAccount
		,PctEffort
		,CESSalaryExpenses
		,PctFTE
FROM
	CESXProjects t1 INNER JOIN 
	CESList t2 ON t1.EID = t2.EID
group by
	t1.EID
    ,Accession
	,Chart
    ,OrgR
	,Account
	,SubAccount
    ,AccountPIName
    ,Title_Code
    ,PctEffort
	,CESSalaryExpenses
	,PctFTE
order by 
	 [EmployeeID]
    ,Accession
	,Chart
    ,OrgR
	,Account
	,SubAccount
    ,PI_FullName
    ,TitleCode
    ,PctEffort
	,CESSalaryExpenses
	,PctFTE
;
'
Select @TSQL += '
declare @Proc varchar(255) = ''usp_insertCES''
declare @RowCount int = 1
declare @MaxRows int
declare @IsDebug bit = ' + CONVERT(char(1), @IsDebug)+ '
declare @return_value int
select @MaxRows = count(*) from @Import
     
while @RowCount <= @MaxRows
	begin
		select @TSQL = ''
		EXEC '' + @Proc + '' 
		'''''' + Convert(varchar(9), EmployeeID) + '''''',
		['' + Convert(varchar(50), PI_FullName) + ''],
		'''''' + Convert(varchar(4), TitleCode) + '''''',
		'''''' + Convert(varchar(7), Accession) + '''''',
		'''''' + Convert(char(4),OrgR) + '''''', 
		'' + Convert(varchar(10),PctEffort) + '' ,
		'' + Convert(varchar(20),CESSalaryExpenses) + '',
		'' + Convert(varchar(10),PctFTE) + '',
		'''''' + Convert(varchar(2),Chart) + '''''', 
		'''''' + Convert(varchar(7),Account) + '''''', 
	    '' + CASE WHEN SubAccount IS NOT NULL THEN '''' +  QUOTENAME(Convert(varchar(5),SubAccount),'''''''') + '''' ELSE  ''NULL'' END + ''
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
