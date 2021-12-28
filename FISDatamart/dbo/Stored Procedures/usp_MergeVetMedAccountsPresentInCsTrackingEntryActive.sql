
-- =============================================
-- Author:		Ken Taylor
-- Create date: December 16, 2019
-- Description:	Merges the CsTrackingEntryActive table so we can use it for figuring out
-- the AAES, BIOS, and VETM Scientist Years and AAES, BIOS, and VETM Cost Share Scientist Years,
--  since we do not perform a nightly load of the FIS CS_TRACKING_ENTRY_ACTIVE information into
 -- our local FIS DataMart except for when we're ready create a new set of Animal Health Reports.
 --
-- Usage:
/*

USE [FISDataMart]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[usp_MergeVetMedAccountsPresentInCsTrackingEntryActive]
		@FiscalYear = 2018,
		@IsDebug = 1

SELECT	'Return Value' = @return_value

GO

*/
-- Modifications
--  2019-12-16 by kjt: Revised the matching keys to include TrackingEntryTypeCode and 
--	CreateDate.
--
-- =============================================
CREATE PROCEDURE [dbo].[usp_MergeVetMedAccountsPresentInCsTrackingEntryActive]
	@FiscalYear int = 2018, 
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    DECLARE @TSQL varchar(MAX) = ''

	SELECT @TSQL = '
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
	OPFund_FK, Is_CAES, FFT_Code
	FROM
		OPENQUERY (FIS_DS,''
		SELECT
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
			(A.FISCAL_YEAR || ''''|'''' || A.FISCAL_PERIOD || ''''|'''' || A.CHART_NUM || ''''|'''' || A.ACCT_NUM) Account_PK,
			(A.FISCAL_YEAR || ''''|'''' || A.FISCAL_PERIOD || ''''|'''' || A.CHART_NUM || ''''|'''' || A.ORG_ID) Org_FK,
			(A.FISCAL_YEAR || ''''|'''' || A.FISCAL_PERIOD || ''''|'''' || A.CHART_NUM || ''''|'''' || A.OP_FUND_NUM) OPFund_FK,
			0 AS Is_CAES,
			A.FFT_Code
		FROM
			FINANCE.ORGANIZATION_ACCOUNT A 
			INNER JOIN (
				select DISTINCT oa.CHART_NUM, oa.ACCT_NUM
 from ORGANIZATION_HIERARCHY oh
inner join ORGANIZATION_ACCOUNT oa on 
    oa.CHART_NUM = oh.CHART_NUM and 
    oa.ORG_ID = oh.ORG_ID and
    oa.FISCAL_YEAR = oh.FISCAL_YEAR and
    oa.FISCAL_PERIOD = oh.FISCAL_PERIOD
--inner join FINANCE.OP_FUND f ON 
--    f.FISCAL_YEAR = oa.FISCAL_YEAR and 
--    f.FISCAL_PERIOD = oa.FISCAL_PERIOD and 
--    f.OP_LOCATION_CODE = oa.OP_LOCATION_CODE and 
--    f.OP_FUND_NUM = oa.OP_FUND_NUM 
--INNER JOIN FINANCE.AWARD A ON 
--    a.UC_LOC_CD = f.OP_LOCATION_CODE AND
--    a.UC_FUND_NBR = f.OP_FUND_NUM AND
--    a.fiscal_year = f.FISCAL_YEAR AND
--    a.fiscal_period = f.FISCAL_PERIOD  
INNER JOIN FINANCE.CS_TRACKING_ENTRY_ACTIVE te ON
	te.CHART_NUM = oa.CHART_NUM AND te.ACCT_NUM = oa.ACCT_NUM AND
	te.REMOVED_DATE IS NULL AND te.START_FISCAL_YEAR >= 2016 
where 
    oh.FISCAL_YEAR = 9999 and oh.FISCAL_PERIOD = ''''--'''' and 
    oh.ORG_ID_LEVEL_4 = ''''VETM'''' AND START_FISCAL_YEAR >= 2016 
	) t1 ON t1.CHART_NUM = A.CHART_NUM AND t1.ACCT_NUM = A.ACCT_NUM
	WHERE A.Fiscal_Year = 9999 and A.Fiscal_Period = ''''--''''
		'')
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
	  ,[FftCode] = FFT_Code
      
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
	Ye_Type,Account_PK,Org_FK, null, OPFund_FK, Is_CAES, FFT_Code
);
'

	IF @IsDebug = 1  
		PRINT @TSQL
	ELSE 
		EXEC(@TSQL)
END