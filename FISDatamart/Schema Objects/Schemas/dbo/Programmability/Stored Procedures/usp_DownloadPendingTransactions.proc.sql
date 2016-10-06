/*
Modifications:
	20100722 by KJT: I added these because Steve Pesis' said that there are now orgs in 
		AAES that belong to BIOS, and BIOS orgs that are outside of BIOS; therefore, 
		we need to readjust the 'IsCAES' logic to handle this.
	20110128 by kjt:
		Analyzed the org level and chart mapping and found that it need to be revised
		because a few of the chart L BIOS orgs were being excluded.
	20110217 by kjt:
		Revised to include both AAES, and BIOS transactions at a single bound.
		Also replaced with inner joins.
	20110411 by kjt:
		Changed @DisableIndexes default to 0 and @RebuildIndexes to 1.
	20110412 by kjt:
		Added timing print outs.
	20111209 by kjt:
		Added logic to handle missing Object (numbers) in PK and replace then with '----'.
	2015-10-08 by kjt: Modifications to take into account removing DANR as level 4 ORG for chart L, and moving
		AANS up to level 4 org position.  AAES is now at Level 4 for both Chart 'L' and Chart '3' as of FY 2016. 
*/
CREATE Procedure [dbo].[usp_DownloadPendingTransactions]
(
	@DisableIndexes bit = 0, --Set to 1 to not disable indexes before downloading data.
	@RebuildIndexes bit = 1, --Set to 0 to not rebuild indexes after downloading data.
	@IsDebug bit = 0 -- Set to 1 just print the SQL and not actually execute. 
)
AS

--Downloads GL_PENDING_TRANSACTIONS (pending transactions) 

	-- 20110412 by kjt: Stuff for timing print outs
	DECLARE @StartTime datetime = (SELECT GETDATE())
	DECLARE @TempTime datetime = (SELECT @StartTime)
	DECLARE @EndTime datetime = (SELECT @StartTime)
	
	IF @IsDebug = 0
		PRINT '--Start time for EXEC usp_DownloadPendingTransactions: 
