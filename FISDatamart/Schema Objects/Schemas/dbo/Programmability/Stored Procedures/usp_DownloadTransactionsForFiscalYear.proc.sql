

/*
Usage:
	
	USE [FISDataMart]
	GO

	EXEC [dbo].[usp_DownloadTransactionsForFiscalYear]
		@FirstDateString = '2018-10-01',
		@LastDateString = '2021-09-30',
		@GetUpdatesOnly = 0,
		@IsDebug = 1

Modifications:
	20110129 by kjt:
		Analyzed the org level and chart mapping and found that it need to be revised
		because a few of the chart L BIOS orgs were being excluded.
	20110223 by kjt:
		Removed IsCAES setting logic and incorporated AAES and BIOS together.
	20110224 by kjt:
		Added logic to set IsCAES doing INNER JOIN with Accounts table.
	20110303 by kjt:
		Added logic to pass a destination table name; otherwise defaults to Trans.
	20110411 by kjt:
		Revised Accounts table to use inner join of DaFIS side instead of mixed. 
	20110421 by kjt:
		Revised IsCAES setting portion to use a subsequent update as opposed to an inner join.
	20110426 by kjt:
		Revised to use concatenated Chart + Account key IN statement instead of multi-column IN
		statement.
	2015-10-08 by kjt: Modifications to take into account removing DANR as level 4 ORG for chart L, and moving
		AANS up to level 4 org position.  AAES is now at Level 4 for both Chart 'L' and Chart '3' as of FY 2016.
	2021-05-05 by kjt: Expanded filtering to also included VETM Orgs as they are required
		for Animal Health reports.  Also modified setting of IsCAES so that null would be the
		default setting to allow VETM to have a null value.
*/
CREATE PROCEDURE [dbo].[usp_DownloadTransactionsForFiscalYear]
(
	--PARAMETERS:
	@FirstDateString varchar(16) = null,
		--earliest date to download 
		--optional, defaults to highest date in Trans table
	@LastDateString varchar(16) = null,
		-- latest date to download  
		-- optional, defaults to today's date.
	@GetUpdatesOnly bit = 1, -- Flag to determine whether to get just updated records only as opposed all
		-- records for the corresponding Fiscal Years(s).
		-- optional, defaults to getting just the updated records.
	@TableName varchar(255) = 'Trans', --Can be passed another table name, i.e. #Trans, etc.
	@IsDebug bit = 0 -- Set to 1 just print the SQL and not actually execute. 
)
AS

	--Downloads GL_Applied (applied transactions) records for a range of posting dates
		--Makes use of pass-through queries to Oracle Linked Servers.

	--local:
	declare @TSQL varchar(MAX)	--Holds T-SQL code to be run with EXEC() function.
	declare @IsCAES tinyint -- to code to tell whether or not transaction is under CAES and not Bio Sci. 
	
	-- 20100721 by KJT: I added these because Steve Pesis' said that there are now orgs in 
    -- AAES that belong to BIOS, and BIOS orgs that are outside of BIOS; therefore, 
    -- we need to readjust the 'IsCAES' logic to handle this.
    -- 20100804 by KJT: Revised above logic to set the Is_CAES based on the input org
    -- as Tom Kaiser says that the ACBS amounts should be included as part of the 
    -- AAES base budget; however, I believe that Steve Pesis doesn't want them for
    -- some of his reports.
    -- 20110107 by kjt: Changed Account num sub query to include chart as account and org combinations
    -- would change depending on chart, i.e.,
    -- FROM:
    --		(A.ACCT_NUM) IN 
	--			(
	--				SELECT DISTINCT
	--					A.ACCT_NUM Account_Num 
	--	TO:				
	--		(A.Chart_num, A.ACCT_NUM) IN
	--			(
	--				SELECT DISTINCT
	--					A.Chart_num, A.ACCT_NUM Account_Num
    --
	declare @AAES char(4) = 'AAES'
	declare @BIOS char(4) = 'BIOS' 
	declare @ACBS char(4) = 'ACBS'
	declare @VETM char(4) = 'VETM'
	
	-----------------------------------------------------------------------------
	--local:
	DECLARE @BeginningFiscalYear int = null
	DECLARE @EndingFiscalYear int = null
	DECLARE @NumFiscalYearsToDownload smallint = null
	DECLARE @FirstDate datetime = null
	DECLARE @LastDate datetime = null
	DECLARE @RecordCount int = 0
	--DECLARE @TableName varchar(255) = 'Trans' --Name of table being updated.
	DECLARE @TruncateTable bit = 0 --Whether or not to truncate the table before load.  This is not set from this sproc, 
	-- but left for consistency.
	DECLARE @Exclude9999FiscalYear bit = 1 --This is the only table with a 9999 fiscal year that we're not interested in. 
-------------------------------------------------------------------------------------
	DECLARE MyCursor CURSOR FOR SELECT BeginningFiscalYear, EndingFiscalYear, NumFiscalYearsToDownload, FirstDate, LastDate, RecordCount 
	FROM udf_GetBeginningAndLastFiscalYearToDownload(@TableName, @FirstDateString, @LastDateString, @NumFiscalYearsToDownload, @TruncateTable, @Exclude9999FiscalYear)
	
	OPEN MyCursor
	
	FETCH NEXT FROM MyCursor INTO @BeginningFiscalYear, @EndingFiscalYear, @NumFiscalYearsToDownload, @FirstDate, @LastDate, @RecordCount
	
	CLOSE MyCursor
	DEALLOCATE MyCursor
	
	IF @IsDebug = 1 PRINT '--@NumFiscalYearsToDownload: ' + Convert(varchar(20), @NumFiscalYearsToDownload) 
			
-------------------------------------------------------------------------------------	

	print '--Downloading transaction records to table ' + @TableName + '...'
	print '--FiscalYear: ' + convert(varchar(4),@BeginningFiscalYear) 
	print '--IsCAES?: ' + CASE @IsCAES WHEN 1 THEN 'True' ELSE 'False' END

	--Build Transact-SQL command:
		--Note: it doesn't work to build the SQL command and only pass in the Oracle SQL as a string--not if you want to parameterize the query.  The OPENQUERY() function apparently expects a string literal *only* for the 2nd argument (the SQL command) and will not work with any kind of character string built from variables.  The workaround is to build the entire t-SQL command as a varchar, and then execute it as a block of code by calling EXEC(<varchar>) with the entire block of code contained in the single parameter.  The trickiest part of doing this is that single quotes need to be escaped with 2 single quotes TWICE within the SQL for Oracle, meaning that you need to write the code with QUADRUPLE single quotes for every embedded quote you eventually want to pass thru to Oracle.  If the item to be inserted in quotes is a variable, then you need *5* single quotes, the 5th being used to close or open the strings being concatenated with the variable (/parameter).
	select @TSQL = '	
	merge ' + @TableName + ' as Trans
using
(SELECT		YEAR,
			PERIOD,
			CHART,
			Org_ID,
			Account_Type,
			ACCT_ID, 
			SUB_ACCT, 
			Object_Type_Code,
			OBJECT, 
			SUB_OBJ, 
			BAL_TYPE, 
			DOC_TYPE, 
			DOC_ORIGIN, 
			DOC_NUM, 
			Doc_Track_Num,
			INITR_ID, 
			INIT_DATE, 
			Line_Squence_Num,
			Line_Desc, 
			LINE_AMT, 
			Project, 
			Org_Ref_Num, 
			PriorDocTypeNum,
			PriorDocOriginCd,
			PriorDocNum,
			Encum_Updt_Cd, 
			Creation_Date, 
			Post_Date, 
			Reversal_Date,
			Change_Date,
			SrcTblCd,
			Organization_FK,
			Accounts_FK,
			Objects_FK,
			Sub_Object_FK,
			Sub_Account_FK,
			Project_FK,
		    Is_CAES, 
	  CONVERT(CHAR(4),[Year]) + ''|'' +
      [Period] + ''|'' +
      [Chart] + ''|'' +
      [ACCT_ID] + ''|'' +
      [SUB_ACCT] + ''|'' +
      [OBJECT_TYPE_CODE] + ''|'' +
      [Object] + ''|'' +
      [SUB_OBJ] + ''|'' +
      [BAL_TYPE] + ''|'' +
      RTRIM([DOC_TYPE]) + ''|'' +
      [DOC_ORIGIN] + ''|'' +
      RTRIM([DOC_NUM]) + ''|'' +
      RTRIM(ISNULL([Doc_Track_Num],'''')) + ''|'' +
      CONVERT(varchar(10), [LINE_SQUENCE_NUM]) + ''|'' +
      CONVERT(varchar(20), [POST_DATE], 112)  as PKTrans
	FROM OPENQUERY (FIS_DS, 
			''SELECT 
			A.FISCAL_YEAR YEAR,
			A.FISCAL_PERIOD PERIOD,
			A.CHART_NUM CHART,
			A.ORG_ID Org_ID,
			A.ACCT_TYPE_CODE Account_Type,
			A.ACCT_NUM ACCT_ID, 
			A.SUB_ACCT_NUM SUB_ACCT, 
			A.OBJECT_TYPE_CODE Object_Type_Code,
			A.OBJECT_NUM OBJECT, 
			A.SUB_OBJECT_NUM SUB_OBJ, 
			A.BALANCE_TYPE_CODE BAL_TYPE, 
			A.DOC_TYPE_NUM DOC_TYPE, 
			A.DOC_ORIGIN_CODE DOC_ORIGIN, 
			A.DOC_NUM DOC_NUM, 
			A.ORG_DOC_TRACKING_NUM Doc_Track_Num,
			A.INITIATOR_ID INITR_ID, 
			A.TRANS_INITIATION_DATE INIT_DATE, 
			A.TRANS_LINE_ENTRY_SEQUENCE_NUM Line_Squence_Num,
			A.TRANS_LINE_DESC Line_Desc, 
			A.TRANS_LINE_AMT LINE_AMT, 
			A.TRANS_LINE_PROJECT_NUM Project, 
			A.TRANS_LINE_ORG_REFERENCE_NUM Org_Ref_Num, 
			A.TRANS_LINE_PRIOR_DOC_TYPE_NUM PriorDocTypeNum,
			A.TRANS_LINE_PRIOR_DOC_ORIGIN_CD PriorDocOriginCd,
			A.TRANS_LINE_PRIOR_DOC_NUM PriorDocNum,
			A.TRANS_ENCUMBRANCE_UPDATE_CODE Encum_Updt_Cd, 
			A.TRANS_GL_POSTED_DATE Creation_Date, 
			A.TRANS_GL_POSTED_DATE Post_Date, 
			A.TRANS_REVERSAL_DATE Reversal_Date,
			A.DS_LAST_UPDATE_DATE Change_Date,
			''''A'''' SrcTblCd,
			A.FISCAL_YEAR || ''''|'''' ||  ''''--'''' || ''''|'''' ||  A.CHART_NUM || ''''|'''' || A.ORG_ID Organization_FK,
			A.FISCAL_YEAR || ''''|'''' ||  ''''--'''' || ''''|'''' || A.CHART_NUM  || ''''|'''' || A.ACCT_NUM Accounts_FK,
			A.FISCAL_YEAR || ''''|'''' ||  A.CHART_NUM || ''''|'''' || OBJECT_NUM Objects_FK,
			A.FISCAL_YEAR || ''''|'''' ||  ''''--'''' || ''''|'''' || A.CHART_NUM || ''''|'''' || A.ACCT_NUM || ''''|'''' || OBJECT_NUM || ''''|'''' || A.SUB_OBJECT_NUM Sub_Object_FK,
			A.FISCAL_YEAR || ''''|'''' ||  ''''--'''' || ''''|'''' || A.CHART_NUM || ''''|'''' || A.ACCT_NUM || ''''|'''' || A.SUB_ACCT_NUM Sub_Account_FK,
			A.FISCAL_YEAR || ''''|'''' ||  ''''--'''' || ''''|'''' || A.CHART_NUM || ''''|'''' || A.TRANS_LINE_PROJECT_NUM Project_FK,
			null AS Is_CAES
		FROM 
			FINANCE.GL_APPLIED_TRANSACTIONS A
			WHERE
				--(A.CHART_NUM, A.ACCT_NUM) IN 
				 A.CHART_NUM || A.ACCT_NUM IN 
				(
					SELECT
						--DISTINCT A.CHART_NUM, A.ACCT_NUM
						DISTINCT A.CHART_NUM || A.ACCT_NUM
					FROM
						FINANCE.ORGANIZATION_ACCOUNT A 
						INNER JOIN FINANCE.ORGANIZATION_HIERARCHY O ON 
							A.FISCAL_YEAR = O.FISCAL_YEAR AND 
							A.FISCAL_PERIOD = O.FISCAL_PERIOD AND 
							A.CHART_NUM = O.CHART_NUM AND 
							A.ORG_ID = O.ORG_ID
					WHERE 
					(
						(
							A.FISCAL_YEAR = ' + CONVERT(char(4), @BeginningFiscalYear) + '
						)	
						AND 
						(
							(A.CHART_NUM, A.ORG_ID) IN 
							(
								SELECT  DISTINCT CHART_NUM, ORG_ID 
								FROM FINANCE.ORGANIZATION_HIERARCHY O
								WHERE
								(
									(CHART_NUM_LEVEL_1=''''3'''' AND ORG_ID_LEVEL_1 = ''''AAES'''')
									OR
									(CHART_NUM_LEVEL_2=''''L'''' AND ORG_ID_LEVEL_2 = ''''AAES'''')
									
									OR
									(ORG_ID_LEVEL_1 = ''''BIOS'''')
									
									OR 
									(CHART_NUM_LEVEL_4 IN (''''3'''', ''''L'''') AND ORG_ID_LEVEL_4 = ''''AAES'''')
									OR
									(CHART_NUM_LEVEL_5 = ''''L'''' AND ORG_ID_LEVEL_5 = ''''AAES'''')
									
									OR
									(ORG_ID_LEVEL_4 = ''''BIOS'''')

								-- 2021-05-04 by kjt: Added VETM orgs for Animal Health Reports. 
									OR 
									(CHART_NUM_LEVEL_4 IN (''''3'''', ''''L'''') AND ORG_ID_LEVEL_4 = ''''VETM'''')
								)
								AND
								(
									FISCAL_YEAR = ' + CONVERT(char(4), @BeginningFiscalYear) + '
								)
							)
						)
					)
				)
				AND
				(
					A.FISCAL_YEAR = ' + CONVERT(char(4), @BeginningFiscalYear) + ' 
					AND (A.BALANCE_TYPE_CODE NOT IN (''''PE'''', ''''RE'''')) 	/*limit used in VFP datamart*/
					AND NOT (A.OBJECT_NUM IN (SELECT DISTINCT OBJECT_NUM FROM FINANCE.OBJECT_REPORTING))
				)
			'')  
		) FIS_DS_TRANS on Trans.PKTrans = FIS_DS_TRANS.PKTrans
/*
WHEN MATCHED THEN UPDATE set
	   [OrgID] = Org_ID
      ,[AccountType] = Account_Type
      ,[DocTrackNum] = Doc_Track_Num
      ,[InitrID] = INITR_ID
      ,[InitDate] = INIT_DATE
      ,[LineDesc] = Line_Desc
      ,[LineAmount] =LINE_AMT
      ,[Project] = FIS_DS_TRANS.Project
      ,[OrgRefNum] =Org_Ref_Num
      ,[PriorDocTypeNum] =FIS_DS_TRANS.PriorDocTypeNum
      ,[PriorDocOriginCd] =FIS_DS_TRANS.PriorDocOriginCd
      ,[PriorDocNum] =FIS_DS_TRANS.PriorDocNum
      ,[EncumUpdtCd] =FIS_DS_TRANS.Encum_Updt_Cd
      ,[CreationDate] =FIS_DS_TRANS.Creation_Date
      ,[ReversalDate] =FIS_DS_TRANS.Reversal_Date
      ,[ChangeDate] =FIS_DS_TRANS.Change_Date
      ,[SrcTblCd] =FIS_DS_TRANS.SrcTblCd
      ,[OrganizationFK] =FIS_DS_TRANS.Organization_FK
      ,[AccountsFK] =FIS_DS_TRANS.Accounts_FK
      ,[ObjectsFK] =FIS_DS_TRANS.Objects_FK
      ,[SubObjectFK] =FIS_DS_TRANS.Sub_Object_FK
      ,[SubAccountFK] =FIS_DS_TRANS.Sub_Account_FK
      ,[ProjectFK] =FIS_DS_TRANS.Project_FK
      ,[IsCAES] = FIS_DS_TRANS.Is_CAES
*/     
WHEN NOT MATCHED BY TARGET THEN INSERT VALUES 
(
    PKTrans,
	YEAR,
	PERIOD,
	CHART,
	Org_ID,
	Account_Type,
	ACCT_ID, 
	SUB_ACCT, 
	Object_Type_Code,
	OBJECT, 
	SUB_OBJ, 
	BAL_TYPE, 
	DOC_TYPE, 
	DOC_ORIGIN, 
	DOC_NUM, 
	Doc_Track_Num,
	INITR_ID, 
	INIT_DATE, 
	Line_Squence_Num,
	Line_Desc, 
	LINE_AMT, 
	Project, 
	Org_Ref_Num, 
	PriorDocTypeNum,
	PriorDocOriginCd,
	PriorDocNum,
	Encum_Updt_Cd, 
	Creation_Date, 
	Post_Date, 
	Reversal_Date,
	Change_Date,
	SrcTblCd,
	Organization_FK,
	Accounts_FK,
	Objects_FK,
	Sub_Object_FK,
	Sub_Account_FK,
	Project_FK,
    Is_CAES
)

--WHEN NOT MATCHED BY SOURCE THEN DELETE
;
'

if @IsDebug = 1
		BEGIN
			--used for testing
			PRINT @TSQL	
		END
	else
		BEGIN
			--Execute the command:
			EXEC(@TSQL)
		END

-------------------------------------------------------------------------

	SELECT @TSQL = '
UPDATE trans
SET IsCAES = CASE
	  WHEN  (chart = ''3'' and account in (select distinct account from accounts a where year = ' +  CONVERT(char(4), @BeginningFiscalYear) + ' AND chart = ''3'' and IsCAES = 0))
            OR
            (chart = ''L'' and account in (select distinct account from accounts a where year = ' +  CONVERT(char(4), @BeginningFiscalYear) + ' AND chart = ''L'' and IsCAES = 0))
      THEN 0
	  WHEN  (chart = ''3'' and account in (select distinct account from accounts a where year = ' +  CONVERT(char(4), @BeginningFiscalYear) + ' AND chart = ''3'' and IsCAES = 1))
            OR
            (chart = ''L'' and account in (select distinct account from accounts a where year = ' +  CONVERT(char(4), @BeginningFiscalYear) + ' AND chart = ''L'' and IsCAES = 1))
      THEN 1
      WHEN  (chart = ''3'' and account in (select distinct account from accounts a where year = ' +  CONVERT(char(4), @BeginningFiscalYear) + ' AND chart = ''3'' and IsCAES = 2))
            OR
            (chart = ''L'' and account in (select distinct account from accounts a where year = ' +  CONVERT(char(4), @BeginningFiscalYear) + ' AND chart = ''L'' and IsCAES = 2))
      THEN 2
      ELSE 1 END
 WHERE IsCAES IS NULL
'

-------------------------------------------------------------------------

if @IsDebug = 1
		BEGIN
			--used for testing
			PRINT @TSQL	
		END
	else
		BEGIN
			--Execute the command:
			EXEC(@TSQL)
		END
