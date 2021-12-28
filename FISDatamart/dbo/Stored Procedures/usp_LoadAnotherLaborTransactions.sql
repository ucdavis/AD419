

-- =============================================
-- Author:		Ken Taylor
-- Create date: October 9, 2020
-- Description:	Loads the AnotherLaborTransactions table so we can later use it for figuring out
-- the labor portion of the expenses,  Note that this version uses UC Path as the data source.
-- Usage:
/*

USE [FISDataMart]
GO

DECLARE	@return_value int, @IsDebug bit = 1

SET NOCOUNT ON;
EXEC	@return_value = [dbo].[usp_LoadAnotherLaborTransactions]
		@FiscalYear = 2021,
		@IsDebug = @IsDebug,
		@TableName = 'AnotherLaborTransactions' -- Can change table for testing purposes

IF @IsDebug = 0
	SELECT	'Return Value' = @return_value
SET NOCOUNT OFF;

GO

*/
-- Modifications
--	2020-10-09 by kjt: Total rewrite of logic to use UC Path as a data source, plus revised 
--	to run on caes-elzar and execute via a synonym from caes-donbot because it took abount 
--	2-1/2 hours to run from caes-donbot, and abount 30 minutes to run from caes-elzar.
--	2020-10-12 by kjt: Changed to use FISDataMart.dbo.RICE_UC_KRIM_PERSON_V Vs. PPS DataMart's 
--	version so that all operations could be kept in FISDataMart.
--	2020-10-20 by kjt: Added PAID_PERCENT, and ERN_DERIVED_PERCENT columns as addition of hours
--		resulted in > 1.00 FTE for a number of persons due to UC Path rounding issues.
--	2021-02-18 by kjt: Rewrote logic to load ALL the UCP labor related transactions from both the
--		salary and fringe tables, instead of only including those transactions having accounts within 
--		our ARCs.  This is because all labor transactions are needed for the Employees with FTE > 1 
--		report.
--		My initial attempt to load all the records without the ARC filter never complated after many
--		hours; therefore, this version uses a cursor and loads the records one period at a time.  
--		Loading records in this fashion completed in 00:14:16 total time to load UCP Salary, and 
--		00:27:30 total time to load UCP Fringe records.  
--		The various updates after load completed in 00:11:32.  
--		The "Check and insert new records completed in 00:06:13 for 3,489,186 new records for FFY 2020.  
--		This same check completed in 00:00:04 when there were no new records to be added.
--		Lastly, added new column "IsAES" bit, that can be used for determining which records should be 
--		used for all of our "regular" AD-419 processing, and which should be ignored for all but the
--		 FTE > 1 report.
--	2021-06-15 by kjt: Added LastUpdateDate.
--  2021-06-16 by kjt: Added Year and Period.
--	2021-06-17 by kjt: Added Logic for EFfseq for determining EmployeeName and TitleCd
--	2021-06-18 by kjt: Added EFFSeq to table, and logic for populating it.
--	2021-06-25 by kjt: Added logic to set JOBCODE.
--	2021-07-23 by kjt: Revised logic to set CalculatedFTE to use variable for number of hours in year,
--		as this changes depending on whether or not it's a leap year, i.e. 2096 Vs. 2088.
--		Also split off updates, and added logic disable indexes.
--	2021-08-03 by kjt: Commented LEFT OUTER JOIN to CAES_HCMODS.PS_UC_LL_EMPL_DTL_V, anand set JOBCODE to
--		NULL as I suspect this was resulting in duplicate records.
--	2021-08-25 by kjt: Broke out copying over records from AnotherLaborTransaction_Temp
--		to AnotherLaborTransactions into its own stored procedure that is called from this one
--		as this procedure was getting too lengthly.
--	2021-08-27 by kjt: Added logic to fail out if child stored procedure 
--		[dbo].[usp_UpdateAnotherLaborTransactionsBlankTitleCodes] encountered issue matching all title code
--		for all employees.
--	2021-08-27 by kjt: Revised to use [dbo].[udf_GetYearPeriodTableForFFY] instead of manually inserting values.
--	2021-09-03 by kjt: Revised error message regarding unmatched title codes.
--	
-- =============================================
CREATE PROCEDURE [dbo].[usp_LoadAnotherLaborTransactions] 
	@FiscalYear int = 2020, 
	@IsDebug bit = 0,
	@TableName varchar(50) = 'AnotherLaborTransactions'
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SET ANSI_NULLS ON

	SET QUOTED_IDENTIFIER ON

	DECLARE @NumberOfHoursInYear int = (SELECT [dbo].[udf_GetHoursInFiscalYear](@FiscalYear))
	DECLARE @NextFiscalYear int = @FiscalYear + 1
	DECLARE @TSQL varchar(MAX) = ''
	DECLARE @OriginalTableName varchar(250) = @TableName

	SELECT @TableName += '_Temp'

	IF @IsDebug = 1
		SELECT @TableName As TempTableName


	--SELECT @TableName += '_FFY' + CONVERT(char(4),@FiscalYear) + '_caes-elzar_test after_empl_Id_update'

	DECLARE @QueryParameterTable AS QueryParameterTableType;
	INSERT INTO @QueryParameterTable
	SELECT ARCCode FROM ARCCodes

	DECLARE @ARCCodesString varchar(MAX) =  (
		SELECT dbo.udf_CommaDelimitedStringFromTableType(@QueryParameterTable, 1)
	)

	-- Create temp labor transactions table if not present:

	IF (NOT EXISTS (
		SELECT * 
        FROM INFORMATION_SCHEMA.TABLES 
        WHERE TABLE_SCHEMA = 'dbo' 
        AND  TABLE_NAME = @TableName
		)
	)
	BEGIN
		SELECT @TSQL = '
		CREATE TABLE [dbo].[' + @TableName + '] (
			[LaborTransactionId] [varchar](125) NOT NULL,
			[Chart] [varchar](2) NULL,
			[Account] [varchar](7) NULL,
			[SubAccount] [varchar](5) NULL,
			[Org] [varchar](4) NULL,
			[ObjConsol] [varchar](4) NULL,
			[Object] [varchar](4) NOT NULL,
			[FinanceDocTypeCd] [varchar](4) NULL,
			[DosCd] [varchar](3) NULL,
			[EmployeeID] [varchar](10) NULL,
			[PPS_ID] [varchar](9) NULL,
			[EmployeeName] [varchar](100) NULL,
			[POSITION_NBR] [nvarchar](8) NULL, -- New field used for populating title code using UCP Jobcode 
			[EFFDT] [datetime2](7) NULL, -- New field used for populating title code and/or employee name using UCP Jobcode or employee name fields.
			[TitleCd] [varchar](4) NULL,
			[RateTypeCd] [varchar](1) NULL, --Don''t really need this since everything is now hourly.
			[Hours] [numeric](18,6) NOT NULL,
			[Amount] [money] NULL,
			[Payrate] [numeric](17, 4) NULL,
			[CalculatedFTE] [numeric](9,6) NULL,
			[PayPeriodEndDate] [datetime2](7) NULL,
			[FringeBenefitSalaryCd] [varchar](1) NULL,
			[AnnualReportCode] [varchar](6) NULL,
			[ExcludedByARC] [bit] NULL,
			[ExcludedByOrg] [bit] NULL,
			[ExcludedByAccount] [bit] NULL,
			[ExcludedByObjConsol] [bit] NULL,
			[ExcludedByDOS] [bit] NULL,
			[IncludeInFTECalc] [bit] NULL,
			[ReportingYear] [int] NOT NULL,
			[School] varchar(4) NULL,
			[OrgId] varchar(4) NULL,
			[PAID_PERCENT] numeric(7,4) NULL,
			[ERN_DERIVED_PERCENT] numeric(7,4) NULL,
			[IsAES] bit NULL,
			[LastUpdateDate] datetime2(7),
			[Year] INT NULL,
			[Period] varchar(2) NULL,
			[EMP_RCD] smallint NULL,
			[EFFSEQ] smallint NULL,
		 CONSTRAINT [PK_' + @TableName + ' ] PRIMARY KEY CLUSTERED 
		(
			[LaborTransactionId] ASC,
			[ReportingYear] DESC
		) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
		) ON [PRIMARY]

		 CREATE NONCLUSTERED INDEX  [' + @TableName + '_ChartOrg_NCLINDX] 
		  ON [' + @TableName + ']
		 (Chart, Org) 
		 WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]

		 CREATE NONCLUSTERED INDEX  [' + @TableName + '_EmployeeId_NCLINDX] 
		  ON [' + @TableName + ']
		 (EmployeeId) 
		 WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]

		CREATE NONCLUSTERED INDEX [' + @TableName + '_TitleCd_NCLINDX] 
		ON [dbo].[' + @TableName + ']
		(
			[TitleCd] ASC
		) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]


		CREATE NONCLUSTERED INDEX [' + @TableName + '_EmpName_EmpId_CVIDX] 
		ON [dbo].[' + @TableName + ']
		(
			[EmployeeName] ASC
		)
		INCLUDE ([EmployeeID]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]

		CREATE NONCLUSTERED INDEX [' + @TableName + '_LastUpdateDate_NCLIDX] 
		ON [dbo].[' + @TableName + ']
		(
			[LastUpdateDate] DESC
		)
		 WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]

		 CREATE NONCLUSTERED INDEX [' + @TableName + '_YearPeriod_NCLIDX] 
		ON [dbo].[' + @TableName + ']
		(
			[Year] DESC, [Period] DESC
		)
		 WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
