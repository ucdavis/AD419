-- =============================================
-- Author:		Ken Taylor
-- Create date: November 2, 2012
-- Description:	Stored procedure to load Raw_PPS_Expenses_new from FIS Labor Transactions table since TOE is no longer an option.
-- =============================================
CREATE PROCEDURE usp_Repopulate_RawPPSExpenses_new 
	@FiscalYear varchar(4) = 2012, 
	@IsDebug bit = 0
AS
BEGIN
/*
DECLARE @FiscalYear char(4) = '2012'
DECLARE @IsDebug bit = 1
*/

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	--SET NOCOUNT ON;
DECLARE @FiscalYearInt int = CONVERT(int, @FiscalYear)
DECLARE @FiscalYearMinusOne VARCHAR(4) = (CONVERT(varchar(4), @FiscalYearInt - 1))

DECLARE @TSQL varchar(MAX) = ''
DECLARE @NumAccounts int = (SELECT DISTINCT COUNT(*) FROM FISDataMart.dbo.Accounts A INNER JOIN FISDataMart.dbo.ArcCodes AC ON A.AnnualReportCode = AC.ARCCode WHERE Year = @FiscalYearInt AND Chart = '3' AND Period = '--'  )
DECLARE @Count int = 0

SELECT @TSQL = '
TRUNCATE TABLE AD419.dbo.Raw_PPS_Expenses_new
'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)

DECLARE MyCursor CURSOR FOR SELECT DISTINCT A.Account FROM FISDataMart.dbo.Accounts A INNER JOIN FISDataMart.dbo.ArcCodes AC ON A.AnnualReportCode = AC.ARCCode WHERE A.Year = CONVERT(int, @FiscalYear) AND A.Chart = '3' AND A.Period = '--'  ORDER BY A.Account
DECLARE @AcctNum varchar(7) = ''
OPEN MyCursor
FETCH NEXT FROM MyCursor INTO @AcctNum
WHILE @@FETCH_STATUS <> -1
BEGIN
	SELECT @Count = @Count + 1
	SELECT @TSQL = '
INSERT INTO AD419.dbo.Raw_PPS_Expenses_new
select 
	MAX(TOE_NAME) TOE_NAME,
	L.EID,
	L.ORG,
	L.Account,
	L.SubAcct,
	L.ObjConsol,
	L.Object,
	L.TitleCd,
	--AC.ARCCode,
	SUM(CONVERT(MONEY, Amount)) Amount,
	--null AS Benefits,
	ROUND(SUM(CONVERT(FLOAT,PartialPercent)),4) FTE
FROM openquery(FIS_DS, ''
	SELECT  
		PERSON_NAME TOE_NAME,
		EMPLID EID,
		ORG_CD Org,
		ACCOUNT_NBR Account,
		SUB_ACCT_NBR SubAcct,
		FIN_CONS_OBJ_CD ObjConsol,
		FIN_OBJECT_CD Object,
		PPS_TITLE_CD TitleCd,
		SUM(TRN_LDGR_ENTR_AMT) Amount,
		CASE WHEN FDOC_TYP_CD = ''''PAY'''' AND FIN_CONS_OBJ_CD NOT IN (''''SB28'''', ''''SUB6'''') AND DIST_PAY_RATE > 0 THEN (SUM(TRN_LDGR_ENTR_AMT) / DIST_PAY_RATE /
		(CASE WHEN RATE_TYPE_CD = ''''H'''' THEN 173.86 ELSE 1 END )) / 12  ELSE 0 END AS PartialPercent
	FROM
		FINANCE.LABOR_TRANSACTIONS LT
	INNER JOIN 
		FINANCE.UCD_PERSON P ON LT.EMPLID = P.EMPLOYEE_ID
	WHERE 
		UNIV_FISCAL_YR = ' + @FiscalYear + '
		AND FIN_COA_CD = ''''3''''
		AND PAY_PERIOD_END_DT >= TO_DATE(' + '''''' + @FiscalYearMinusOne + '.07.01'''', ''''yyyy.mm.dd'''')
		AND FS_ORIGIN_CD NOT LIKE ''''PL''''
		--AND FINOBJ_FRNGSLRY_CD = ''''F''''
		--AND DIST_PAY_RATE <> 0
		--AND EMPLID IN ( ''''084871045'''')
		AND ACCOUNT_NBR = ' + '''''' + @AcctNum + '''''' + '
 
	GROUP BY
		PERSON_NAME,
		EMPLID,
		ORG_CD,
		ACCOUNT_NBR,
		SUB_ACCT_NBR,
		FIN_CONS_OBJ_CD,
		FIN_OBJECT_CD,
		PPS_TITLE_CD,
		FDOC_TYP_CD,
		RATE_TYPE_CD,
		DIST_PAY_RATE
'') L
--INNER JOIN FISDataMart.dbo.Accounts A ON L.Account = A.Account
--INNER JOIN FISDataMart.dbo.ArcCodes AC ON A.AnnualReportCode = AC.ArcCode
--WHERE A.Year = 2012 AND A.CHART = ''3'' AND A.Period = ''--''
GROUP BY 
	EID,
	L.ORG,
	L.Account,
	L.SubAcct,
	L.ObjConsol,
	L.Object,
	L.TitleCd
	--AC.ARCCode
HAVING
	SUM(CONVERT(FLOAT,PartialPercent)) <> 0 OR SUM(CONVERT(FLOAT,Amount)) <> 0
'

	PRINT CONVERT(varchar(10), @Count) + '. ' + @AcctNum +  ': ' + CONVERT(varchar(50), @NumAccounts - @Count) + ' of ' + CONVERT(varchar(10), @NumAccounts) + ' accounts left to go.'

	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		BEGIN
			EXEC(@TSQL)
		END

	FETCH NEXT FROM MyCursor INTO @AcctNum
END
CLOSE MyCursor
DEALLOCATE MyCursor
END