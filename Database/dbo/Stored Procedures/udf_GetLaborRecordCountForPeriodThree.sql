  --=====================================================================
  -- Author: Ken Taylor
  -- Created On: September 3,2021
  -- Description: Given the ending year, returns the number of combined records in UCPath labor tables
  --	for the final period (3) of the Federal Fiscal Year, .e. for FFY 2021, returns the record for
  --	period 03 of fiscal year 2022.  This is used with checking if the AnotherLaborTransactions table
  --	needs to be loaded for a particular reporting year.
  -- Usage:
  /*

	DECLARE @Return_value int, @NumRecsOut int,
		@FiscalYear int = 2021, @IsDebug bit = 0 

	EXEC @Return_Value = udf_GetLaborRecordCountForPeriodThree
		@FiscalYear = @FiscalYear,
		@IsDebug = @IsDebug,
		@NumRecs = @NumRecsOut OUTPUT

	IF @IsDebug = 0
		SELECT 'NumRecs' = @NumRecsOut, 'Return_value' = @Return_Value
	GO

  */
  -- Modifications:
  --
   --=====================================================================
   CREATE Procedure udf_GetLaborRecordCountForPeriodThree
   (
		@FiscalYear int = 2021,
		@IsDebug bit = 0,
		@NumRecs int OUTPUT
   )
   AS 
