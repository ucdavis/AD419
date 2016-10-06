/*
Modifications:
	20110129 by kjt:
		Analyzed the org level and chart mapping and found that it need to be revised
		because a few of the chart L BIOS orgs were being excluded.
*/
CREATE Procedure [dbo].[usp_DownloadTransactions]
(
	--PARAMETERS:
	@FirstDate varchar(16) = null,	--earliest date to download (GL_Applied.TRANS_GL_POSTED_DATE) 
		--optional, defaults to day after highest date in Trans table
	@LastDate varchar(16) = null,	--latest date to download 
		--optional, defaults to day after @FirstDate
	@CollegeOrg char(4) = null, -- either 'AAES' or 'BIOS'
	@IsDebug bit = 0 -- Set to 1 just print the SQL and not actually execute. 
)
AS

	--Downloads GL_Applied (applied transactions) records for a range of posting dates
		--Makes use of pass-through queries to Oracle Linked Servers.

	--local:
	declare @TSQL varchar(MAX)	--Holds T-SQL code to be run with EXEC() function.
	declare @IsCAES bit -- to flag whether or not transaction is under CAES and not Bio Sci. 
	declare @MyDate smalldatetime	--temp holder of dates as type smalldatetime
		--Note regarding date formats: Need to pass date to Oracle using it's conversion function TO_DATE, for which a string type is need.  I'm using a varchar for the parameters here, but convert to a smalldatetime in order to make use of the DateAdd() function and formatting options in the conversion function CONVERT. (which I use to convert back to a char type for conversion to the Oracle date type.
     
    -- 20100721 by KJT: I added these because Steve Pesis' said that there are now orgs in 
    -- AAES that belong to BIOS, and BIOS orgs that are outside of BIOS; therefore, 
    -- we need to readjust the 'IsCAES' logic to handle this.
    -- 20100804 by KJT: Revised above logic to set the Is_CAES based on the input org
    -- as Tom Kaiser says that the ACBS amounts should be included as part of the 
    -- AAES base budget; however, I believe that Steve Pesis doesn't want them for
    -- some of his reports.
    -- 20110111 by kjt: Changed Account num sub query to include chart as account and org combinations
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
	
	--TESTING
	--set @firstDate = '10/10/06'
	-----------------------------------------------------------------------------
	if @CollegeOrg IS NULL OR @CollegeOrg = 'AAES'
		BEGIN
			SELECT @CollegeOrg = 'AAES'
			SELECT @IsCAES = 1
		END
	else
		BEGIN
			SELECT @IsCAES = 0
		END	
		
	--If no parameters passed, default to greatest date in Trans table, else use param value(s):
	if @FirstDate IS NULL 
		--Attempt to read highest date in table currently and use this as @FirstDate value:
		BEGIN
			SELECT @MyDate =
			(
				SELECT cast(max(PostDate) as smalldatetime) as MaxPostDate
				FROM Trans
				WHERE IsCAES = @IsCAES
			)
			SELECT @FirstDate = convert(varchar(30),DateAdd(dd,1,@MyDate), 102)
		END
	else
		BEGIN
			SELECT @MyDate = convert(smalldatetime,@FirstDate)
			SELECT @FirstDate = convert(varchar(30), @MyDate, 102)
		END

	--Determine last date to download:
	if @LastDate IS NULL 
		BEGIN
			SELECT @MyDate = convert(smalldatetime,@FirstDate)
			SELECT @LastDate = convert(varchar(30),DateAdd(dd,7,@MyDate), 102)
		END
	else
		BEGIN
			SELECT @MyDate = convert(smalldatetime,@LastDate)
			SELECT @LastDate = convert(varchar(30), @MyDate, 102)
		END

	print '--Downloading transaction records...'
	print '--' + ISNULL(convert(varchar(30),convert(smalldatetime,@FirstDate),102), 'NULL') + ' = First date'
	print '--' + ISNULL(convert(varchar(30),convert(smalldatetime,@LastDate),102), 'NULL') + ' = Last date'

	--Build Transact-SQL command:
		--Note: it doesn't work to build the SQL command and only pass in the Oracle SQL as a string--not if you want to parameterize the query.  The OPENQUERY() function apparently expects a string literal *only* for the 2nd argument (the SQL command) and will not work with any kind of character string built from variables.  The workaround is to build the entire t-SQL command as a varchar, and then execute it as a block of code by calling EXEC(<varchar>) with the entire block of code contained in the single parameter.  The trickiest part of doing this is that single quotes need to be escaped with 2 single quotes TWICE within the SQL for Oracle, meaning that you need to write the code with QUADRUPLE single quotes for every embedded quote you eventually want to pass thru to Oracle.  If the item to be inserted in quotes is a variable, then you need *5* single quotes, the 5th being used to close or open the strings being concatenated with the variable (/parameter).
	select @TSQL = 
	'SELECT YEAR,
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
      RTRIM(ISNULL([Doc_Track_Num], '''')) + ''|'' +
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
			A.FISCAL_YEAR || ''''|'''' ||  ''''--'''' || ''''|'''' || A.CHART_NUM || ''''|'''' || A.TRANS_LINE_PROJECT_NUM Project_FK
			, ' 
			
			IF @CollegeOrg = @AAES OR @CollegeOrg = @ACBS
						BEGIN
							select @TSQL += '	CASE WHEN A.ORG_ID IN (Select DISTINCT ORG_ID from FINANCE.ORGANIZATION_HIERARCHY where (ORG_ID_LEVEL_2 = ''''ACBS'''' OR ORG_ID_LEVEL_5 = ''''ACBS'''') AND FISCAL_YEAR = 9999 AND FISCAL_PERIOD = ''''--'''') THEN 2
							ELSE 1 END AS Is_CAES'
						END
			ELSE
				BEGIN
					select @TSQL += '0 AS Is_CAES'
				END
						
		Select @TSQL += '
		FROM 
			FINANCE.GL_APPLIED_TRANSACTIONS A
		WHERE
			(A.Chart_num, A.ACCT_NUM) IN
				(
					SELECT DISTINCT
					A.Chart_num, A.ACCT_NUM Account_Num
				FROM
					FINANCE.ORGANIZATION_ACCOUNT A ,
					FINANCE.ORGANIZATION_HIERARCHY O
				WHERE
					(
						A.CHART_NUM=O.CHART_NUM
						AND A.ORG_ID=O.ORG_ID
						AND O.FISCAL_YEAR = A.FISCAL_YEAR
						AND O.FISCAL_PERIOD = A.FISCAL_PERIOD 
						AND A.FISCAL_PERIOD = ''''--'''' 
						AND A.FISCAL_YEAR = 9999
					)
					AND 
					(
						(O.CHART_NUM_LEVEL_1 = ''''3'''' AND O.ORG_ID_LEVEL_1 = ''''' + @CollegeOrg +''''')
						OR 
					'
							IF @CollegeOrg = @BIOS
		SELECT @TSQL += '	(O.CHART_NUM_LEVEL_1 = ''''L'''' AND O.ORG_ID_LEVEL_1 = ''''' + @CollegeOrg +''''') '
							ELSE							
		SELECT @TSQL += '	(O.CHART_NUM_LEVEL_2 = ''''L'''' AND O.ORG_ID_LEVEL_2 = ''''' + @CollegeOrg +''''') '
							
		SELECT @TSQL += '
						OR 
						(O.CHART_NUM_LEVEL_4 IN (''''3'''', ''''L'''') AND O.ORG_ID_LEVEL_4 = ''''' + @CollegeOrg +''''') 
						OR 
					'
							IF @CollegeOrg = @BIOS
		SELECT @TSQL +=	'	(O.CHART_NUM_LEVEL_4 = ''''L'''' AND O.ORG_ID_LEVEL_4 = ''''' + @CollegeOrg +''''') '
							ELSE
		SELECT @TSQL +=	'	(O.CHART_NUM_LEVEL_5 = ''''L'''' AND O.ORG_ID_LEVEL_5 = ''''' + @CollegeOrg +''''') '

		SELECT @TSQL +=	'
					)							
			)
			AND (a.trans_gl_posted_date >= TO_DATE(''''' + ISNULL(@FirstDate, 'NULL')  + ''''' ,''''yyyy.mm.dd'''')) 
			AND (a.trans_gl_posted_date < TO_DATE(''''' + ISNULL(@LastDate, 'NULL')  + ''''' ,''''yyyy.mm.dd'''')) 
			AND (A.BALANCE_TYPE_CODE NOT IN (''''PE'''', ''''RE''''))	/*limit used in VFP datamart*/
			AND NOT (A.OBJECT_NUM IN (SELECT DISTINCT OBJECT_NUM FROM FINANCE.OBJECT_REPORTING))''
		)'
/*
Removed WHERE conditions:
			OR 
				(a.acct_num in (''''EVOR094'''',''''MBOR039'''',''''MIOR017'''',''''NPOR035'''',''''PBOR023'''',''''BSOR001'''',''''BSFACOR'''',''''BSRESCH'''',''''CNSOR05'''',''''EVOR093'''',''''PBHB024'''',''''PBHBSAL''''))
*/
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