'
	END
	ELSE 
	BEGIN
		SELECT @TSQL = '
	TRUNCATE TABLE [dbo].[' + @TableName + ']
'
	END

	SELECT @TSQL += '
	--Disable all indexes:
	-- 2021-07-23 by kjt: Disable indexes:
	EXEC usp_DisableAllTableIndexesExceptPkOrClustered @TableName= [' + @TableName + '] , @IsDebug = 0
'

	IF @IsDebug = 1  
		PRINT @TSQL
	ELSE 
		EXEC(@TSQL)

	--DECLARE @ARCCodesString varchar(MAX) = (SELECT [dbo].[udf_ArcCodesString](DEFAULT)) -- Use this on AD419 on caes-donbot
	DECLARE @Year int = 0, @Period int = 0 -- variables for use with cursors

	DECLARE YearPeriodCursor CURSOR FOR
	SELECT FiscalYear [Year], Period FROM [dbo].[udf_GetYearPeriodTableForFFY](@FiscalYear) AS READONLY

		IF @IsDebug = 1
		PRINT '
	--======================================================================
	--
	--	SQL Statements to Insert records from PS_UC_LL_SAL_DTL begins here.
	--
	--======================================================================
'

	OPEN YearPeriodCursor
	FETCH NEXT FROM YearPeriodCursor INTO @Year, @Period
	WHILE @@FETCH_STATUS <> -1

	BEGIN
		SELECT @TSQL = '
	INSERT INTO [dbo].[' + @TableName + '](     
		   [LaborTransactionId]
		  ,[Chart]
		  ,[Account]
		  ,[SubAccount]
		  ,[Org]
		  ,[ObjConsol]
		  ,[Object]
		  ,FinanceDocTypeCd
		  ,[DosCd]
		  ,[EmployeeID]
		  ,[EmployeeName]
		  ,[POSITION_NBR]
		  ,[EFFDT]
		  ,[TitleCd]
		  ,[RateTypeCd]
		  ,[Hours]
		  ,[Amount]
		  ,[Payrate]
		  ,[CalculatedFTE]
		  ,[PayPeriodEndDate]
		  ,[FringeBenefitSalaryCd]
		  ,[AnnualReportCode]
		  ,[ExcludedByARC]
		  ,[ReportingYear]
		  ,[OrgId]
		  ,[PAID_PERCENT]
		  ,[ERN_DERIVED_PERCENT]
		  ,[IsAES]
		  ,[LastUpdateDate]	
		  ,[Year]
		  ,[Period]
		  ,[EMP_RCD]
		  ,[EFFSEQ])
	SELECT DISTINCT 
		t1.[JOURNAL_ID] + ''-'' + 
			CONVERT(nvarchar(50), t1.[JOURNAL_LINE]) + ''-'' + 
			t1.[UC_ADDL_SEQ] + ''-'' + 
			t1.[EMPLID] + ''-'' + CONVERT(varchar(5), t1.[EMPL_RCD])  + ''-'' + 
			t1.[ERNCD]  + ''-'' +
			t1.[UC_RUN_ID_EARN] AS [LaborTransactionId],
		[OPERATING_UNIT] [Chart],
		RIGHT([DEPTID_CF], 7) [Account],
		[CLASS_FLD] [SubAccount],
		RIGHT([UC_DEPTID_ROLLUP], 4) [Org],
		t1.FIN_CONS_OBJ_CD [ObjConsol],
		RIGHT(ACCOUNT,4) [Object],
		''PAY'' FinanceDocTypeCd,
		[ERNCD] [DOSCd],
		t1.[EMPLID] [EmployeeID],
		'''' EmployeeName,	-- Need to include this as the field can''t be null.
		t1.[POSITION_NBR],
		t1.[EFFDT],
		--2021-08-3 by kjt: Commented out as I suspect this was resulting in duplicate records.
	    -- CASE WHEN JOBCODE IS NOT NULL THEN RIGHT(t1.[JOBCODE],4) ELSE JOBCODE END JOBCODE,
		NULL AS JOBCODE,
		''H'' [RateTypeCd],	-- Need to include this as the field can''t be null.
		Hours1 Hours,
		MONETARY_AMOUNT Amount,
		CASE WHEN Hours1 <> 0 THEN round(MONETARY_AMOUNT/Hours1, 3) ELSE 0 END Payrate,
		CASE WHEN Hours1 <> 0 THEN ROUND(hours1/' + CONVERT(char(4), @NumberOfHoursInYear) + ', 6) ELSE 0 END [CalculatedFTE],
		UC_EARN_END_DT [PayPeriodEndDate],
		''S'' [FringeBenefitSalaryCd],
		t2.ANNUAL_REPORT_CODE [AnnualReportCode], 
		0 AS [ExcludedByARC],
		' + CONVERT(char(4), @FiscalYear) + ' [ReportingYear],
		t2.ORG_ID OrgId,
		t1.UC_PCT_TOT_PAY PAID_PERCENT, 
		t1.UC_DRV_EFT_PCT ERN_DERIVED_PERCENT,
		NULL AS [IsAES], -- We will set this later in an update.
		t1.LASTUPDDTTM LastUpdateDate,
		t1.FISCAL_YEAR Year,
		RIGHT(''0'' + CONVERT(varchar(2), t1.ACCOUNTING_PERIOD), 2) Period,
		t1.EMPL_RCD EMP_RCD,
		t1.EFFSEQ
	  FROM OPENQUERY ([FIS_BISTG_PRD (CAES_HCMODS_APPUSER)],''
		SELECT t1.*, t2.* --, t3.JOBCODE 
		FROM CAES_HCMODS.PS_UC_LL_SAL_DTL_V t1
		INNER JOIN CAES_HCMODS.UCD_OBJECT_CODES_V t2 ON 
			SUBSTR(t1.ACCOUNT,3,4) = t2.FIN_OBJECT_CD AND 
			t1.OPERATING_UNIT = t2.FIN_COA_CD AND 
			t1.Fiscal_Year = t2.UNIV_FISCAL_YR 

		-- 2021-08-3 by kjt: Removed LEFT OUTER JOIN to CAES_HCMODS.PS_UC_LL_EMPL_DTL_V as I suspect this 
		--		was resulting in duplicate records.
		--LEFT OUTER JOIN CAES_HCMODS.PS_UC_LL_EMPL_DTL_V t3 ON t1.EMPLID = t3.EMPLID AND
		--	t1.EMPL_RCD = t3.EMPL_RCD AND 
		--	t1.POSITION_NBR = t3.POSITION_NBR AND
		--	t1.EFFDT    = t3.EFFDT AND
		--	t1.EFFSEQ	= t3.EFFSEQ AND
		--	t1.PAY_BEGIN_DT = t3.PAY_BEGIN_DT AND
		--	(t1.RUN_ID = t3.RUN_ID  OR t1.UC_RUN_ID_EARN = t3.RUN_ID)  
		WHERE OPERATING_UNIT IN (''''3'''',''''L'''') AND
			(
				(
					t1.FISCAL_YEAR = ' + CONVERT(varchar(4), @Year) + '  AND 
					t1.ACCOUNTING_PERIOD = ' + CONVERT(varchar(2), @Period) + '
				) 
			) AND
			t1.BUSINESS_UNIT IN (''''DVCMP'''',''''UCANR'''') AND
			t1.DML_IND <> ''''D'''' AND
			SUBSTR(t1.ACCOUNT,3,4) NOT IN (''''INC0'''', ''''BLSH'''', ''''SB74'''', ''''SUB9'''') 
		ORDER BY t1.JOURNAL_ID, t1.JOURNAL_LINE, t1.UC_ADDL_SEQ, t1.POSITION_NBR 
	  '') t1
	  INNER JOIN 
	  (
		SELECT CHART_NUM, ACCT_NUM, ANNUAL_REPORT_CODE, ORG_ID
		FROM OPENQUERY([FIS_DS], ''
			SELECT A.CHART_NUM, A.ACCT_NUM, A.ANNUAL_REPORT_CODE, A.ORG_ID
			FROM FINANCE.ORGANIZATION_ACCOUNT A
			WHERE A.FISCAL_YEAR = 9999 AND 
				A.FISCAL_PERIOD = ''''--'''' AND
				A.HIGHER_ED_FUNC_CODE NOT LIKE ''''PROV'''' 
		'')
	   ) t2 ON t1.OPERATING_UNIT =  t2.CHART_NUM AND
			RIGHT([DEPTID_CF], 7) = t2.ACCT_NUM

	ORDER BY [LaborTransactionId]
	 '
		IF @IsDebug = 1  
		BEGIN
			PRINT @TSQL
		END
		ELSE 
			EXEC(@TSQL)

		FETCH NEXT FROM YearPeriodCursor INTO @Year, @Period
	END -- WHILE @@FETCH_STATUS <> -1

	CLOSE YearPeriodCursor  -- Close only.  We will  reopen it to set it back at the first entry below
							--	 for use with the FRINGE transactions.

	IF @IsDebug = 1
		PRINT '
	--======================================================================
	--
	--	SQL Statements to Insert records from PS_UC_LL_FRNG_DTL begins here.
	--
	--======================================================================
'
	OPEN YearPeriodCursor
	FETCH NEXT FROM YearPeriodCursor INTO @Year, @Period
		WHILE @@FETCH_STATUS <> -1

		BEGIN
			SELECT @TSQL = '
	INSERT INTO [dbo].[' + @TableName + '](     
		   [LaborTransactionId]
		  ,[Chart]
		  ,[Account]
		  ,[SubAccount]
		  ,[Org]
		  ,[ObjConsol]
		  ,[Object]
		  ,FinanceDocTypeCd
		  ,[DosCd]
		  ,[EmployeeID]
		  ,[EmployeeName]
		  ,[POSITION_NBR]
		  ,[EFFDT]
		  ,[TitleCd]
		  ,[RateTypeCd]
		  ,[Hours]
		  ,[Amount]
		  ,[Payrate]
		  ,[CalculatedFTE]
		  ,[PayPeriodEndDate]
		  ,[FringeBenefitSalaryCd]
		  ,[AnnualReportCode]
		  ,[ExcludedByARC]
		  ,[ReportingYear]
		  ,[OrgId]
		  ,[PAID_PERCENT]
		  ,[ERN_DERIVED_PERCENT]
		  ,[IsAES]
		  ,[LastUpdateDate]
		  ,[Year]
		  ,[Period]
		  ,[EMP_RCD]
		  ,[EFFSEQ]
	 )
	SELECT DISTINCT 
		t1.[JOURNAL_ID] + ''-'' + 
			CONVERT(nvarchar(50), t1.[JOURNAL_LINE]) + ''-'' + 
			t1.[UC_ADDL_SEQ] + ''-'' + 
			t1.[EMPLID] + ''-'' + CONVERT(varchar(5), t1.[EMPL_RCD])  + ''-'' + 
			''XXX''  + ''-'' +
			t1.[RUN_ID] AS [LaborTransactionId],
		[OPERATING_UNIT] [Chart],
		RIGHT([DEPTID_CF], 7) [Account],
		[CLASS_FLD] [SubAccount],
		RIGHT([UC_DEPTID_ROLLUP], 4) [Org],
		t1.FIN_CONS_OBJ_CD [ObjConsol],
		RIGHT(ACCOUNT,4) [Object],
		''PAY'' FinanceDocTypeCd,
		''XXX'' [DOSCd],
		t1.[EMPLID] [EmployeeID],
		'''' EmployeeName,	-- Need to include this as the field can''t be null.
		t1.[POSITION_NBR],
		t1.[EFFDT],
		-- 2021-08-3 by kjt: Commeented out LEFT OUTER JOIN to CAES_HCMODS.PS_UC_LL_EMPL_DTL_V as I suspect this 
		--		was resulting in duplicate records.
		-- CASE WHEN JOBCODE IS NOT NULL THEN RIGHT(t1.[JOBCODE],4) ELSE JOBCODE END JOBCODE,
		NULL AS JOBCODE,
		''H'' [RateTypeCd],	-- Need to include this as the field can''t be null.
		0 [Hours],
		MONETARY_AMOUNT [Amount],
		0 [Payrate],
		0 [CalculatedFTE],
		UC_EARN_END_DT [PayPeriodEndDate],
		''F'' [FringeBenefitSalaryCd],
		t2.ANNUAL_REPORT_CODE [AnnualReportCode], 
		0 AS [ExcludedByARC],
		' + CONVERT(char(4), @FiscalYear) + ' [ReportingYear],
		t2.ORG_ID OrgId,
		0 AS PAID_PERCENT,
		0 AS ERN_DERIVED_PERCENT,
		NULL AS [IsAES],
		LASTUPDDTTM [LastUpdateDate],
		FISCAL_YEAR Year,
		RIGHT(''0'' + CONVERT(varchar(2), t1.ACCOUNTING_PERIOD), 2) Period,
		EMPL_RCD [EMP_RCD],
		EFFSEQ

	  FROM OPENQUERY ([FIS_BISTG_PRD (CAES_HCMODS_APPUSER)],''
		SELECT t1.*, t2.* --, t3.JOBCODE 
		FROM CAES_HCMODS.PS_UC_LL_FRNG_DTL_V t1
		INNER JOIN CAES_HCMODS.UCD_OBJECT_CODES_V t2 ON 
			SUBSTR(t1.ACCOUNT,3,4) = t2.FIN_OBJECT_CD AND 
			t1.OPERATING_UNIT = t2.FIN_COA_CD AND 
			t1.Fiscal_Year = t2.UNIV_FISCAL_YR 
		-- 2021-08-3 by kjt: Commeented out LEFT OUTER JOIN to CAES_HCMODS.PS_UC_LL_EMPL_DTL_V as I suspect this 
		--		was resulting in duplicate records.
		--LEFT OUTER JOIN CAES_HCMODS.PS_UC_LL_EMPL_DTL_V t3 ON t1.EMPLID = t3.EMPLID AND
		--	t1.EMPL_RCD = t3.EMPL_RCD AND 
		--	t1.POSITION_NBR = t3.POSITION_NBR AND
		--	t1.EFFDT    = t3.EFFDT AND
		--	t1.EFFSEQ	= t3.EFFSEQ AND
		--	t1.PAY_BEGIN_DT = t3.PAY_BEGIN_DT AND
		--	t1.RUN_ID = t3.RUN_ID  
		WHERE OPERATING_UNIT IN (''''3'''',''''L'''') AND
			(
				(
					t1.FISCAL_YEAR = ' + CONVERT(varchar(4), @Year) + '  AND 
					t1.ACCOUNTING_PERIOD = ' + CONVERT(varchar(2), @Period) + '
				) 
			) AND
			t1.BUSINESS_UNIT IN (''''DVCMP'''',''''UCANR'''') AND
			t1.DML_IND <> ''''D'''' AND
			SUBSTR(t1.ACCOUNT,3,4) NOT IN (''''INC0'''', ''''BLSH'''', ''''SB74'''', ''''SUB9'''') 
		ORDER BY t1.JOURNAL_ID, t1.JOURNAL_LINE, t1.UC_ADDL_SEQ, t1.POSITION_NBR 
	  '') t1
	  INNER JOIN 
	  (
		SELECT CHART_NUM, ACCT_NUM, ANNUAL_REPORT_CODE, ORG_ID
		FROM OPENQUERY([FIS_DS], ''
			SELECT A.CHART_NUM, A.ACCT_NUM, A.ANNUAL_REPORT_CODE, A.ORG_ID
			FROM FINANCE.ORGANIZATION_ACCOUNT A
			WHERE A.FISCAL_YEAR = 9999 AND 
				A.FISCAL_PERIOD = ''''--'''' AND
				A.HIGHER_ED_FUNC_CODE NOT LIKE ''''PROV''''
		'')
	   ) t2 ON t1.OPERATING_UNIT =  t2.CHART_NUM AND
			RIGHT([DEPTID_CF], 7) = t2.ACCT_NUM
	
	ORDER BY [LaborTransactionId]
	 '
 		IF @IsDebug = 1  
			PRINT @TSQL
		ELSE 
			EXEC(@TSQL)

		FETCH NEXT FROM YearPeriodCursor INTO @Year, @Period
	END

	CLOSE YearPeriodCursor
	DEALLOCATE YearPeriodCursor  -- No longer needed.

	-- Rebuild (re-enable) all indexes:
	SELECT @TSQL = '
	EXEC usp_RebuildAllTableIndexes @TableName = [' + @TableName + '], @IsDebug = 0
	'
	IF @IsDebug = 1  
			PRINT @TSQL
		ELSE 
			EXEC(@TSQL)

	DECLARE @ErrorMessage varchar(200) = 'Not all Title Codes could be matched.  Unmatched title codes will need to be manually entered using AD-419 DataHelper.'
	DECLARE @Statement nvarchar(MAX) = ''
    SELECT @Statement = '
	--======================================================================
	--
	-- Call the various updates:
	--
	--======================================================================
'
	IF @IsDebug = 1  
		BEGIN
			SELECT @Statement += '
	DECLARE @NullDosCodeCount int, @BlankTitleCodeCount int
'	
		END

	SELECT @Statement += '
	EXEC usp_UpdateAnotherLaborTransactions
		@FiscalYear = ' + CONVERT(char(4), @FiscalYear) + ',
		@IsDebug = 0,
		@TableName = ''' + @TableName + ''', -- This is the name of the temp table we''ve been using
		@NumNullDosCodes = @NullDosCodeCount OUTPUT,
		@NumNullRecs = @BlankTitleCodeCount OUTPUT
'

	IF @IsDebug = 1  
		BEGIN
			SELECT @Statement += '
	SELECT ''NullDosCodeCount'' = @NullDosCodeCount, ''BlankTitleCodeCount'' = @BlankTitleCodeCount
'
			PRINT @Statement + '
	IF  @BlankTitleCodeCount > 0
		PRINT ''-- ' + @ErrorMessage + '''
	--ELSE 
	BEGIN
'
		END
	ELSE 
		BEGIN
			DECLARE @NumNullDosCodes int, @NumNullRecs int
			DECLARE @Params nvarchar(100) = N'@NullDosCodeCount int OUTPUT, @BlankTitleCodeCount int OUTPUT'
			EXEC sp_executesql @Statement, @Params, @NullDosCodeCount = @NumNullDosCodes OUTPUT, @BlankTitleCodeCount = @NumNullRecs OUTPUT
			SELECT @NumNullDosCodes AS NullDosCodeCount, @NumNullRecs AS BlankTitleCodeCount

			-- Commented out this section as I think we want to address setting any unmatched title codes manually in datahelper.
			--IF @NumNullRecs > 0
			--BEGIN
			--	RAISERROR(@ErrorMessage, 16, 1)
			--	RETURN -1
			--END
		END
	
	SELECT @TSQL = '
	--================================================================================
	--
	-- Call the stored procedure to copy new records over to AnotherLaborTransactions:
	--
	--================================================================================
'
	SELECT @TSQL += '
		DECLARE	@return_value int

		EXEC	[dbo].[usp_InsertNewRecordsIntoAnotherLaborTransactions]
				@FiscalYear = ' + CONVERT(char(4), @FiscalYear) + ',
				@IsDebug = 0,
				@TableName = ''' + @OriginalTableName + ''',    -- This is the original table name to which
																--   we want the records copied over to.  
																--  Assumes source table is names <@TableName>_Temp.
				@NumRecordsAdded = @return_value OUTPUT
'
	IF @IsDebug = 0
		SELECT @TSQL += '
		SELECT @return_value AS ''NumRecordsAdded (Output value from insert sproc): '' 
'

	IF @IsDebug = 1 
	BEGIN
		SET NOCOUNT ON; 
		PRINT @TSQL + '
		SELECT ''Number of New Records Added'' = @return_value
	END
'
		SET NOCOUNT OFF;
	END
	ELSE 
		EXEC(@TSQL)

	SET NOCOUNT ON;
    
END