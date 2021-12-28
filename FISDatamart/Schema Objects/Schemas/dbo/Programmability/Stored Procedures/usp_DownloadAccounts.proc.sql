

/*
Usage:
	
	USE [FISDataMart]
	GO

	EXEC [dbo].[usp_DownloadAccounts]
	@FirstDateString = '2019-10-01',
		@GetUpdatesOnly = 0,
		@IsDebug = 1


Modifications:
	20110128 by kjt:
		Analyzed the org level and chart mapping and found that it need to be revised
		because a few of the chart L BIOS orgs were being excluded.
	2011-02-01 by kjt: 
		Removed all date logic and replaced with call to udf_GetBeginningAndLastFiscalYearToDownload instead.
	2011-02-02 by kjt: 
		Modified the date logic to handle the 9999 fiscal year.
	2011-02-23 by kjt:
		Modified logic to include setting of IsCAES field.
	2011-03-04 by kjt:
		Added logic to pass a destination table name; otherwise defaults to Accounts.
	2011-06-15 by kjt:
		Added 3 new fields relating to FringeBenefits as per Steve Pesis.
		Added "--" to comment out @NumFiscalYearsToDownload.
	2011-08-19 by kjt:
		Added 4 new fields relating to Account Manager Id, Account Reviewer Id, Principal Investigator Id, plus
		Account Reviewer Name as per Scott K. required for the new Purchasing app.
	2015-10-08 by kjt: Modifications to take into account removing DANR as level 4 ORG for chart L, and moving
		AANS up to level 4 org position.  AAES is now at Level 4 for both Chart 'L' and Chart '3' as of FY 2016. 
	2018-04-23 by kjt: Added FftCode (Federal Flow-Through code) to be abel to use with Animal Health queries.
	2021-05-03 by kjt: Expanded filtering to also included VETM Orgs as they are required for Animal Health reports.
	2921-05-05 by kjt: Removed some spaces, line feeds, and commented out logic so that all of the text was present in debug mode. 
*/
CREATE PROCEDURE [dbo].[usp_DownloadAccounts]
(
	@FirstDateString varchar(16) = null,
		--earliest date to download (FINANCE.ORGANIZATION_ACCOUNT.DS_LAST_UPDATE_DATE) 
		--optional, defaults to highest date in Accounts table
	@LastDateString varchar(16) = null,
		-- latest date to download (FINANCE.ORGANIZATION_ACCOUNT.DS_LAST_UPDATE_DATE) 
		-- optional, defaults to today's date.
	@GetUpdatesOnly bit = 1, -- Flag to determine whether to get just updated records only as opposed all
		-- records for the corresponding Fiscal Years(s).
		-- optional, defaults to getting just the updated records.
	@TableName varchar(255) = 'Accounts', --Can be passed another table name, i.e. #Accounts, etc.
	@IsDebug bit = 0 -- Set to 1 just print the SQL and not actually execute. 
)
AS

--local:
DECLARE @WhereClause varchar(MAX) = '' -- Holds the T-SQL for the where clause.
/*
	If table is empty then we'll to derive a Fiscal Year based on today's date and
	an estimated closing date for a fiscal year of August 15th for the June Final (13th) period. 
	
	We'll need to handle max-date failure cases should the table be empty. 
*/
--local:
	DECLARE @TSQL varchar(MAX)	= '' --Holds T-SQL code to be run with EXEC() function.
	DECLARE @BeginningFiscalYear int = null
	DECLARE @EndingFiscalYear int = null
	DECLARE @NumFiscalYearsToDownload smallint = null
	DECLARE @FirstDate datetime = null
	DECLARE @LastDate datetime = null
	DECLARE @RecordCount int = 0
	--DECLARE @TableName varchar(255) = 'Accounts' --Name of table being updated.
	DECLARE @TruncateTable bit = 0 --Whether or not to truncate the table before load.  This is not set from this sproc, 
	-- but left for consistency.
	DECLARE @Exclude9999FiscalYear bit = 0 --This is the only table with a 9999 fiscal year that we're not interested in. 
-------------------------------------------------------------------------------------
	DECLARE MyCursor CURSOR FOR SELECT BeginningFiscalYear, EndingFiscalYear, NumFiscalYearsToDownload, FirstDate, LastDate, RecordCount 
	FROM udf_GetBeginningAndLastFiscalYearToDownload(@TableName, @FirstDateString, @LastDateString, @NumFiscalYearsToDownload, @TruncateTable, @Exclude9999FiscalYear)
	
	OPEN MyCursor
	
	FETCH NEXT FROM MyCursor INTO @BeginningFiscalYear, @EndingFiscalYear, @NumFiscalYearsToDownload, @FirstDate, @LastDate, @RecordCount
	
	CLOSE MyCursor
	DEALLOCATE MyCursor
	
	IF @IsDebug = 1 PRINT '--@NumFiscalYearsToDownload: ' + Convert(varchar(20), @NumFiscalYearsToDownload) 
			
-------------------------------------------------------------------------------------	
-- Build the Where clause based on the dates provided:
SELECT @WhereClause = '
				(
					A.FISCAL_YEAR' +
CASE WHEN @BeginningFiscalYear <> @EndingFiscalYear AND
          @EndingFiscalYear <> 9999 THEN
' BETWEEN ' + Convert(char(4), @BeginningFiscalYear) +
		 ' AND ' + + Convert(char(4), @EndingFiscalYear)
WHEN @EndingFiscalYear = 9999 THEN
' >= ' + Convert(char(4), @BeginningFiscalYear)
ELSE 
' = ' + Convert(char(4), @BeginningFiscalYear)
END + '	
				)		'
