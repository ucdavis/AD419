------------------------------------------------------------------------
/*
PROGRAM: sp_Extract_Raw_PPS_Expenses
BY:	Mike Ransom
USAGE:

	EXEC sp_Extract_Raw_PPS_Expenses
	--note: [9/12/06] Tue: query still has hard-coded dates defining range of expense transfer records. This even includes the naming of the source table, e.g. "ETHTOE_V_FY_2006".

DESCRIPTION: 
	

CURRENT STATUS:
	[12/26/05] Mon, 23:32
Working correctly


NOTES:
	10363 row(s) affected, 1:39 min, after limiting TOE_TRANS_END_DATE to >= 07-01-2004.	([12/26/05] Mon, 23:32)
	(10929 row(s) affected), 1:38 min., after modifying FTE calc. [12/16/05] Fri
	11077 row(s) affected, now that I've switched to filtering by Obj Consolidation
	10683 rows, 1:41 minutes, extracting for all Cht 3, ORES and ACAD, 2005.
	10265 rows, 1:12 minutes, extracting for all Cht 3, ORES, 2005.

CALLED BY:
DEPENDENCIES: 
MODIFICATIONS: see bottom
*/
/*
*/
-------------------------------------------------------------------------
CREATE procedure [dbo].[sp_Extract_Raw_PPS_Expenses]
@FiscalYear int = 2009, -- Fiscal Year.
@BeginDate varchar(16) = '', -- The beginning of the fiscal year, i.e. for FY 2009: 2008.07.01, etc.
@IsDebug bit = 0 -- Set to 1 to just print SQL, and not actually run sproc.

AS
-------------------------------------------------------------------------
DECLARE @TSQL VarChar(MAX)

IF @BeginDate = ''
	BEGIN
		Select @BeginDate = Convert(char(4),(@FiscalYear - 1)) + '.07.01'
	END

print 'Clear current PPS TOE records...'
select @TSQL= 'DELETE FROM Raw_PPS_Expenses'
	if @IsDebug = 1
		begin
			Print @TSQL
		end
	else
		begin
			EXEC(@TSQL)
		end
