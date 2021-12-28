--DROP  PROCEDURE [dbo].[Step2]

CREATE PROCEDURE [dbo].[Step2]
AS
BEGIN
merge Accounts as Accounts
using
(
	SELECT
	Fiscal_Year, Fiscal_Period, Chart_Num,Account_Num,
	Org_ID,Account_Name,SubFund_Group_Num,Sub_Fund_Group_Type_Code,
	Fund_Group_Code,Acct_Effective_Date,Acct_Create_Date,Acct_Expiration_Date,
	Acct_Last_Update_Date,Acct_Mgr_Id,Acct_Mgr_Name,Acct_Reviewer_Id, Acct_Reviewer_Name,
	Principal_Investigator_Id, Principal_Investigator_Name,
	Acct_Type_Code, Acct_Purpose_Text, Control_Chart_Num,Control_Acct_Num,Sponsor_Code,
	Sponsor_Category_Code,Federal_Agency_Code,CFDA_Num,Award_Num,
	Award_Type_Code,Award_Year_Num,Award_Begin_Date, Award_End_Date, Award_Amount,
	ICR_Type_Code,ICR_Series_Num,Higher_Ed_Func_Code,Acct_Reports_To_Chart_Num,
	Acct_Reports_To_Acct_Num,A11_Acct_Num,A11_Fund_Num,OP_Fund_Num,
	OP_Fund_Group_Code, Academic_Discipline_Code,Annual_Report_Code,
	Payment_Medium_Code,NIH_Doc_Num, 
	fringe_benefit_ind,fringe_benefit_chart_num,fringe_benefit_acct_num,
	null as Ye_Type,Account_PK,Org_FK, null as FunctionCodeID,
	OPFund_FK, Is_CAES, Fft_Code
	
	 FROM
		OPENQUERY (FIS_DS,
		'SELECT
			A.FISCAL_YEAR Fiscal_Year,
			A.FISCAL_PERIOD Fiscal_Period,
			A.CHART_NUM Chart_Num,
			A.ORG_ID Org_ID,
			A.ACCT_NUM Account_Num,
			A.ACCT_NAME Account_Name,
			A.SUB_FUND_GROUP_NUM SubFund_Group_Num,
			A.FUND_GROUP_CODE Fund_Group_Code,
			A.SUB_FUND_GROUP_TYPE_CODE Sub_Fund_Group_Type_Code,
			A.ACCT_EFFECTIVE_DATE Acct_Effective_Date,
			A.ACCT_CREATE_DATE Acct_Create_Date,
			A.ACCT_EXPIRATION_DATE Acct_Expiration_Date,
			A.ACCT_LAST_UPDATE_DATE Acct_Last_Update_Date,
			A.ACCT_MGR_ID Acct_Mgr_Id,
			A.ACCT_MGR_NAME Acct_Mgr_Name,
			A.ACCT_REVIEWER_ID Acct_Reviewer_Id,
			A.ACCT_REVIEWER_NAME Acct_Reviewer_Name,
			A.PRINCIPAL_INVESTIGATOR_ID Principal_Investigator_Id,
			A.PRINCIPAL_INVESTIGATOR_NAME Principal_Investigator_Name,
			A.ACCT_TYPE_CODE Acct_Type_Code,
			A.acct_purpose_text Acct_Purpose_Text,
			A.CONTROL_CHART_NUM Control_Chart_Num,
			A.CONTROL_ACCT_NUM Control_Acct_Num,
			A.SPONSOR_CODE Sponsor_Code,
			A.SPONSOR_CATEGORY_CODE Sponsor_Category_Code,
			A.FEDERAL_AGENCY_CODE Federal_Agency_Code,
			A.CFDA_NUM CFDA_Num,
			A.AWARD_NUM Award_Num,
			A.AWARD_TYPE_CODE Award_Type_Code,
			A.AWARD_YEAR_NUM Award_Year_Num,
			A.AWARD_BEGIN_DATE Award_Begin_Date,
			A.AWARD_END_DATE Award_End_Date,
			A.AWARD_AMT Award_Amount,
			A.ICR_TYPE_CODE ICR_Type_Code,
			A.ICR_SERIES_NUM ICR_Series_Num,
			A.HIGHER_ED_FUNC_CODE Higher_Ed_Func_Code,
			A.ACCT_REPORTS_TO_CHART_NUM Acct_Reports_To_Chart_Num,
			A.ACCT_REPORTS_TO_ACCT_NUM Acct_Reports_To_Acct_Num,
			A.A11_ACCT_NUM A11_Acct_Num,
			A.A11_FUND_NUM A11_Fund_Num,
			A.OP_FUND_NUM OP_Fund_Num,
			A.OP_FUND_GROUP_CODE OP_Fund_Group_Code,
			A.ACADEMIC_DISCIPLINE_CODE Academic_Discipline_Code,
			A.ANNUAL_REPORT_CODE Annual_Report_Code,
			A.PAYMENT_MEDIUM_CODE Payment_Medium_Code,
			A.NIH_DOC_NUM NIH_Doc_Num,
			A.fringe_benefit_ind,
			A.fringe_benefit_chart_num,
			A.fringe_benefit_acct_num,
			(A.FISCAL_YEAR || ''|'' || A.FISCAL_PERIOD || ''|'' || A.CHART_NUM || ''|'' || A.ACCT_NUM) Account_PK,
			(A.FISCAL_YEAR || ''|'' || A.FISCAL_PERIOD || ''|'' || A.CHART_NUM || ''|'' || A.ORG_ID) Org_FK,
			(A.FISCAL_YEAR || ''|'' || A.FISCAL_PERIOD || ''|'' || A.CHART_NUM || ''|'' || A.OP_FUND_NUM) OPFund_FK,
			CASE 
					 WHEN (ORG_ID_LEVEL_2 = ''ACBS'' OR ORG_ID_LEVEL_5 = ''ACBS'') THEN 2
				     WHEN (ORG_ID_LEVEL_1 = ''BIOS'' OR ORG_ID_LEVEL_4 = ''BIOS'') THEN 0
				     ELSE 1 END AS Is_CAES,
			A.FFT_CODE
		FROM
			FINANCE.ORGANIZATION_ACCOUNT A 
			INNER JOIN FINANCE.ORGANIZATION_HIERARCHY O ON 
				A.FISCAL_YEAR = O.FISCAL_YEAR AND 
				A.FISCAL_PERIOD = O.FISCAL_PERIOD AND 
				A.CHART_NUM = O.CHART_NUM AND 
				A.ORG_ID = O.ORG_ID
		WHERE (
				(
					A.FISCAL_YEAR >= 2012	
				)		
				AND (
						(A.CHART_NUM, A.ORG_ID) IN 
						(
							SELECT DISTINCT CHART_NUM, ORG_ID 
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
								FISCAL_YEAR >= 2012	
							)
						)
						--OR A.ACCT_NUM in (''EVOR094'',''MBOR039'',''MIOR017'',''NPOR035'',''PBOR023'',''BSOR001'',''BSFACOR'',''BSRESCH'',''CNSOR05'',''EVOR093'',''PBHB024'',''PBHBSAL'')
				)
			)
		')
) FIS_DS_ACCOUNTS on Accounts.AccountPK = FIS_DS_ACCOUNTS.Account_PK

