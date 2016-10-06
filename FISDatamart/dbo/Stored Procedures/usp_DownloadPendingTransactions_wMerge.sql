/*
Modifications:
	20110128 by kjt:
		Analyzed the org level and chart mapping and found that it need to be revised
		because a few of the chart L BIOS orgs were being excluded.
	20110214 by kjt:
		Added output SQL param and modified to PRINT, EXEC TSQL logic.
	20111209 by kjt:
		Revised logic to handle missing Object (numbers) in PK and replace them with '----'.
	2015-10-08 by kjt: Modifications to take into account removing DANR as level 4 ORG for chart L, and moving
		AANS up to level 4 org position.  AAES is now at Level 4 for both Chart 'L' and Chart '3' as of FY 2016.
*/
CREATE Procedure [dbo].[usp_DownloadPendingTransactions_wMerge]
(
	@CollegeOrg char(4) = null, -- College: Either AAES or BIOS.
	@FiscalYear int = null,
		--earliest date to download (SUB_OBJECT.DS_LAST_UPDATE_DATE) 
		--optional, defaults to highest date in Trans table
	@IsDebug bit = 0, -- Set to 1 just print the SQL and not actually execute. 
	@TSQLOut varchar(MAX) OUTPUT
)
AS

--Downloads GL_PENDING_TRANSACTIONS (pending transactions) 

	--local:
	declare @TSQL varchar(MAX)	= '' --Holds T-SQL code to be run with EXEC() function.
	declare @IsCAES bit	    -- Whether or not pending trans is under CAES.
	declare @MaxYear int	-- Temp holder for Max(Year) 
	SET @MaxYear = (Select MAX(Year) from Trans)
	-----------------------------------------------------------------------------
	
	-- 20100722 by KJT: I added these because Steve Pesis' said that there are now orgs in 
    -- AAES that belong to BIOS, and BIOS orgs that are outside of BIOS; therefore, 
    -- we need to readjust the 'IsCAES' logic to handle this.
	declare @AAES char(4) = 'AAES'
	declare @BIOS char(4) = 'BIOS'
	declare @ACBS char(4) = 'ACBS'
		
	-- Logic for setting College ORG and IsCAES:	
	if @CollegeOrg IS NULL OR @CollegeOrg = 'AAES'
		BEGIN
			SELECT @CollegeOrg = 'AAES'
			SELECT @IsCAES = 1
		END
	else
		BEGIN
			SELECT @IsCAES = 0
		END	
		
	-- Logic for setting @FiscalYear if none provided:	
	if @FiscalYear IS NULL
		BEGIN
			if @MaxYear IS NOT NULL 
				BEGIN 
					SELECT @FiscalYear = @MaxYear
				END
			else 
				BEGIN 
					Select @FiscalYear = DATEPART(year, getdate())
					-- If the current date is August 1st or after, the assume that the FY has closed, and  
					-- use next year as the Fiscal Year, meaning use 2010 after August 1st, 2009, etc.
					if DATEDIFF(month, convert (datetime, convert(char(4), DATEPART(year, getdate())) + '-08-01'), GETDATE()) >= 0
						BEGIN
							 Select @FiscalYear = @FiscalYear + 1
						END
				END
		END
	Print '--Max(Year): ' + Convert(varchar(4), @MaxYear)
	print '--Fiscal Year >= ' + convert(char(4), @FiscalYear)
	print '--IsDebug = ' + CASE @IsDebug WHEN 1 THEN 'True' ELSE 'False' END	
	print '--Downloading pending transaction records for ' + @CollegeOrg + '...'
	
	--Select out all of pending trans
	Select @TSQL = 
	'SELECT 		(
			CONVERT(CHAR(4),[Year]) + ''|'' +
			[Period] + ''|'' +
			[Chart] + ''|'' +
			ACCT_ID + ''|'' +
			SUB_ACCT + ''|'' +
			ISNULL(OBJECT_TYPE,''--'') + ''|'' +
			ISNULL([OBJECT],''----'') + ''|'' +
			SUB_OBJ + ''|'' +
			BAL_TYPE + ''|'' +
			RTRIM(DOC_TYPE) + ''|'' +
			DOC_ORIGIN + ''|'' +
			RTRIM(DOC_NUM) + ''|'' +
			RTRIM(ISNULL([Doc_Track_Num],'''')) + ''|'' +
			CONVERT(varchar(10), SEQUENCE_NUM) + ''|'' + 
			''--------''
		) AS PKPendingTrans,
		P_TRANS.YEAR Year,P_TRANS.PERIOD Period, P_TRANS.CHART Chart, P_TRANS.ORG_ID as OrgID,
		P_TRANS.ACCT_TYPE AccountType, P_TRANS.ACCT_ID Account, P_TRANS.SUB_ACCT SubAccount, P_TRANS.OBJECT_TYPE ObjectTypeCode,
		P_TRANS.OBJECT Object, P_TRANS.SUB_OBJ SubObject, P_TRANS.BAL_TYPE BalType, P_TRANS.DOC_TYPE DocType, 
		P_TRANS.DOC_ORIGIN DocOrigin, P_TRANS.DOC_NUM DocNum, P_TRANS.Doc_Track_Num DocTrackNum,
		P_TRANS.INITR_ID InitrID, P_TRANS.INIT_DATE InitDate, P_TRANS.SEQUENCE_NUM as LineSquenceNumber, P_TRANS.Line_Desc LineDesc, P_TRANS.LINE_AMT LineAmount,
		P_TRANS.Project, P_TRANS.Org_Ref_Num OrgRefNum, PRIOR_DOC_TYPE as PriorDocTypeNum, PRIOR_DOC_ORIGIN as PriorDocOriginCd, PRIOR_DOC_NUM as PriorDocNum,
		P_TRANS.Encum_Updt_Cd EncumUpdtCd, null as PostDate, P_TRANS.Reversal_Date ReversalDate, P_TRANS.SrcTblCd,
		CONVERT([char](4),P_TRANS.YEAR,(0)) + ''|'' + ''--'' + ''|'' + P_TRANS.CHART + ''|'' + P_TRANS.ORG_ID as OrganizationFK,
		CONVERT([char](4),P_TRANS.YEAR,(0)) + ''|'' + ''--'' + ''|'' + P_TRANS.CHART + ''|'' + P_TRANS.ACCT_ID as AccountsFK,
		CONVERT([char](4),P_TRANS.YEAR,(0)) + ''|'' +                  P_TRANS.CHART + ''|'' + P_TRANS.OBJECT ObjectsFK,
		CONVERT([char](4),P_TRANS.YEAR,(0)) + ''|'' + ''--'' + ''|'' + P_TRANS.CHART + ''|'' + P_TRANS.ACCT_ID + ''|'' + P_TRANS.OBJECT + ''|'' + P_TRANS.SUB_OBJ as SubObjectFK,
		CONVERT([char](4),P_TRANS.YEAR,(0)) + ''|'' + ''--'' + ''|'' + P_TRANS.CHART + ''|'' + P_TRANS.ACCT_ID + ''|'' + P_TRANS.SUB_ACCT as SubAccountFK,
		CONVERT([char](4),P_TRANS.YEAR,(0)) + ''|'' + ''--'' + ''|'' + P_TRANS.CHART + ''|'' + P_TRANS.Project as ProjectFK,
		Is_CAES IsCAES

	FROM OPENQUERY (FIS_DS, 
			''SELECT
			P.FISCAL_YEAR YEAR,
			P.FISCAL_PERIOD PERIOD,
			P.CHART_NUM CHART,
			O.ORG_ID,
			P.ACCT_TYPE_CODE ACCT_TYPE,
			P.ACCT_NUM ACCT_ID, 
			P.SUB_ACCT_NUM SUB_ACCT, 
			P.OBJECT_TYPE_CODE OBJECT_TYPE,
			P.OBJECT_NUM OBJECT, 
			P.SUB_OBJECT_NUM SUB_OBJ, 
			P.BALANCE_TYPE_CODE BAL_TYPE,
			P.TRANS_LINE_ENTRY_SEQUENCE_NUM SEQUENCE_NUM,
			P.TRANS_LINE_PRIOR_DOC_NUM PRIOR_DOC_NUM,
			P.TRANS_LINE_PRIOR_DOC_ORIGIN_CD PRIOR_DOC_ORIGIN,
			P.TRANS_LINE_PRIOR_DOC_TYPE_NUM PRIOR_DOC_TYPE,
			P.DOC_TYPE_NUM DOC_TYPE, 
			P.DOC_ORIGIN_CODE DOC_ORIGIN, 
			P.DOC_NUM DOC_NUM, 
			P.ORG_DOC_TRACKING_NUM Doc_Track_Num,
			P.INITIATOR_ID INITR_ID, 
			P.TRANS_INITIATION_DATE INIT_DATE, 
			P.TRANS_LINE_DESC Line_Desc, 
			P.TRANS_LINE_AMT LINE_AMT, 
			P.TRANS_LINE_PROJECT_NUM Project, 
			P.TRANS_LINE_ORG_REFERENCE_NUM Org_Ref_Num, 
			P.TRANS_ENCUMBRANCE_UPDATE_CODE Encum_Updt_Cd, 
			P.TRANS_REVERSAL_DATE Reversal_Date,
			''''P'''' SrcTblCd,
			'
			IF @CollegeOrg = @AAES OR @CollegeOrg = @ACBS
						BEGIN
							select @TSQL += '	CASE WHEN O.ORG_ID IN (Select DISTINCT ORG_ID from FINANCE.ORGANIZATION_HIERARCHY where (ORG_ID_LEVEL_2 = ''''ACBS'''' OR ORG_ID_LEVEL_5 = ''''ACBS'''') AND FISCAL_YEAR = 9999 AND FISCAL_PERIOD = ''''--'''') THEN 2
							ELSE 1 END AS Is_CAES'
						END
			ELSE
				BEGIN
					select @TSQL += '0 AS Is_CAES'
				END
				
		Select @TSQL += '		
		FROM 
			FINANCE.GL_PENDING_TRANSACTIONS P,
			FINANCE.ORGANIZATION_ACCOUNT A ,
			FINANCE.ORGANIZATION_HIERARCHY O
		WHERE
			(
				(P.Chart_Num, P.acct_num) IN 
				( 
					SELECT DISTINCT 
						A.Chart_Num, A.Acct_num
					FROM 
						FINANCE.ORGANIZATION_ACCOUNT A,
						FINANCE.ORGANIZATION_HIERARCHY O
					WHERE
						A.FISCAL_YEAR = 9999
						AND O.FISCAL_YEAR = A.FISCAL_YEAR
					
						AND A.FISCAL_PERIOD = ''''--''''
						AND O.FISCAL_PERIOD = A.FISCAL_PERIOD	
					
						AND A.CHART_NUM = O.CHART_NUM
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
						AND A.ORG_ID = O.ORG_ID
				)
				AND P.ACCT_NUM = A.ACCT_NUM
				AND P.CHART_NUM = A.CHART_NUM
				AND A.CHART_NUM = O.CHART_NUM
				AND A.ORG_ID = O.ORG_ID
				AND P.FISCAL_YEAR = O.FISCAL_YEAR
				AND O.FISCAL_YEAR = A.FISCAL_YEAR
				AND P.FISCAL_PERIOD = O.FISCAL_PERIOD
				AND O.FISCAL_PERIOD = A.FISCAL_PERIOD 
				AND A.FISCAL_YEAR >= ' + CONVERT(char(4), @FiscalYear) + ' 
			)'' ) P_TRANS'
			
	-------------------------------------------------------------------------
	if @IsDebug = 1 AND @TSQLOut IS NULL
		BEGIN
			--used for testing
			PRINT @TSQL	
		END
	else IF @TSQLOut = ''
		BEGIN
			SELECT @TSQLOut = @TSQL
		END
	ELSE
		BEGIN
			--Execute the command:
			EXEC(@TSQL)
		END
	
	RETURN