--' + CONVERT(varchar(20),@StartTime, 114)

	--local:
	DECLARE @TableName varchar(255) = 'PendingTrans'
	declare @TSQL varchar(MAX)	= '' --Holds T-SQL code to be run with EXEC() function.
	declare @IsCAES bit	    -- Whether or not pending trans is under CAES.
	declare @MaxYear int	-- Temp holder for Max(Year) 
	SET @MaxYear = (Select MAX(Year) from Trans)
	-----------------------------------------------------------------------------
	--Truncating PendingTrans table...
	Select @TSQL = '
	TRUNCATE TABLE PendingTrans;
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
	--Disabling all non-clustered and non-PK indexes if selected...
	IF @DisableIndexes = 1
		BEGIN
			SELECT @TSQL = 'EXEC usp_DisableAllTableIndexesExceptPkOrClustered @TableName = ''' + @TableName + ''', @IsDebug = ' + CONVERT(char(1), @IsDebug) + '
	'
		if @IsDebug = 1
			BEGIN
				--used for testing
				PRINT '--' + @TSQL
				EXEC(@TSQL)	
			END
		else
			BEGIN
				--Execute the command:
				EXEC(@TSQL)
			END
		END
	-------------------------------------------------------------------------
	--Download and insert all AAES and BIOS Pending Transactions...	
	
	PRINT '
	--Downloading and Inserting AAES and BIOS Pending Transactions into PendingTrans...'
	SELECT @TSQL = '	insert into [FISDataMart].dbo.PendingTrans (
	   [Year]
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
      ,[ReversalDate]
      ,[SrcTblCd]
      ,[OrganizationFK]
      ,[AccountsFK]
      ,[ObjectsFK]
      ,[SubObjectFK]
      ,[SubAccountFK]
      ,[ProjectFK]
      ,[IsCAES]
      ,[PKPendingTrans]
      )
	SELECT P_TRANS.YEAR Year,P_TRANS.PERIOD , P_TRANS.CHART Chart, P_TRANS.ORG_ID as OrgID,
		P_TRANS.ACCT_TYPE AccountType, P_TRANS.ACCT_ID Account, P_TRANS.SUB_ACCT SubAccount, P_TRANS.OBJECT_TYPE ObjectTypeCode,
		P_TRANS.OBJECT Object, P_TRANS.SUB_OBJ SubObject, P_TRANS.BAL_TYPE BalType, P_TRANS.DOC_TYPE DocType, 
		P_TRANS.DOC_ORIGIN DocOrigin, P_TRANS.DOC_NUM DocNum, P_TRANS.Doc_Track_Num DocTrackNum,
		P_TRANS.INITR_ID InitrID, P_TRANS.INIT_DATE InitDate, P_TRANS.SEQUENCE_NUM as LineSquenceNumber, P_TRANS.Line_Desc LineDesc, P_TRANS.LINE_AMT LineAmount,
		P_TRANS.Project, P_TRANS.Org_Ref_Num OrgRefNum, PRIOR_DOC_TYPE as PriorDocTypeNum, PRIOR_DOC_ORIGIN as PriorDocOriginCd, PRIOR_DOC_NUM as PriorDocNum,
		P_TRANS.Encum_Updt_Cd EncumUpdtCd, P_TRANS.Reversal_Date ReversalDate, P_TRANS.SrcTblCd,
		CONVERT([char](4),P_TRANS.YEAR,(0)) + ''|'' + ''--'' + ''|'' + P_TRANS.CHART + ''|'' + P_TRANS.ORG_ID as Organization_FK,
		CONVERT([char](4),P_TRANS.YEAR,(0)) + ''|'' + ''--'' + ''|'' + P_TRANS.CHART + ''|'' + P_TRANS.ACCT_ID as Accounts_FK,
		CONVERT([char](4),P_TRANS.YEAR,(0)) + ''|'' +                  P_TRANS.CHART + ''|'' + P_TRANS.OBJECT Objects_FK,
		CONVERT([char](4),P_TRANS.YEAR,(0)) + ''|'' + ''--'' + ''|'' + P_TRANS.CHART + ''|'' + P_TRANS.ACCT_ID + ''|'' + P_TRANS.OBJECT + ''|'' + P_TRANS.SUB_OBJ as Sub_Object_FK,
		CONVERT([char](4),P_TRANS.YEAR,(0)) + ''|'' + ''--'' + ''|'' + P_TRANS.CHART + ''|'' + P_TRANS.ACCT_ID + ''|'' + P_TRANS.SUB_ACCT as Sub_Account_FK,
		CONVERT([char](4),P_TRANS.YEAR,(0)) + ''|'' + ''--'' + ''|'' + P_TRANS.CHART + ''|'' + P_TRANS.Project as Project_FK,
		Is_CAES IsCAES,
		(
			CONVERT(CHAR(4),[Year]) + ''|'' +
			[Period] + ''|'' +
			[Chart] + ''|'' +
			ACCT_ID + ''|'' +
			SUB_ACCT + ''|'' +
			ISNULL(OBJECT_TYPE,''--'') + ''|'' +
			ISNULL([Object],''----'') + ''|'' +
			SUB_OBJ + ''|'' +
			BAL_TYPE + ''|'' +
			RTRIM(DOC_TYPE) + ''|'' +
			DOC_ORIGIN + ''|'' +
			RTRIM(DOC_NUM) + ''|'' +
			RTRIM(ISNULL([Doc_Track_Num],'''')) + ''|'' +
			CONVERT(varchar(10), SEQUENCE_NUM) + ''|'' + 
			''--------''
		) AS PKPendingTrans
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
			CASE WHEN O.ORG_ID IN (Select DISTINCT ORG_ID from FINANCE.ORGANIZATION_HIERARCHY where (ORG_ID_LEVEL_2 = ''''ACBS'''' OR ORG_ID_LEVEL_5 = ''''ACBS'''') AND FISCAL_YEAR = 9999 AND FISCAL_PERIOD = ''''--'''') THEN 2
				     WHEN O.ORG_ID IN (Select DISTINCT ORG_ID from FINANCE.ORGANIZATION_HIERARCHY where (ORG_ID_LEVEL_1 = ''''BIOS'''' OR ORG_ID_LEVEL_4 = ''''BIOS'''') AND FISCAL_YEAR = 9999 AND FISCAL_PERIOD = ''''--'''') THEN 0
					 ELSE 1 END AS Is_CAES		
		FROM 
			FINANCE.GL_PENDING_TRANSACTIONS P
			INNER JOIN FINANCE.ORGANIZATION_ACCOUNT A ON P.FISCAL_YEAR = A.FISCAL_YEAR AND P.FISCAL_PERIOD = A.FISCAL_PERIOD AND P.CHART_NUM = A.CHART_NUM AND P.ACCT_NUM = A.ACCT_NUM
			INNER JOIN FINANCE.ORGANIZATION_HIERARCHY O ON A.FISCAL_YEAR = O.FISCAL_YEAR AND A.FISCAL_PERIOD = O.FISCAL_PERIOD AND A.CHART_NUM = O.CHART_NUM AND A.ORG_ID = O.ORG_ID
		WHERE
			(
				(P.Chart_Num, P.acct_num) IN 
				( 
					SELECT DISTINCT 
						A.Chart_Num, A.Acct_num
					FROM 
						FINANCE.ORGANIZATION_ACCOUNT A
						INNER JOIN FINANCE.ORGANIZATION_HIERARCHY O ON A.FISCAL_YEAR = O.FISCAL_YEAR AND A.FISCAL_PERIOD = O.FISCAL_PERIOD AND A.CHART_NUM = O.CHART_NUM AND A.ORG_ID = O.ORG_ID
					WHERE
						A.FISCAL_YEAR = 9999
						AND A.FISCAL_PERIOD = ''''--''''
						AND
						(
							(O.CHART_NUM_LEVEL_1 = ''''3'''' AND O.ORG_ID_LEVEL_1 = ''''AAES'''')
							OR 
							(O.CHART_NUM_LEVEL_2 = ''''L'''' AND O.ORG_ID_LEVEL_2 = ''''AAES'''') 
							OR 
							(O.CHART_NUM_LEVEL_4 IN (''''3'''', ''''L'''') AND O.ORG_ID_LEVEL_4 = ''''AAES'''') 
							OR 
							(O.CHART_NUM_LEVEL_5 = ''''L'''' AND O.ORG_ID_LEVEL_5 = ''''AAES'''') 
							OR
							(O.CHART_NUM_LEVEL_1 = ''''3'''' AND O.ORG_ID_LEVEL_1 = ''''BIOS'''')
							OR 
							(O.CHART_NUM_LEVEL_1 = ''''L'''' AND O.ORG_ID_LEVEL_1 = ''''BIOS'''') 
							OR 
							(O.CHART_NUM_LEVEL_4 = ''''3'''' AND O.ORG_ID_LEVEL_4 = ''''BIOS'''') 
							OR 
							(O.CHART_NUM_LEVEL_4 = ''''L'''' AND O.ORG_ID_LEVEL_4 = ''''BIOS'''') 
						)					
				)
			)
	'' ) as P_TRANS
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
			SELECT @StartTime = (@EndTime)
			SELECT @EndTime = (GETDATE())
			PRINT '--Executed in ' + CONVERT(varchar(20),@EndTime - @StartTime, 114)
		END
	-------------------------------------------------------------------------
	--Rebuilding ALL table indexes if selected...
	IF @RebuildIndexes = 1
		BEGIN
			SELECT @TSQL = 'EXEC usp_RebuildAllTableIndexes @TableName = ''' + @TableName + ''', @IsDebug = ' + CONVERT(char(1), @IsDebug) + '
	'
			
			if @IsDebug = 1
				BEGIN
					--used for testing
					PRINT '--' + @TSQL
					EXEC(@TSQL)	
				END
			else
				BEGIN
					--Execute the command:
					EXEC(@TSQL)
				END
		END
	IF @IsDebug =
	 0
		BEGIN
			SELECT @StartTime = (@TempTime)
			SELECT @EndTime = (GETDATE())
			PRINT '--Total Execution time Start time for EXEC usp_DownloadPendingTransactions:
--' + CONVERT(varchar(20),@EndTime - @StartTime, 114)
		END
