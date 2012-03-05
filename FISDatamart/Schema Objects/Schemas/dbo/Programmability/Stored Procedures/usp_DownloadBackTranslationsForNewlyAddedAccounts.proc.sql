-- =============================================
-- Author:		Ken Taylor
-- Create date: February 16, 2011
-- Description:	Download any missing transactions that were not 
-- downloaded prior due to the account(s) being outside AAES or BIOS
-- during previous download attempts.
-- =============================================
CREATE PROCEDURE [dbo].[usp_DownloadBackTranslationsForNewlyAddedAccounts] 
	-- Add the parameters for the stored procedure here
	@CollegeOrg varchar(4) = AAES, 
	@IsDebug bit = 0 --set to 1 to print SQL only.
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	-- SET NOCOUNT ON;

    -- Insert statements for procedure here
  /*
  DECLARE @CollegeOrg varchar(4) = 'BIOS'
  DECLARE @IsDebug bit = 1
  */
 
  DECLARE @IsCAES bit -- to flag whether or not transaction is under CAES and not Bio Sci.
  DECLARE @AAES char(4) = 'AAES'
  DECLARE @BIOS char(4) = 'BIOS' 
  DECLARE @ACBS char(4) = 'ACBS'
  
  	if @CollegeOrg IS NULL OR @CollegeOrg = 'AAES'
		BEGIN
			SELECT @CollegeOrg = 'AAES'
			SELECT @IsCAES = 1
		END
	else
		BEGIN
			SELECT @IsCAES = 0
		END	
 

  DECLARE @TSQL varchar(MAX) = ''
  
  DECLARE @TableName varchar(255)= 'Trans',
	@Exclude9999FiscalYear bit = 1
	
  DECLARE @BeginningFiscalYear int, 
	@EndingFiscalYear int,
	@LastFiscalYearToDownload int,
	@NumFiscalYearsToDownload smallint,
	@FirstDate datetime,
	@LastDate dateTime,
	@TruncateTable bit = 0,
	@RecordCount int
	
  DECLARE MyYearlyCursor CURSOR FOR SELECT * FROM udf_GetBeginningAndLastFiscalYearToDownload(
	@TableName, null, null, null, @TruncateTable, @Exclude9999FiscalYear)
	
  OPEN MyYearlyCursor
  FETCH NEXT FROM MyYearlyCursor INTO @BeginningFiscalYear, 
	@EndingFiscalYear,
	@LastFiscalYearToDownload,
	@NumFiscalYearsToDownload,
	@FirstDate,
	@LastDate,
	@TruncateTable,
	@RecordCount
	
  CLOSE MyYearlyCursor
  DEALLOCATE MyYearlyCursor
  
  DECLARE @WhereClause varchar(1024) = ''
  SELECT  @WhereClause = 
				CASE WHEN @BeginningFiscalYear <> @EndingFiscalYear THEN
' BETWEEN ' + Convert(char(4), @BeginningFiscalYear) +
		 ' AND ' + + Convert(char(4), @EndingFiscalYear)