SELECT @WhereClause += '
				AND (
						(A.CHART_NUM, A.ORG_ID) IN 
						(
							SELECT DISTINCT CHART_NUM, ORG_ID 
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
							-- 2021-05-03 by kjt: Added VETM orgs for Animal Health Reports. 
								OR 
								(CHART_NUM_LEVEL_4 IN (''''3'''', ''''L'''') AND ORG_ID_LEVEL_4 = ''''VETM'''')
							)
							AND
							(
								FISCAL_YEAR' +
								CASE WHEN @BeginningFiscalYear <> @EndingFiscalYear AND @EndingFiscalYear <> 9999 THEN
								' BETWEEN ' + Convert(char(4), @BeginningFiscalYear) +
								' AND ' + + Convert(char(4), @EndingFiscalYear)
									WHEN @EndingFiscalYear = 9999 THEN
									' >= ' + Convert(char(4), @BeginningFiscalYear)
								ELSE 
									' = ' + Convert(char(4), @BeginningFiscalYear)
								END + '	
							)
						)
				)'

-- Add the LastUpdateDate portion if appropriate: 
IF @RecordCount > 0 AND @GetUpdatesOnly = 1
BEGIN
	SELECT @WhereClause += '
				AND (A.ACCT_LAST_UPDATE_DATE ' + 
				CASE WHEN @FirstDate <> @LastDate THEN 'BETWEEN TO_DATE(''''' + Convert(varchar(10),@FirstDate,102)  + ''''' ,''''yyyy.mm.dd'''')
						AND TO_DATE(''''' + Convert(varchar(10),@LastDate,102)  + ''''' ,''''yyyy.mm.dd''''))'
				ELSE '= TO_DATE(''''' + Convert(varchar(10),@FirstDate,102)  + ''''' ,''''yyyy.mm.dd''''))' END
END

-------------------------------------------------------------------------------------
-- Display the values the sproc will actually run with:
	print '--Downloading Accounts records...'
	print '--Table ' + CASE WHEN @RecordCount = 0 THEN 'is EMPTY' ELSE 'has data' END
	print '--Earliest Date = ' + convert(varchar(30),convert(smalldatetime,@FirstDate),102)
	print '--Latest Date = ' + convert(varchar(30),convert(smalldatetime,@LastDate),102)
	print '--Fiscal Year' + CASE WHEN @BeginningFiscalYear <> @EndingFiscalYear THEN
' BETWEEN ' + Convert(char(4), @BeginningFiscalYear) +
		 ' AND ' + + Convert(char(4), @EndingFiscalYear)
ELSE
' = ' + Convert(char(4), @BeginningFiscalYear)
END 												      
	print '--IsDebug = ' + CASE @IsDebug WHEN 1 THEN 'True' ELSE 'False' END
	
-------------------------------------------------------------------------------------
select @TSQL = 
'
merge ' + @TableName + ' as Accounts
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
	OP_Fund_Group_Code, Academic_Discipline_Code,Annual_Report_Code, Payment_Medium_Code,NIH_Doc_Num, 
	fringe_benefit_ind,fringe_benefit_chart_num,fringe_benefit_acct_num,
	null as Ye_Type,Account_PK,Org_FK, null as FunctionCodeID,OPFund_FK, Is_CAES, FFT_Code
	
	 FROM
		OPENQUERY (FIS_DS,
		''SELECT
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
			CASE 
					 WHEN (ORG_ID_LEVEL_2 = ''''ACBS'''' OR ORG_ID_LEVEL_5 = ''''ACBS'''') THEN 2
				     WHEN (ORG_ID_LEVEL_1 = ''''BIOS'''' OR ORG_ID_LEVEL_4 = ''''BIOS'''') THEN 0
				     ELSE 1 END AS Is_CAES,
			A.FFT_Code
		FROM
			FINANCE.ORGANIZATION_ACCOUNT A 
			INNER JOIN FINANCE.ORGANIZATION_HIERARCHY O ON 
				A.FISCAL_YEAR = O.FISCAL_YEAR AND 
				A.FISCAL_PERIOD = O.FISCAL_PERIOD AND 
				A.CHART_NUM = O.CHART_NUM AND 
				A.ORG_ID = O.ORG_ID
		WHERE ('  + @WhereClause + '
			)
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
	Acct_Last_Update_Date, Acct_Mgr_Id, Acct_Mgr_Name,Acct_Reviewer_Id, 
	Acct_Reviewer_Name, Principal_Investigator_Id,Principal_Investigator_Name,
	Acct_Type_Code,Acct_Purpose_Text,Control_Chart_Num,Control_Acct_Num,Sponsor_Code,
	Sponsor_Category_Code,Federal_Agency_Code,CFDA_Num,Award_Num,
	Award_Type_Code,Award_Year_Num,Award_Begin_Date, Award_End_Date, Award_Amount,
	ICR_Type_Code,ICR_Series_Num,Higher_Ed_Func_Code,Acct_Reports_To_Chart_Num,
	Acct_Reports_To_Acct_Num,A11_Acct_Num,A11_Fund_Num,OP_Fund_Num,
	OP_Fund_Group_Code, Academic_Discipline_Code,Annual_Report_Code,
	Payment_Medium_Code,NIH_Doc_Num, 
	fringe_benefit_ind,fringe_benefit_chart_num,fringe_benefit_acct_num,
	Ye_Type,Account_PK,Org_FK, FunctionCodeID, OPFund_FK, Is_CAES, FFT_Code
)

--WHEN NOT MATCHED BY SOURCE THEN DELETE
;'

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