--print 'Insert new records extracted from ETHTOE_V_FY_' + @FiscalYear + '...'
print 'Insert new records extracted from ETHTOE_V_FY_' + Convert(Varchar(4),@FiscalYear) + '...'
select @TSQL = 'Insert into Raw_PPS_Expenses (TOE_Name, EID, Org, Account, SubAcct, ObjConsol, TitleCd, FTE, Salary, Benefits)
SELECT * FROM OPENQUERY
	(pay_pers_extr, ''
	SELECT DISTINCT 
		Max(TOE.TOE_NAME)  TOE_NAME, 
		TOE.TOE_EMPLOYEE_ID  EID, 
		TOE.TOE_FAU_ORG_CD Org, 
		TOE.TOE_FAU_ACCT  Account, 
		TOE.TOE_FAU_SUBACCT  SubAcct, 
		TOE.TOE_FAU_OBJ_CONSOLDTN  ObjConsol, 
		TOE.TOE_TITLE  TitleCd, 
		Sum
			(DECODE	/* normalize to percent time for both salaried and hourly employees */
				(TOE_RATE_TYPE,
					''''%'''', (TOE.TOE_TIME / 100),  /* Salaried employees */
					''''H'''', (TOE.TOE_TIME / 173.86),	/* hourly employees (avg hours per month for full-time) */
					0
				)
			) / 12 FTE, 
		Sum(TOE.TOE_ORIG_GROSS_ERN)  Salary, 
		Sum(TOE.BEN_TOTAL)  Benefits
	FROM 
		ETHTOE_V_FY_' + Convert(Varchar(4),@FiscalYear) + '  TOE		/* A new table/view is created each year, so this needs to be edited each year */
	WHERE 
		TOE.FISCAL_YEAR=' + Convert(Varchar(4),@FiscalYear) + '
		AND TOE.TOE_FAU_CHART=''''3''''
		AND TOE.TOE_FAU_HIGH_ED_FUNC_CD in (''''ORES'''',''''ACAD'''')
		AND TOE.TOE_FAU_OBJ_CONSOLDTN  IN (''''SB01'''',''''SB02'''',''''SB03'''',''''SB05'''',''''SB06'''',''''SB07'''',''''SUBS'''',''''SUBG'''')
		AND ABS(DECODE
			(TOE_RATE_TYPE,
				''''%'''', TOE_RATE,
				''''H'''', TOE_RATE*173.86,
				0
			)) > 800	/* Dont know reason for this, and may not be necessary--it was in original code by Ken Paulson */
		AND TOE.TOE_TRANS_END_DATE >= TO_DATE(''''' + @BeginDate  + ''''' ,''''yyyy.mm.dd'''') /* cuts out retroactive pay actions effective before reporting year */
	GROUP BY 
		TOE.TOE_EMPLOYEE_ID, 
		TOE.TOE_TITLE,
		TOE.TOE_FAU_ORG_CD, 
		TOE.TOE_FAU_ACCT, 
		TOE.TOE_FAU_SUBACCT, 
		TOE.TOE_FAU_OBJ_CONSOLDTN
	ORDER BY 
		Max(TOE.TOE_NAME)
	''	)'
	
	if @IsDebug = 1
		begin
			-- For debugging
			Print @TSQL
		end
	else
		begin
			--Execute the command:
			EXEC(@TSQL)
		end

-------------------------------------------------------------------------
-- MODIFICATIONS:
/*
[10/17/05] Mon created.
used during devel:
	WHERE 
		...
		and TOE.TOE_FAU_ORG_CD=''AVIT''

[10/19/05] Wed 
	Removed limit on Org (was 'AVIT' to speed devel), changed name of target table to PPS_TOE_Raw
	10265 rows, 1:12 minutes, extracting for all Cht 3, ORES, 2005.

[10/20/05] Thu Added ACADs.
	10683 rows, 1:41 minutes, extracting for all Cht 3, ORES and ACAD, 2005.

	EXEC sp_Expenses_PPS_Extract

[10/26/05] Wed
	In WHERE clause, replaced
		TOE.TOE_DOS In (''REG'',''SLN'',''SLR'',''FYS'',''FYO'',''OSC'',''OLM'',''OLN'',''STP'',''HST'',''RTP'')
	with
		TOE.TOE_FAU_OBJ_CONSOLDTN  IN (''SB01'',''SB02'',''SB03'',''SB05'',''SB06'',''SB07'',''SUBS'',''SUBG'')
	We found that discrepancies between FIS and PPS were being caused by missing DOS CODES such as HST (HSCP REG COMP-RET (T)) and RTP (REDUCTION IN TIME PROGRAM). Discussed with Steve. I saw that we might be able to use CTLDOS.DOS_PAY_CATEGORY, as all the records we wanted seemed to have a code of "N" in this field.  Steve suggested using certain Object Consolidation codes, then later, anything that had transfer amounts in ETHTOE_V_FY_2005.TOE_ORIG_GROSS_ERN.  But I determined that the latter was picking up a few DOS codes we didn't want, such as VAC.  It looks like there could be some coding problems in the TOE table.  It's really probably a view, and it certainly isn't normalized data--much of waht we're talking about are really values associated with the accounts table.


	[12/16/05] Fri
Modified to fix incorrect FTE calculation.  Requires using a DECODE in both the SELECT and the WHERE clauses.

Previously, I just totalled the FTE over the entire year and divided by 12 to get the avg. FTE.  Problem was that some (many) of the pay records are on an hourly rate basis.  RATE_TYPE indicates '%' or 'H'.  If %, then TOE_TIME represents the pay record's percentage of full time; if H, it represents the hours worked.  To normalize FTE to a fraction value, the percentages need to be divided by 100, and the hourly total by the # of hours there would be, on the average, for a full-time month.  Which 173.86 hours, on average.  The hours worked per 173.86 is the fraction of a full-time month.  Once normalized, the sum has to be divided by 12 to get the annual average.

There is a funny little limit on minimum pay rates considered.  This is copied from what Ken Paulson used, but neither Steve nor I could see a reason to do this.  It doesn't seem that it would eliminate any pay, since $800/month (or $4/hr. in Ken's code) would is below minimum wage

	[12/26/05] Mon, 23:32
A number of employees had FTE and Salary amounts that were wildly high.  I've traced it back to what appears to be retroactive pay transactions.  There is a column named TOE_TRANS_END_DATE which contains what appears to be an "effective date" for the tranaction. Adding the following WHERE condition...
	AND TOE.TOE_TRANS_END_DATE >= TO_DATE(''07-01-2004'',''MM,DD-YYYY'')
eliminates the unwanted records and seems to give reasonable numbers.  For the first case I tested, Barry Wilson, there were something like 98 pay records for FP 03 alone; the dates went back to 2001 I think.

---------------------------------------------------------------------
	[9/12/06] Tue
Run today after editing date and FY values for 05-06 cycle.  A veritable miracle compared with previous years. No muss, no fuss.

[9/10/2009] by KJT:
Revised to use new FISDataMart database.
*/
