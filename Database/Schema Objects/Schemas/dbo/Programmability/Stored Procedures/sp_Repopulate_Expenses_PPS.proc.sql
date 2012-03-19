------------------------------------------------------------------------
/*
PROGRAM: sp_Repopulate_Expenses_PPS
BY:	Mike Ransom
USAGE:	

	EXEC sp_Repopulate_Expenses_PPS

DESCRIPTION: 

CURRENT STATUS:
[10/26/05] Wed
Re-run after modifying sp_Extract_Raw_PPS_Expenses to go by Obj_Consol instead of DOS codes. 9193 row(s) now.


NOTES:
(9193 row(s) affected) (twice), 287 rows of JV expenses. Total 3:19 minutes

CALLED BY:
DEPENDENCIES: 
MODIFICATIONS: see bottom
*/
-------------------------------------------------------------------------
--IF NOT EXISTS (select * from sys.objects where object_id = object_id(N'[sp_Repopulate_Expenses_PPS]') and type in (N'P', N'PC'))
CREATE procedure [dbo].[sp_Repopulate_Expenses_PPS]
-- Parameters:
@FiscalYear int = 2009,
@IsDebug bit = 0

AS

declare @TSQL varchar(MAX) = null
-------------------------------------------------------------------------
BEGIN
-- Drop and repopulate expenses from Expenses_PPS

--Drop:
print '--Deleting all records from Expenses_PPS...'
Select @TSQL = 'DELETE FROM Expenses_PPS;
'
--(18539 row(s) affected)

	if @IsDebug = 1
		begin
			Print @TSQL
		end
	else
		begin
			EXEC(@TSQL)
		end
		
-------------------------------------------------------------------------
--Repopulate:
print '--Repopulating Expenses_PPS from raw PPS extract:'

--Salary...
print '--Adding Salary expenses...'
Select @TSQL = 'INSERT INTO Expenses_PPS
	(
	Org_R,
	Employee_ID,
	TOE_NAME,
	TitleCd,
	Account,
	SubAcct,
	ObjConsol,
	Expenses,
	FTE
	)
SELECT 
	OrgR.OrgR Org_R,
	TOE.EID,
	TOE.TOE_NAME,
	TOE.TitleCd,
	TOE.Account,
	TOE.SubAcct,
	TOE.ObjConsol,
	TOE.Salary as Expenses,
	TOE.FTE
FROM 
	Raw_PPS_Expenses AS TOE 
	LEFT JOIN FISDataMart.dbo.Accounts AS A ON TOE.Account = A.Account
	AND A.Year = ' + CONVERT(char(4), @FiscalYear) + '
	AND A.Period = ''--''
	LEFT JOIN OrgXOrgR AS OrgR ON A.Org = OrgR.Org 
	LEFT JOIN [FISDataMart].[dbo].[ARCCodes] AS ARCs ON A.AnnualReportCode = ARCs.[ARCCode]
WHERE 
	A.Chart = ''3''
	AND OrgR.Chart = ''3''
	AND A.Year = ' + Convert(char(4), @FiscalYear) + '
	AND A.Period = ''--''
	--AND ARCs.isAES<>0 -- No longer need this because I am using a view that only gets the isAES <> 0 records.
	;'
	--(8650 row(s) affected)
	
	if @IsDebug = 1
		begin
			Print @TSQL
		end
	else
		begin
			EXEC(@TSQL)
		end
		
--Benefits...
print '--Adding benefits expenses...'

select @TSQL = 'INSERT INTO Expenses_PPS
	(
	Org_R,
	Employee_ID,
	TOE_NAME,
	TitleCd,
	Account,
	SubAcct,
	ObjConsol,
	Expenses,
	FTE
	)
SELECT 
	OrgR.OrgR Org_R,
	TOE.EID,
	TOE.TOE_NAME,
	TOE.TitleCd,
	TOE.Account,
	TOE.SubAcct,
	''SUB6'' as ObjConsol,
	TOE.Benefits as Expenses,
	null as FTE
FROM 
	Raw_PPS_Expenses AS TOE 
	LEFT JOIN FISDataMart.dbo.Accounts AS A ON TOE.Account = A.Account 
	AND A.Year = ' + CONVERT(char(4), @FiscalYear) + '
	AND A.Period = ''--''
	LEFT JOIN OrgXOrgR AS OrgR ON A.Org = OrgR.Org 
	LEFT JOIN [FISDataMart].dbo.ARCCodes AS ARCs ON A.AnnualReportCode = ARCs.ARCCode
