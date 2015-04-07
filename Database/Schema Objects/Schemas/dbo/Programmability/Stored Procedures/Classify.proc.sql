/*
PROGRAM: Classify
BY:	Mike Ransom  (all comments Mike's unless otherwise noted)
USAGE/TEST:	
	EXEC Classify '201', 'left(Op_Fund_Num,5) in (''21005'',''21006'')'

DESCRIPTION: 

CURRENT STATUS:
NOTES:
CALLED BY: only by sp_SFN_Classify (used as a procedure call)
CLIENTS/RELATED FILES/DEPENDENCIES:
TODO LIST:
MODIFICATIONS: see bottom
*/
-------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[Classify]
	@SFN AS varchar(10),
	@Filter As varchar(max),
	@FiscalYear int = 2009,
	@IsDebug bit = 0
AS
-------------------------------------------------------------------------
declare @txtSQL as varchar(MAX)

select @txtSQL = 
'UPDATE Acct_SFN 
	set SFN = ''' + @SFN + ''', 
	SFNsCt = SFNsCt + 1, 
	SFNs = SFNs + ''' + @SFN + ' ''
WHERE (Acct_ID + Chart + Org) IN
	(SELECT distinct (Account + Chart + Org)
	FROM [FISDataMart].[dbo].[Accounts] Accounts
	WHERE ' + @Filter + ' AND (
		(Accounts.Year = ' + Convert(char(4), @FiscalYear) + ' AND Accounts.Period = ''--'')'

	IF @SFN IN ('201', '202', '203', '204', '205') 
		select @txtSQL += ' OR
		(Accounts.Year = ' + Convert(char(4), @FiscalYear + 1)+ ' AND Accounts.Period IN (''01'',''02'',''03''))'
	
	select @txtSQL += '
	  )
	)'  

	IF @IsDebug = 1
		BEGIN
			Print @txtSQL
			print '-- SFN ' + @SFN + ': ' + convert(varchar,@@RowCount)  + ' records.'
		END
	ELSE
		BEGIN
			exec (@txtSQL)
			print 'SFN ' + @SFN + ': ' + convert(varchar,@@RowCount)  + ' records.'
		END

-------------------------------------------------------------------------
/*
MODIFICATIONS:

[9/7/06] Thu
Inclusion of Org code is not needed, as Account is uniquely determined by Chart + Account (per S. Pesis). Actually, using only Cht + Acct is essential, as the value entered in the Accounts table for Org code is inconsistent--I believe that often it's not the org but the org3, and sometimes not entered (?).
[9/10/2009] by KJT
Changed to use new [FISDataMart].[dbo].[Accounts]

[3/19/2015] by kjt:
Modified to allow detection of FFY SFNs, and include the first 3 periods of the next fiscal year.

*/