WHEN MATCHED THEN UPDATE set
	   [Org] = Org_ID
      ,[AccountName] = Account_Name
      ,[SubFundGroupNum] = SubFund_Group_Num
      ,[SubFundGroupTypeCode] = Sub_Fund_Group_Type_Code
      ,[FundGroupCode] = Fund_Group_Code
      ,[EffectiveDate] = Acct_Effective_Date
      ,[CreateDate] = Acct_Create_Date
      ,[ExpirationDate] = Acct_Expiration_Date
      ,[LastUpdateDate] = Acct_Last_Update_Date
      ,[MgrId] = Acct_Mgr_Id
      ,[MgrName] = Acct_Mgr_Name
      ,[ReviewerId] = Acct_Reviewer_Id
      ,[ReviewerName] = Acct_Reviewer_Name
      ,[PrincipalInvestigatorId] = Principal_Investigator_Id
      ,[PrincipalInvestigatorName] = Principal_Investigator_Name
      ,[TypeCode] = Acct_Type_Code
      ,[Purpose] = Acct_Purpose_Text
      ,[ControlChart] = Control_Chart_Num
      ,[ControlAccount] = Control_Acct_Num
      ,[SponsorCode] = Sponsor_Code
      ,[SponsorCategoryCode] = Sponsor_Category_Code
      ,[FederalAgencyCode] = Federal_Agency_Code
      ,[CFDANum] = CFDA_Num
      ,[AwardNum] = Award_Num
      ,[AwardTypeCode] = Award_Type_Code
      ,[AwardYearNum] = Award_Year_Num
      ,[AwardBeginDate] = Award_Begin_Date
      ,[AwardEndDate] = Award_End_Date
      ,[AwardAmount] = Award_Amount
      ,[ICRTypeCode] = ICR_Type_Code
      ,[ICRSeriesNum] = ICR_Series_Num
      ,[HigherEdFuncCode] = Higher_Ed_Func_Code
      ,[ReportsToChart] = Acct_Reports_To_Chart_Num
      ,[ReportsToAccount] = Acct_Reports_To_Acct_Num
      ,[A11AcctNum] = A11_Acct_Num
      ,[A11FundNum] = A11_Fund_Num
      ,[OpFundNum] = OP_Fund_Num
      ,[OpFundGroupCode] = OP_Fund_Group_Code
      ,[AcademicDisciplineCode] = Academic_Discipline_Code
      ,[AnnualReportCode] = Annual_Report_Code
      ,[PaymentMediumCode] = Payment_Medium_Code
      ,[NIHDocNum] = NIH_Doc_Num
      ,[FringeBenefitIndicator] = fringe_benefit_ind
      ,[FringeBenefitChart] = fringe_benefit_chart_num
      ,[FringeBenefitAccount] = fringe_benefit_acct_num
      ,[YeType] = Ye_Type
      ,[OrgFK] = Org_FK
      ,[OPFundFK] = OPFund_FK
      ,[IsCAES] = Is_CAES
	  ,[FftCode] = Fft_Code
      
 WHEN NOT MATCHED BY TARGET THEN INSERT VALUES 
 (
	Fiscal_Year, Fiscal_Period, Chart_Num,Account_Num,
	Org_ID,Account_Name,SubFund_Group_Num,Sub_Fund_Group_Type_Code,
	Fund_Group_Code,Acct_Effective_Date,Acct_Create_Date,Acct_Expiration_Date,
	Acct_Last_Update_Date,
	Acct_Mgr_Id,
	Acct_Mgr_Name,Acct_Reviewer_Id, Acct_Reviewer_Name, Principal_Investigator_Id,
	Principal_Investigator_Name,
	Acct_Type_Code,Acct_Purpose_Text,Control_Chart_Num,Control_Acct_Num,Sponsor_Code,
	Sponsor_Category_Code,Federal_Agency_Code,CFDA_Num,Award_Num,
	Award_Type_Code,Award_Year_Num,Award_Begin_Date, Award_End_Date, Award_Amount,
	ICR_Type_Code,ICR_Series_Num,Higher_Ed_Func_Code,Acct_Reports_To_Chart_Num,
	Acct_Reports_To_Acct_Num,A11_Acct_Num,A11_Fund_Num,OP_Fund_Num,
	OP_Fund_Group_Code, Academic_Discipline_Code,Annual_Report_Code,
	Payment_Medium_Code,NIH_Doc_Num, 
	fringe_benefit_ind,fringe_benefit_chart_num,fringe_benefit_acct_num,
	Ye_Type,Account_PK,Org_FK, null, OPFund_FK, Is_CAES, Fft_Code
)

--WHEN NOT MATCHED BY SOURCE THEN DELETE
;
END