WHERE 
	A.Chart = ''3''
	AND OrgR.Chart = ''3''
	AND A.Year = ' + Convert(char(4), @FiscalYear) + '
	AND A.Period = ''--''
	--AND ARCs.isAES<>0 -- No longer need this because I am using a view that only gets the isAES <> 0 records.
	;'
	
	--(8650 row(s) affected)
	
	if @IsDebug = 1
		begin
			Print @TSQL
		end
	else
		begin
			EXEC(@TSQL)
		end

-------------------------------------------------------------------------
-- Create the new Raw_FIS_JV_Expenses, which the Expenses_FIS_JV uses:
print '--Executing the [dbo].[usp_Create_Raw_FIS_JV_Expenses] script...
'
select @TSQL = 'EXEC usp_Create_Raw_FIS_JV_Expenses @FiscalYear = ''' + CONVERT(char(4), @FiscalYear) + ''' '
	if @IsDebug = 1
		begin
			Print @TSQL
		end
	else
		begin
			EXEC(@TSQL)
		end
-------------------------------------------------------------------------
-- Insert Journal Voucher ("JV") expenses:
print '--Inserting Journal Voucher ("JV") expenses into Expenses_PPS from FIS extract...'
select @TSQL = 'INSERT INTO Expenses_PPS
SELECT 
	Org_R,
	''JV Expn'',
	'' JV Employee Expenses'' as Name,
	''Unkn'' as TitleCd,
	Account,
	SubAccount,
	ObjConsol,
	Expenses,
	null as FTE
FROM 
	Expenses_FIS_JV(' + Convert(char(4), @FiscalYear) + ')
	;'

	--(278 row(s) affected)

	if @IsDebug = 1
		begin
			Print @TSQL
		end
	else
		begin
			EXEC(@TSQL)
		end
		
-------------------------------------------------------------------------
--Delete all expenses with negative EID subtotals:
--[12/7/05] Commented out after discussion with Steve. He agreed with the reasoning below.

	/*
		--(23 row(s) affected, 2005)
		--Note: [12/7/05] I have misgivings about even doing this step.  What matters is that *Projects* doen't end up with negative associated expenses.  Project expenses can, and often do come from different accounts, plus their negative expenses (credits) on the FIS side could be offsetting expenses on the PPS (salary) side.  Also, the "PPS reversal" procedure has expenses from PPS which very closely match the FIS side; this could be thrown off if the FIS were artificially reduced (expecially if the same thing isn't done on the PPS side, which it isn't.  PPS side eliminates "negative expenses at the EID aggregation level, which also doen'st match.  Finally, on the "back side"--after user associations--I believe there is code to eliminate negative expense reporting at Project level.
		--Note: [12/7/05] Currently coded as one-way street--once deleted from Expenses_CAES, you won't be able to extract them again without re-running FIS extract.  Actually, I'm going to comment out for now the clearing out of Negative_Accounts_Archive.
		-- Note: [12/7/05] 
	--get most recent year in deleted archive
	DECLARE @MaxYear as int
	SET @MaxYear = (SELECT MAX(FYr) from Negative_Employee_Archive)
	set @MaxYear = isnull(@MaxYear, 2005)	--A little different from other isNull functions (i.e. nonstandard). 2nd param reqd.
		--DELETE FROM Negative_Accounts_Archive WHERE FYr LIKE @MaxYear
	--extract & archive negative accounts:
	INSERT INTO Negative_Employee_Archive
		SELECT
			@MaxYear as FYr,
			Employee_ID as EID,
			sum(Expenses) as Salary,
			sum(FTE) as FTE
		FROM 
			Expenses_PPS
		GROUP BY
			Employee_ID
		HAVING sum(Expenses)<0 or sum(FTE)<0-- Remove all expenses for negative accounts
		--Commented out until I get confirmation that we should really do this.  I don't want to.
		--DELETE FROM Expenses_PPS WHERE Account IN (SELECT Account FROM Negative_Accounts_Archive)
	*/
END
-------------------------------------------------------------------------
/*
USAGE:	
	EXEC sp_Repopulate_Expenses_PPS

MODIFICATIONS:

[10/26/05] Wed
Re-run after modifying sp_Extract_Raw_PPS_Expenses to go by Obj_Consol instead of DOS codes. 9193 row(s) now.

*/