ELSE 
' = ' + Convert(char(4), @BeginningFiscalYear)
END
  
  IF @IsDebug = 1
	BEGIN
		PRINT '--BeginningFiscalYear: ' + ISNULL(CONVERT(char(4),@BeginningFiscalYear), 'NULL')
		PRINT '--EndingFiscalYear: ' + ISNULL(CONVERT(char(4),@EndingFiscalYear), 'NULL')
		PRINT '--LastFiscalYearToDownload: ' + ISNULL(CONVERT(char(4), @LastFiscalYearToDownload), 'NULL')
		PRINT '--NumFiscalYearsToDownload: ' + CONVERT(char(4), @NumFiscalYearsToDownload)
		PRINT '--FirstDate: ' + ISNULL(CONVERT(varchar(20), @FirstDate), 'NULL')
		PRINT '--LastDate: ' + ISNULL(CONVERT(varchar(20), @LastDate), 'NULL')
		PRINT '--TruncateTable: ' + CASE @TruncateTable WHEN 1 THEN 'True' ELSE 'False' END
		PRINT '--RecordCount: ' + CONVERT(varchar(10), @RecordCount)
	END

  DECLARE @MyTable TABLE (
	  FISCAL_YEAR int, 
	  FISCAL_PERIOD char(2), 
	  CHART_NUM varchar(2), 
	  ACCT_NUM char(7), 
	  SUB_ACCT_NUM char(5),
	  OBJECT_TYPE_CODE char(2),
	  OBJECT_NUM char(4),
	  SUB_OBJECT_NUM char(3),
	  BALANCE_TYPE_CODE char(2), 
	  DOC_TYPE_NUM char(4),
	  DOC_ORIGIN_CODE char(2), 
	  DOC_NUM char(9),
	  ORG_DOC_TRACKING_NUM char(10),
	  TRANS_LINE_ENTRY_SEQUENCE_NUM decimal(7,0),
	  TRANS_GL_POSTED_DATE smalldatetime)
  
  SELECT @TSQL = '
    SELECT  
      CONVERT(int, FISCAL_YEAR) FISCAL_YEAR,
      CONVERT(char(2),FISCAL_PERIOD) FISCAL_PERIOD,
      CONVERT(varchar(2),CHART_NUM) CHART_NUM,
      CONVERT(char(7), ACCT_NUM) ACCT_NUM,
      CONVERT(char(5),SUB_ACCT_NUM) SUB_ACCT_NUM,
      CONVERT(char(2),OBJECT_TYPE_CODE) OBJECT_TYPE_CODE,
      CONVERT(char(4),OBJECT_NUM) OBJECT_NUM,
      CONVERT(char(3), SUB_OBJECT_NUM) SUB_OBJECT_NUM,
      CONVERT(char(2), BALANCE_TYPE_CODE) BALANCE_TYPE_CODE,
      CONVERT(char(4), RTRIM(DOC_TYPE_NUM)) DOC_TYPE_NUM,
      CONVERT(char(2), DOC_ORIGIN_CODE) DOC_ORIGIN_CODE,
      CONVERT(char(9), RTRIM(DOC_NUM)) DOC_NUM,
      CONVERT(char(10), RTRIM(ISNULL(ORG_DOC_TRACKING_NUM,''''))) ORG_DOC_TRACKING_NUM,
      CONVERT(decimal(7,0), TRANS_LINE_ENTRY_SEQUENCE_NUM) TRANS_LINE_ENTRY_SEQUENCE_NUM,
      CONVERT(smalldatetime, TRANS_GL_POSTED_DATE, 112) TRANS_GL_POSTED_DATE
      
	FROM OPENQUERY (FIS_DS, 
			''SELECT 
			A.FISCAL_YEAR,
			A.FISCAL_PERIOD,
			A.CHART_NUM,
			A.ACCT_NUM, 
			A.SUB_ACCT_NUM, 
			A.OBJECT_TYPE_CODE,
			A.OBJECT_NUM, 
			A.SUB_OBJECT_NUM, 
			A.BALANCE_TYPE_CODE, 
			A.DOC_TYPE_NUM, 
			A.DOC_ORIGIN_CODE, 
			A.DOC_NUM, 
			A.ORG_DOC_TRACKING_NUM, 
			A.TRANS_LINE_ENTRY_SEQUENCE_NUM,
			A.TRANS_GL_POSTED_DATE
	
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
						AND A.FISCAL_YEAR' + @WhereClause +  '
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
						(O.CHART_NUM_LEVEL_4 = ''''3'''' AND O.ORG_ID_LEVEL_4 = ''''' + @CollegeOrg +''''') 
						OR 
					'
							IF @CollegeOrg = @BIOS
		SELECT @TSQL +=	'	(O.CHART_NUM_LEVEL_4 = ''''L'''' AND O.ORG_ID_LEVEL_4 = ''''' + @CollegeOrg +''''') '
							ELSE
		SELECT @TSQL +=	'	(O.CHART_NUM_LEVEL_5 = ''''L'''' AND O.ORG_ID_LEVEL_5 = ''''' + @CollegeOrg +''''') '

		SELECT @TSQL +=	'
					)
			)
			AND A.FISCAL_YEAR' + @WhereClause + '
			AND (A.BALANCE_TYPE_CODE NOT IN (''''PE'''', ''''RE'''')) 	/*limit used in VFP datamart*/
			AND NOT (A.OBJECT_NUM IN (SELECT DISTINCT OBJECT_NUM FROM FINANCE.OBJECT_REPORTING))		
			''
			)
  EXCEPT 
  
  SELECT 
      CONVERT(int, YEAR) FISCAL_YEAR,
      CONVERT(char(2),Period) FISCAL_PERIOD,
      CONVERT(varchar(2),Chart) CHART_NUM,
      CONVERT(char(7), Account) ACCT_NUM,
      CONVERT(char(5),SubAccount) SUB_ACCT_NUM,
      CONVERT(char(2),ObjectTypeCode) OBJECT_TYPE_CODE,
      CONVERT(char(4),[Object]) OBJECT_NUM,
      CONVERT(char(3), SubObject) SUB_OBJECT_NUM,
      CONVERT(char(2), BalType) BALANCE_TYPE_CODE,
      CONVERT(char(4), RTRIM(DocType)) DOC_TYPE_NUM,
      CONVERT(char(2), DocOrigin) DOC_ORIGIN_CODE,
      CONVERT(char(9), RTRIM(DocNum)) DOC_NUM,
      CONVERT(char(10), RTRIM(ISNULL(DocTrackNum,''''))) ORG_DOC_TRACKING_NUM,
      CONVERT(decimal(7,0), LineSquenceNumber) TRANS_LINE_ENTRY_SEQUENCE_NUM,
      CONVERT(smalldatetime, PostDate, 112) TRANS_GL_POSTED_DATE FROM [FISDataMart].[dbo].[Trans] 
      WHERE Year ' + @WhereClause + '
      '
      
  IF @IsDebug = 1
	BEGIN
		PRINT @TSQL
		INSERT INTO @MyTable
		EXEC(@TSQL)
		SELECT * FROM @MyTable
	END
  ELSE
	BEGIN
		INSERT INTO @MyTable
		EXEC(@TSQL)
	END
    
  DECLARE @FiscalYear int,
		@FiscalPeriod char(2),
		@ChartNum varchar(2),
		@AcctNum char(7),
		@SubAcctNum char(5),
		@ObjectTypeCode char(2),
		@ObjectNum char(4),
		@SubObjectNum char(3),
	    @BalanceTypeCode char(2),
	    @DocTypeNum char(4),
	    @DocOriginCode char(2),
	    @DocNum char(9),
	    @OrgDocTrackingNum char(10),
	    @TransLineEntrySequenceNum decimal (7,0),
	    @TransGLPostedDate smalldatetime
	    
	DECLARE MyCursor CURSOR FOR SELECT 
	   [FISCAL_YEAR]
      ,[FISCAL_PERIOD]
      ,[CHART_NUM]
      ,[ACCT_NUM]
      ,[SUB_ACCT_NUM]
      ,[OBJECT_TYPE_CODE]
      ,[OBJECT_NUM]
      ,[SUB_OBJECT_NUM]
      ,[BALANCE_TYPE_CODE]
      ,[DOC_TYPE_NUM]
      ,[DOC_ORIGIN_CODE]
      ,[DOC_NUM]
      ,[ORG_DOC_TRACKING_NUM]
      ,[TRANS_LINE_ENTRY_SEQUENCE_NUM]
      ,[TRANS_GL_POSTED_DATE]
      FROM @MyTable
  
  OPEN MyCursor
  FETCH NEXT FROM MyCursor INTO @FiscalYear,
		@FiscalPeriod ,
		@ChartNum ,
		@AcctNum ,
		@SubAcctNum ,
		@ObjectTypeCode,
		@ObjectNum ,
		@SubObjectNum ,
	    @BalanceTypeCode ,
	    @DocTypeNum ,
	    @DocOriginCode ,
	    @DocNum ,
	    @OrgDocTrackingNum ,
	    @TransLineEntrySequenceNum ,
	    @TransGLPostedDate
  
  WHILE @@FETCH_STATUS <> -1
	BEGIN
		
	  SELECT @TSQL = '
	    INSERT INTO FISDataMart.dbo.Trans (
	   [PKTrans]
      ,[Year]
      ,[Period]
      ,[Chart]
      ,[OrgID]
      ,[AccountType]
      ,[Account]
      ,[SubAccount]
      ,[ObjectTypeCode]
      ,[Object]
      ,[SubObject]
      ,[BalType]
      ,[DocType]
      ,[DocOrigin]
      ,[DocNum]
      ,[DocTrackNum]
      ,[InitrID]
      ,[InitDate]
      ,[LineSquenceNumber]
      ,[LineDesc]
      ,[LineAmount]
      ,[Project]
      ,[OrgRefNum]
      ,[PriorDocTypeNum]
      ,[PriorDocOriginCd]
      ,[PriorDocNum]
      ,[EncumUpdtCd]
      ,[CreationDate]
      ,[PostDate]
      ,[ReversalDate]
      ,[ChangeDate]
      ,[SrcTblCd]
      ,[OrganizationFK]
      ,[AccountsFK]
      ,[ObjectsFK]
      ,[SubObjectFK]
      ,[SubAccountFK]
      ,[ProjectFK]
      ,[IsCAES]
 )
    
	  SELECT *
	  FROM OPENQUERY (FIS_DS, 
			''SELECT 
			(A.FISCAL_YEAR  || ''''|'''' || A.FISCAL_PERIOD || ''''|'''' || A.CHART_NUM || ''''|'''' || A.ACCT_NUM   
			|| ''''|'''' || A.SUB_ACCT_NUM || ''''|'''' || A.OBJECT_TYPE_CODE || ''''|'''' || A.OBJECT_NUM  
			|| ''''|'''' || A.SUB_OBJECT_NUM  || ''''|'''' || A.BALANCE_TYPE_CODE  || ''''|'''' ||  RTRIM(A.DOC_TYPE_NUM)
			|| ''''|'''' || A.DOC_ORIGIN_CODE || ''''|'''' || RTRIM(A.DOC_NUM) || ''''|'''' || RTRIM(NVL(A.ORG_DOC_TRACKING_NUM,'''''''')) 
			|| ''''|'''' || LTRIM(TO_CHAR(A.TRANS_LINE_ENTRY_SEQUENCE_NUM, ''''9999'''')) || ''''|'''' || TO_CHAR(A.TRANS_GL_POSTED_DATE, ''''YYYYMMDD'''')
			) AS PKTrans,
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
			A.FISCAL_YEAR || ''''|'''' ||  A.CHART_NUM     || ''''|''''        || OBJECT_NUM Objects_FK,
			A.FISCAL_YEAR || ''''|'''' ||  ''''--'''' || ''''|'''' || A.CHART_NUM  || ''''|'''' || A.ACCT_NUM || ''''|'''' || OBJECT_NUM || ''''|'''' || A.SUB_OBJECT_NUM Sub_Object_FK,
			A.FISCAL_YEAR || ''''|'''' ||  ''''--'''' || ''''|'''' || A.CHART_NUM  || ''''|'''' || A.ACCT_NUM || ''''|'''' || A.SUB_ACCT_NUM Sub_Account_FK,
			A.FISCAL_YEAR || ''''|'''' ||  ''''--'''' || ''''|'''' || A.CHART_NUM  || ''''|'''' || A.TRANS_LINE_PROJECT_NUM Project_FK,
			 ' 
			
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
						AND A.FISCAL_YEAR = ' + CONVERT(char(4), @FiscalYear) + '
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
						(O.CHART_NUM_LEVEL_4 = ''''3'''' AND O.ORG_ID_LEVEL_4 = ''''' + @CollegeOrg +''''') 
						OR 
					'
							IF @CollegeOrg = @BIOS
		SELECT @TSQL +=	'	(O.CHART_NUM_LEVEL_4 = ''''L'''' AND O.ORG_ID_LEVEL_4 = ''''' + @CollegeOrg +''''') '
							ELSE
		SELECT @TSQL +=	'	(O.CHART_NUM_LEVEL_5 = ''''L'''' AND O.ORG_ID_LEVEL_5 = ''''' + @CollegeOrg +''''') '

		SELECT @TSQL +=	'
					)
			)
			AND A.FISCAL_YEAR = ' + CONVERT(char(4), @FiscalYear) + '
			AND (A.BALANCE_TYPE_CODE NOT IN (''''PE'''', ''''RE'''')) 	/*limit used in VFP datamart*/
			AND NOT (A.OBJECT_NUM IN (SELECT DISTINCT OBJECT_NUM FROM FINANCE.OBJECT_REPORTING))

		 AND A.FISCAL_PERIOD = ( ''''' + @FiscalPeriod + ''''')
		 AND A.CHART_NUM IN (''''' + @ChartNum + ''''')
		 AND A.ACCT_NUM  IN (''''' + @AcctNum + ''''')
		 AND A.SUB_ACCT_NUM IN (''''' + @SubAcctNum + ''''')
		 AND A.OBJECT_TYPE_CODE IN (''''' + @ObjectTypeCode +''''')
		 AND A.OBJECT_NUM  IN (''''' + @ObjectNum + ''''')
		 AND A.SUB_OBJECT_NUM  IN (''''' + @SubObjectNum + ''''')
		 AND A.BALANCE_TYPE_CODE IN (''''' + @BalanceTypeCode + ''''')
		 AND RTRIM(A.DOC_TYPE_NUM) IN (''''' + RTRIM(@DocTypeNum) + ''''')
		 AND A.DOC_ORIGIN_CODE IN (''''' + @DocOriginCode + ''''')
		 AND RTRIM(A.DOC_NUM) IN (''''' + RTRIM(@DocNum) + ''''')
		 AND (
				(RTRIM(NVL(A.ORG_DOC_TRACKING_NUM,'''''''')) IN (''''' + RTRIM(@OrgDocTrackingNum) + '''''))
		     OR (RTRIM(NVL(A.ORG_DOC_TRACKING_NUM,'''''''')) IS NULL)
		      )
		 AND LTRIM(TO_CHAR(A.TRANS_LINE_ENTRY_SEQUENCE_NUM, ''''9999'''')) IN (''''' + LTRIM(CONVERT(varchar(10), @TransLineEntrySequenceNum)) + ''''')
		 AND TO_CHAR(A.TRANS_GL_POSTED_DATE, ''''YYYYMMDD'''') IN (''''' + CONVERT(varchar(20), @TransGLPostedDate, 112) + ''''' )
			''
		)
	'
	
		IF @IsDebug = 1
			PRINT @TSQL
		ELSE
			EXEC (@TSQL)
      
		FETCH NEXT FROM MyCursor INTO @FiscalYear,
		@FiscalPeriod ,
		@ChartNum ,
		@AcctNum ,
		@SubAcctNum ,
		@ObjectTypeCode,
		@ObjectNum ,
		@SubObjectNum ,
	    @BalanceTypeCode ,
	    @DocTypeNum ,
	    @DocOriginCode ,
	    @DocNum ,
	    @OrgDocTrackingNum ,
	    @TransLineEntrySequenceNum ,
	    @TransGLPostedDate
	END
  
  CLOSE MyCursor
  DEALLOCATE MyCursor
  
END
