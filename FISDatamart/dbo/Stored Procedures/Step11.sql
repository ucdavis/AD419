
CREATE PROCEDURE [dbo].[Step11]
AS
BEGIN
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
	  CONVERT(CHAR(4),[Year]) + '|' +
      [Period] + '|' +
      [Chart] + '|' +
      [ACCT_ID] + '|' +
      [SUB_ACCT] + '|' +
      [OBJECT_TYPE_CODE] + '|' +
      [Object] + '|' +
      [SUB_OBJ] + '|' +
      [BAL_TYPE] + '|' +
      RTRIM([DOC_TYPE]) + '|' +
      [DOC_ORIGIN] + '|' +
      RTRIM([DOC_NUM]) + '|' +
      RTRIM(ISNULL([Doc_Track_Num],'')) + '|' +
      CONVERT(varchar(10), [LINE_SQUENCE_NUM]) + '|' +
      CONVERT(varchar(20), [POST_DATE], 112)  as PKTrans
	FROM OPENQUERY (FIS_DS, 
			'SELECT 
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
			''A'' SrcTblCd,
			A.FISCAL_YEAR || ''|'' ||  ''--'' || ''|'' ||  A.CHART_NUM || ''|'' || A.ORG_ID Organization_FK,
			A.FISCAL_YEAR || ''|'' ||  ''--'' || ''|'' || A.CHART_NUM  || ''|'' || A.ACCT_NUM Accounts_FK,
			A.FISCAL_YEAR || ''|'' ||  A.CHART_NUM || ''|'' || OBJECT_NUM Objects_FK,
			A.FISCAL_YEAR || ''|'' ||  ''--'' || ''|'' || A.CHART_NUM || ''|'' || A.ACCT_NUM || ''|'' || OBJECT_NUM || ''|'' || A.SUB_OBJECT_NUM Sub_Object_FK,
			A.FISCAL_YEAR || ''|'' ||  ''--'' || ''|'' || A.CHART_NUM || ''|'' || A.ACCT_NUM || ''|'' || A.SUB_ACCT_NUM Sub_Account_FK,
			A.FISCAL_YEAR || ''|'' ||  ''--'' || ''|'' || A.CHART_NUM || ''|'' || A.TRANS_LINE_PROJECT_NUM Project_FK,
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
							A.FISCAL_YEAR >= 2011
						)	
						AND 
						(
							(A.CHART_NUM, A.ORG_ID) IN 
							(
								SELECT  DISTINCT CHART_NUM, ORG_ID 
								FROM FINANCE.ORGANIZATION_HIERARCHY O
								WHERE
								(
									(CHART_NUM_LEVEL_1=''3'' AND ORG_ID_LEVEL_1 = ''AAES'')
									OR
									(CHART_NUM_LEVEL_2=''L'' AND ORG_ID_LEVEL_2 = ''AAES'')
									
									OR
									(ORG_ID_LEVEL_1 = ''BIOS'')
									
									OR 
									(CHART_NUM_LEVEL_4 = ''3'' AND ORG_ID_LEVEL_4 = ''AAES'')
									OR
									(CHART_NUM_LEVEL_5 = ''L'' AND ORG_ID_LEVEL_5 = ''AAES'')
									
									OR
									(ORG_ID_LEVEL_4 = ''BIOS'')
								)
								AND
								(
									FISCAL_YEAR >= 2011
								)
							)
						)
					)
				)
				AND
				(
					A.FISCAL_YEAR >= 2011 
					AND (A.BALANCE_TYPE_CODE NOT IN (''PE'', ''RE'')) 	/*limit used in VFP datamart*/
					AND NOT (A.OBJECT_NUM IN (SELECT DISTINCT OBJECT_NUM FROM FINANCE.OBJECT_REPORTING))
				)
			')  
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
END