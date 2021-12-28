


-- =============================================
-- Author:		Ken Taylor
-- Create date: December 13, 2019
-- Description:	Merges the GL Applied Transactions into our FISDataMart table 
--	so we can use it for figuring out the VETM OP Fund Expenses, since we
--	do not normally load VETM GL Applied Transactional information into our 
--	local FISDataMart.
--
-- Usage:
/*

USE [FISDataMart]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[usp_MergeVetMedTransactions]
		@FiscalYear = 2020,
		@IsDebug = 1

SELECT	'Return Value' = @return_value

GO

*/
-- Modifications:
--	2021-06-30 by kjt: Replaced @FiscalYear literal with ' + CONVERT(char(4), @FiscalYear) + ', as was intended.
--
-- =============================================
CREATE PROCEDURE [dbo].[usp_MergeVetMedTransactions] 
	@FiscalYear int = 2018, 
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    DECLARE @TSQL varchar(MAX) = ''

	SELECT @TSQL = '
merge Trans as Trans
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
			0 AS Is_CAES
		FROM 
			FINANCE.GL_APPLIED_TRANSACTIONS A
			INNER JOIN (
			select oa.CHART_NUM, oa.ACCT_NUM
 from ORGANIZATION_HIERARCHY oh
inner join ORGANIZATION_ACCOUNT oa on 
    oa.CHART_NUM = oh.CHART_NUM and 
    oa.ORG_ID = oh.ORG_ID and
    oa.FISCAL_YEAR = oh.FISCAL_YEAR and
    oa.FISCAL_PERIOD = oh.FISCAL_PERIOD
inner join FINANCE.OP_FUND f ON 
    f.FISCAL_YEAR = oa.FISCAL_YEAR and 
    f.FISCAL_PERIOD = oa.FISCAL_PERIOD and 
    f.OP_LOCATION_CODE = oa.OP_LOCATION_CODE and 
    f.OP_FUND_NUM = oa.OP_FUND_NUM 
   
INNER JOIN FINANCE.AWARD A ON 
    a.UC_LOC_CD = f.OP_LOCATION_CODE AND
    a.UC_FUND_NBR = f.OP_FUND_NUM AND
    a.fiscal_year = f.FISCAL_YEAR AND
    a.fiscal_period = f.FISCAL_PERIOD  
where 
    oh.FISCAL_YEAR = 9999 and oh.FISCAL_PERIOD = ''''--'''' and 
    oh.ORG_ID_LEVEL_4 = ''''VETM'''' AND 
    (oa.HIGHER_ED_FUNC_CODE IN (''''ORES'''', ''''OAES'''') OR SUBSTR(oa.A11_ACCT_NUM,1, 2) BETWEEN ''''44'''' AND ''''59'''')
GROUP by oh.FISCAL_YEAR, oh.FISCAL_PERIOD, f.OP_LOCATION_CODE, f.OP_FUND_NUM, oh.ORG_ID_LEVEL_4, oa.CHART_NUM, oa.ACCT_NUM , f.AWARD_BEGIN_DATE, f.AWARD_END_DATE
			) t1 ON A.Chart_Num = t1.Chart_Num AND A.Acct_Num = t1.Acct_Num
			WHERE
			A.OBJECT_NUM NOT IN (''''0054'''', ''''0520'''', ''''9998'''', ''''HIST'''') AND
			A.BALANCE_TYPE_CODE IN (''''AC'''') AND
					((A.FISCAL_YEAR = ' + CONVERT(varchar(4), @FiscalYear) + ' and a.fiscal_period between ''''04'''' AND ''''13'''') OR  
					(A.FISCAL_YEAR = ' + CONVERT(varchar(4), @FiscalYear + 1) + ' and a.fiscal_period between ''''01'''' AND ''''03''''))
					AND (A.BALANCE_TYPE_CODE NOT IN (''''PE'''', ''''RE'''')) 	/*limit used in VFP datamart*/
					AND NOT (A.OBJECT_NUM IN (SELECT DISTINCT OBJECT_NUM FROM FINANCE.OBJECT_REPORTING))
			'')  
		) FIS_DS_TRANS on Trans.PKTrans = FIS_DS_TRANS.PKTrans
/*
-- We should''nt have any new VETM transactions that need to be updated,
-- so the following section is commented out:
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
	IF @IsDebug = 1  
		PRINT @TSQL
	ELSE 
		EXEC(@TSQL)


	SELECT @TSQL = '
UPDATE trans
SET IsCAES = CASE
	  WHEN  (chart = ''3'' and account in (select distinct account from accounts a where year = ' + CONVERT(char(4), @FiscalYear) + ' AND chart = ''3'' and IsCAES = 0))
            OR
            (chart = ''L'' and account in (select distinct account from accounts a where year = ' + CONVERT(char(4), @FiscalYear) + ' AND chart = ''L'' and IsCAES = 0))
      THEN 0
      WHEN  (chart = ''3'' and account in (select distinct account from accounts a where year = ' + CONVERT(char(4), @FiscalYear) + ' AND chart = ''3'' and IsCAES = 2))
            OR
            (chart = ''L'' and account in (select distinct account from accounts a where year = ' + CONVERT(char(4), @FiscalYear) + ' AND chart = ''L'' and IsCAES = 2))
      THEN 2
      ELSE 1 END
 WHERE IsCAES IS NULL
'
	IF @IsDebug = 1  
		PRINT @TSQL
	ELSE 
		EXEC(@TSQL)

END