BEGIN
   SET NOCOUNT ON

  -- DECLARE @FiscalYear int = 2022
   DECLARE @AllRecs int, @ProvRecs int

   DECLARE @TSQL varchar(MAX) = ''

   DECLARE @Statement nvarchar(MAX) = ''
   
   SELECT @Statement = 'SELECT @AllRecsParam = (SELECT NUM_RECS
   FROM OPENQUERY([FIS_BISTG_PRD (CAES_HCMODS_APPUSER)], ''
   SELECT SUM(Num_recs) NUM_RECS
    FROM (
		SELECT 
			COUNT(*) num_recs
		FROM CAES_HCMODS.PS_UC_LL_SAL_DTL_V t1
		INNER JOIN CAES_HCMODS.UCD_OBJECT_CODES_V t2 ON 
			SUBSTR(t1.ACCOUNT,3,4) = t2.FIN_OBJECT_CD AND 
			t1.OPERATING_UNIT = t2.FIN_COA_CD AND 
			t1.Fiscal_Year = t2.UNIV_FISCAL_YR 
		WHERE OPERATING_UNIT IN (''''3'''',''''L'''') AND
			(
					t1.FISCAL_YEAR = ' + CONVERT(char(4), @FiscalYear + 1) + '  AND 
					t1.ACCOUNTING_PERIOD = 3 
			) AND
			t1.BUSINESS_UNIT IN (''''DVCMP'''',''''UCANR'''') AND
			t1.DML_IND <> ''''D'''' AND
			SUBSTR(t1.ACCOUNT,3,4) NOT IN (''''INC0'''', ''''BLSH'''', ''''SB74'''', ''''SUB9'''') 

UNION ALL
		SELECT 
			COUNT(*) num_recs
		FROM CAES_HCMODS.PS_UC_LL_FRNG_DTL_V t1
		INNER JOIN CAES_HCMODS.UCD_OBJECT_CODES_V t2 ON 
			SUBSTR(t1.ACCOUNT,3,4) = t2.FIN_OBJECT_CD AND 
			t1.OPERATING_UNIT = t2.FIN_COA_CD AND 
			t1.Fiscal_Year = t2.UNIV_FISCAL_YR 
		WHERE OPERATING_UNIT IN (''''3'''',''''L'''') AND
			(
					t1.FISCAL_YEAR = ' + CONVERT(char(4), @FiscalYear + 1) + '  AND 
					t1.ACCOUNTING_PERIOD = 3 
			) AND
			t1.BUSINESS_UNIT IN (''''DVCMP'''',''''UCANR'''') AND
			t1.DML_IND <> ''''D'''' AND
			SUBSTR(t1.ACCOUNT,3,4) NOT IN (''''INC0'''', ''''BLSH'''', ''''SB74'''', ''''SUB9'''') 

) t1
'') t1
)'
	DECLARE @Params nvarchar(200) = N'@AllRecsParam int OUTPUT'
	EXEC sp_executesql @Statement, @Params, @AllRecsParam = @AllRecs OUTPUT
	IF @IsDebug = 1
		SELECT 'All Recs' = @AllRecs

	IF @AllRecs > 0
	BEGIN

	SELECT @Statement = 'SELECT @ProvRecsParam = (
	   SELECT COUNT(*) NumRecs 
	   FROM OPENQUERY([FIS_BISTG_PRD (CAES_HCMODS_APPUSER)], ''
	   SELECT *
		FROM (
			SELECT 
				t1.FISCAL_YEAR "Year",
				t1.ACCOUNTING_PERIOD "Period",
				t1.OPERATING_UNIT "Chart",
				SUBSTR(DEPTID_CF,3, 7) "Account"
			FROM CAES_HCMODS.PS_UC_LL_SAL_DTL_V t1
			INNER JOIN CAES_HCMODS.UCD_OBJECT_CODES_V t2 ON 
				SUBSTR(t1.ACCOUNT,3,4) = t2.FIN_OBJECT_CD AND 
				t1.OPERATING_UNIT = t2.FIN_COA_CD AND 
				t1.Fiscal_Year = t2.UNIV_FISCAL_YR 
			WHERE OPERATING_UNIT IN (''''3'''',''''L'''') AND
				(
						t1.FISCAL_YEAR = ' + CONVERT(char(4), @FiscalYear + 1) + '  AND 
						t1.ACCOUNTING_PERIOD = 3 
				) AND
				t1.BUSINESS_UNIT IN (''''DVCMP'''',''''UCANR'''') AND
				t1.DML_IND <> ''''D'''' AND
				SUBSTR(t1.ACCOUNT,3,4) NOT IN (''''INC0'''', ''''BLSH'''', ''''SB74'''', ''''SUB9'''') 

	UNION ALL
			SELECT 
				t1.FISCAL_YEAR "Year",
				t1.ACCOUNTING_PERIOD "Period",
				t1.OPERATING_UNIT "Chart",
				SUBSTR(DEPTID_CF,3, 7) "Account"
			FROM CAES_HCMODS.PS_UC_LL_FRNG_DTL_V t1
			INNER JOIN CAES_HCMODS.UCD_OBJECT_CODES_V t2 ON 
				SUBSTR(t1.ACCOUNT,3,4) = t2.FIN_OBJECT_CD AND 
				t1.OPERATING_UNIT = t2.FIN_COA_CD AND 
				t1.Fiscal_Year = t2.UNIV_FISCAL_YR 
			WHERE OPERATING_UNIT IN (''''3'''',''''L'''') AND
				(
						t1.FISCAL_YEAR = ' + CONVERT(char(4), @FiscalYear + 1) + '  AND 
						t1.ACCOUNTING_PERIOD = 3 
				) AND
				t1.BUSINESS_UNIT IN (''''DVCMP'''',''''UCANR'''') AND
				t1.DML_IND <> ''''D'''' AND
				SUBSTR(t1.ACCOUNT,3,4) NOT IN (''''INC0'''', ''''BLSH'''', ''''SB74'''', ''''SUB9'''') 

	) t1
	'') t1

	--GROUP BY Year, Period
	 INNER JOIN 
		  (
			SELECT CHART_NUM, ACCT_NUM, ANNUAL_REPORT_CODE, ORG_ID
			FROM OPENQUERY([FIS_DS], ''
				SELECT A.CHART_NUM, A.ACCT_NUM, A.ANNUAL_REPORT_CODE, A.ORG_ID
				FROM FINANCE.ORGANIZATION_ACCOUNT A
				WHERE A.FISCAL_YEAR = 9999 AND 
					A.FISCAL_PERIOD = ''''--'''' AND
					A.HIGHER_ED_FUNC_CODE  LIKE ''''PROV'''' 
			'')
		   ) t2 ON t1.Chart =  t2.CHART_NUM AND
				Account = t2.ACCT_NUM
	)'

	SELECT @Params  = N'@ProvRecsParam int OUTPUT'
	EXEC sp_executesql @Statement, @Params, @ProvRecsParam = @ProvRecs OUTPUT
	SELECT 'Prov Recs' = @ProvRecs

		IF @IsDebug = 1
			SELECT @TSQL = 'SELECT ' + CONVERT(varchar(10), @AllRecs - @ProvRecs) + ' AS ''Num Recs for Fiscal Year ' + CONVERT(char(4), @FiscalYear + 1) + ', Period 3:'''
	END
	ELSE
		BEGIN
			SELECT @ProvRecs = 0
			IF @IsDebug = 1
				SELECT @TSQL = 'SELECT ' + CONVERT(varchar(10), @ProvRecs) + ' AS '' Num Recs for Fiscal Year ' + CONVERT(char(4), @FiscalYear + 1) + ', Period 3:'''
		END

	EXEC(@TSQL)
	SELECT @NumRecs = (@AllRecs - @ProvRecs)

END			
/*
Year	Period	NumRecs
2021	3	399,698 --NOT LIKE ''PROV''
2021	3	377	-- LIKE ''PROV''
2021	3	400,075 -- all records.
*/