
CREATE PROCEDURE [dbo].[Step1]
AS
BEGIN
		-- Truncate the log file:
	ALTER DATABASE FISDataMart SET RECOVERY SIMPLE
	ALTER DATABASE FISDataMart SET RECOVERY FULL


--DownloadFISDataMart started at: 11:06:32:657
--Calling EXEC usp_DownloadAccountTypes @IsDebug = 1
--IsDebug = True

print '--Truncating table AccountType...'
TRUNCATE TABLE FISDataMart.dbo.AccountType;

print '--Downloading all AccountType records...'
INSERT INTO FISDataMart.dbo.AccountType(AccountType, AccountTypeName, LastUpdateDate)
SELECT 
	ACCOUNT_TYPE_CODE AccountType,
	ACCOUNT_TYPE_NAME AccountTypeName,
    DS_LAST_UPDATE_DATE as LastUpdateDate
 FROM OPENQUERY(FIS_DS, 
	'SELECT 
		ACCT_TYPE_CODE ACCOUNT_TYPE_CODE,
		ACCT_TYPE_NAME ACCOUNT_TYPE_NAME,
		DS_LAST_UPDATE_DATE
	FROM FINANCE.ACCOUNT_TYPE
	')
--Calling EXEC usp_DownloadBalanceTypes @IsDebug = 1
--IsDebug = True
print '--Truncating table BalanceTypes...'
TRUNCATE TABLE FISDataMart.dbo.BalanceTypes;
	
	print '--Downloading all BalanceTypes records...'
INSERT INTO FISDataMart.dbo.BalanceTypes (
	   [BalanceTypeCode]
      ,[BalanceTypeName]
      ,[BalanceCategoryCode]
      ,[BalanceCategoryName]
      ,[BalanceReportingTypeCode]
      ,[LastUpdateDate])
SELECT 
	BALANCE_TYPE_CODE as BalanceTypeCode,
	BALANCE_TYPE_NAME as BalanceTypeName,
	BALANCE_CATEGORY_CODE as BalanceCategoryCode,
	BALANCE_CATEGORY_NAME as BalanceCategoryName,
	BALANCE_REPORTING_TYPE as BalanceReportingTypeCode,
    DS_LAST_UPDATE_DATE as LastUpdateDate
 FROM OPENQUERY(FIS_DS, 
	'SELECT BALANCE_TYPE_CODE,
	         BALANCE_TYPE_NAME,
	         CASE WHEN BALANCE_CATEGORY_NAME LIKE ''%Approp%'' THEN ''AP''
	         WHEN BALANCE_CATEGORY_NAME LIKE ''%Encumb%'' THEN ''EN''
	         WHEN BALANCE_CATEGORY_NAME LIKE ''%Expend%'' THEN ''EX''
	         ELSE ''--''
	         END AS BALANCE_CATEGORY_CODE,
			 BALANCE_CATEGORY_NAME,
			 BALANCE_REPORTING_TYPE,
			 DS_LAST_UPDATE_DATE
	FROM FINANCE.BALANCE_TYPE_REPORTING
	'
	)
--Calling EXEC usp_DownloadBillingIDConversions @IsDebug = 1
--IsDebug = True
print '--Truncating table BillingIDConversions...'
TRUNCATE TABLE FISDataMart.dbo.BillingIDConversions;

print '--Downloading BillingIDConversions records...'
INSERT INTO FISDataMart.dbo.BillingIDConversions(
	   [BillingID]
      ,[Chart]
      ,[Account]
      ,[SubAccount]
      ,[OrgID]
      ,[ProjectNumTransLine]
      ,[EffectiveDate]
      ,[ExpirationDate]
      ,[Comments]
      ,[LastUpdateDate])
SELECT 
	Billing_ID as BillingID,
	Chart_Num as Chart,
	Account_Num as Account,
	Sub_Account as SubAccount,
	Org_ID as OrgID,
	Project_Num_Trans_Line as ProjectNumTransLine,
	Effective_Date as EffectiveDate,
	Expiration_Date as ExpirationDate,
	Comments,
	Last_Update_Date as LastUpdateDate

 FROM
	OPENQUERY 
		(FIS_DS,
		'SELECT 
			BID.BILLING_ID 					  Billing_ID ,                
			BID.CHART_NUM 					  Chart_Num ,                 
			BID.ACCT_NUM 					  Account_Num ,                  
			BID.SUB_ACCT_NUM 				  Sub_Account ,              
			BID.ORG_ID 						  Org_ID ,                    
			BID.TRANS_LINE_PROJECT_NUM 		  Project_Num_Trans_Line ,    
			BID.BILLING_ID_EFFECTIVE_DATE 	  Effective_Date , 
			BID.BILLING_ID_EXPIRATION_DATE 	  Expiration_Date ,
			BID.BILLING_ID_COMMENTS 		  Comments ,       
			BID.BILLING_ID_LAST_UPDATE_DATE   Last_Update_Date 
		FROM
			FINANCE.BILLING_ID_CONVERSION BID,
			Finance.Organization_Hierarchy O 
		WHERE 
			BID.CHART_NUM = O.CHART_NUM
			AND BID.ORG_ID = O.ORG_ID
			AND O.FISCAL_YEAR=9999 
			AND O.FISCAL_PERIOD = ''--''
			AND
				(
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
					OR BID.acct_num in (''EVOR094'',''MBOR039'',''MIOR017'',''NPOR035'',''PBOR023'',''BSOR001'',''BSFACOR'',''BSRESCH'',''CNSOR05'',''EVOR093'',''PBHB024'',''PBHBSAL'')
				)
				'
		)
--Calling EXEC usp_DownloadDocumentOriginCodes @IsDebug = 1
--IsDebug = True
print '--Truncating table DocumentOriginCodes'
TRUNCATE TABLE FISDataMart.dbo.DocumentOriginCodes;

print '--Downloading all DocumentOriginCodes records...'
INSERT INTO FISDataMart.dbo.DocumentOriginCodes(
	   [DocumentOriginCode]
      ,[OriginCodeDescription]
      ,[DocumentOriginDatabaseName]
      ,[DocumentOriginServerName]
      ,[DefaultChart]
      ,[DefaultAccount]
      ,[DefaultObject]
      ,[GLEContactEmail]
      ,[ReferenceControlManagerDaFisId]
      ,[LastUpdateDate])
SELECT 
	DOC_ORIGIN_CODE as DocumentOriginCode,
	DOC_ORIGIN_CODE_DESC as OriginCodeDescription,
	DOC_ORIGIN_DATABASE_NAME as DocumentOriginDatabaseName,
	DOC_ORIGIN_SERVER_NAME as DocumentOriginServerName,
	DEFAULT_CHART_NUM as DefaultChart,
	DEFAULT_ACCT_NUM as DefaultAccount,
	DEFAULT_OBJECT_NUM as DefaultObject,
	GLE_CONTACT_EMAIL_ID as GLEContactEmail,
	REFERENCE_CONTROL_MGR_DAFIS_ID as ReferenceControlManagerDaFisId,
    GETDATE() as LastUpdateDate
 FROM OPENQUERY(FIS_DS, 
	'SELECT 
		DOC_ORIGIN_CODE,
		DOC_ORIGIN_CODE_DESC,
		DOC_ORIGIN_DATABASE_NAME,
		DOC_ORIGIN_SERVER_NAME,
		DEFAULT_CHART_NUM,
		DEFAULT_ACCT_NUM,
		DEFAULT_OBJECT_NUM,
		GLE_CONTACT_EMAIL_ID,
		REFERENCE_CONTROL_MGR_DAFIS_ID
	FROM FINANCE.origin_code
	ORDER BY DOC_ORIGIN_CODE
	')
--Calling EXEC usp_DownloadDocumentTypes @IsDebug = 1
--IsDebug = True
print '--Truncating table DocumentTypes...'
TRUNCATE TABLE  [FISDataMart].[dbo].[DocumentTypes];

print '--Downloading all DocumentTypes records...'
INSERT INTO [FISDataMart].[dbo].[DocumentTypes](
	   [DocumentType]
      ,[DocumentTypeName]
      ,[DocumentGroupCode]
      ,[DocumentGroupName]
      ,[DocumentSubsystemCode]
      ,[DocumentActiveIndicator]
      ,[ChartManagerRoutingIndicator]
      ,[AccountManagerRoutingIndicator]
      ,[ReviewHierarchyRoutingIndicator]
      ,[SpecialConditionsRoutingIndicator]
      ,[LastUpdateDate])
SELECT 
	DOC_TYPE_NUM as DocumentTypes,
	DOC_TYPE_NAME as DocumentType,
	DOC_GROUP_CODE as DocumentGroupCode,
	DOC_GROUP_NAME as DocumentGroupName,
	DOC_SUBSYSTEM_CODE as DocumentSubsystemCode,
	DOC_ACTIVE_IND as DocumentActiveIndicator,
	CHART_MGR_ROUTING_IND as ChartManagerRoutingIndicator,
	ACCT_MGR_ROUTING_IND as AccountManagerRoutingIndicator,
	REVIEW_HIERARCHY_ROUTING_IND as ReviewHierarchyRoutingIndicator,
	SPECIAL_CONDITIONS_ROUTING_IND as SpecialConditionsRoutingIndicator,
    DS_LAST_UPDATE_DATE as LastUpdateDate
FROM OPENQUERY(FIS_DS, 
	'SELECT 
		DOC_TYPE_NUM,
		DOC_TYPE_NAME,
		DOC_GROUP_CODE,
		DOC_GROUP_NAME,
		DOC_SUBSYSTEM_CODE,
		DOC_ACTIVE_IND,
		CHART_MGR_ROUTING_IND,
		ACCT_MGR_ROUTING_IND,
		REVIEW_HIERARCHY_ROUTING_IND,
		SPECIAL_CONDITIONS_ROUTING_IND,
		DS_LAST_UPDATE_DATE
	FROM FINANCE.DOCUMENT_TYPE
	ORDER BY DOC_TYPE_NUM
	')
--Calling EXEC usp_DownloadFundGroups @IsDebug = 1
--IsDebug = True
print '--Truncating table FundGroups...'
TRUNCATE TABLE [FISDataMart].[dbo].[FundGroups];

print '--Downloading all FundGroups records...'
INSERT INTO [FISDataMart].[dbo].[FundGroups](
	   [FundGroup]
      ,[FundGroupName]
      ,[LastUpdateDate])
SELECT 
	FUND_GROUP_CODE as FundGroup,
	FUND_GROUP_NAME as FundGroupName,
    DS_LAST_UPDATE_DATE as LastUpdateDate
FROM OPENQUERY(FIS_DS, 
	'SELECT 
		FUND_GROUP_CODE,
		FUND_GROUP_NAME,
		DS_LAST_UPDATE_DATE
	FROM FINANCE.FUND_GROUP
	ORDER BY FUND_GROUP_CODE
	')
--Calling EXEC usp_DownloadHigherEducationFunctionCodes @IsDebug = 1

Print '-- Truncating table dbo.HigherEducationFunctionCodes...'
TRUNCATE TABLE dbo.HigherEducationFunctionCodes
	
Print '-- Reloading table dbo.HigherEducationFunctionCodes...'
INSERT INTO dbo.HigherEducationFunctionCodes (
	[HigherEducationFunctionCode]
   ,[HigherEducationFunctionName]
   ,[LastUpdateDate])
SELECT 
	HIGHER_ED_FUNC_CODE, 
	HIGHER_ED_FUNC_NAME, 
	DS_LAST_UPDATE_DATE from OPENQUERY (FIS_DS,
		'SELECT 
			HIGHER_ED_FUNC_CODE, 
			HIGHER_ED_FUNC_NAME, 
			DS_LAST_UPDATE_DATE
		from FINANCE.higher_ed_function_code
		ORDER BY higher_ed_func_code')
		
--Calling EXEC usp_DownloadObjectSubTypes @IsDebug = 1

Print '-- Truncating table [dbo].[ObjectSubTypes]...'
TRUNCATE TABLE [dbo].[ObjectSubTypes]

Print '-- Reloading table [dbo].[ObjectSubTypes]...'
INSERT INTO [FISDataMart].[dbo].[ObjectSubTypes]
(
	   [ObjectSubType]
      ,[ObjectSubTypeName]
      ,[LastUpdateDate]
)

SELECT [ObjectSubType]
      ,[ObjectSubTypeName]
      ,[LastUpdateDate]
FROM OPENQUERY(FIS_DS, 
	'SELECT 
		OBJECT_SUB_TYPE_CODE OBJECTSUBTYPE,
		OBJECT_SUB_TYPE_NAME OBJECTSUBTYPENAME,
		DS_LAST_UPDATE_DATE LASTUPDATEDATE
	FROM FINANCE.OBJECT_SUB_TYPE
	ORDER BY OBJECTSUBTYPE
')
--Calling EXEC usp_DownloadObjectTypes @IsDebug = 1

Print '-- Truncating table [dbo].[ObjectTypes]...'
TRUNCATE TABLE [dbo].[ObjectTypes]

Print '-- Reloading table [dbo].[ObjectTypes]...'
INSERT INTO [FISDataMart].[dbo].[ObjectTypes]
(
	   [ObjectType]
      ,[ObjectTypeName]
      ,[LastUpdateDate]
)

SELECT [ObjectType]
      ,[ObjectTypeName]
      ,[LastUpdateDate]
FROM OPENQUERY(FIS_DS, 
	'SELECT 
		OBJECT_TYPE_CODE OBJECTTYPE,
		OBJECT_TYPE_NAME OBJECTTYPENAME,
		DS_LAST_UPDATE_DATE LASTUPDATEDATE
	FROM FINANCE.OBJECT_TYPE
	ORDER BY OBJECTTYPE
')
--Calling EXEC usp_DownloadSubFundGroupTypes @IsDebug = 1

TRUNCATE TABLE [dbo].[SubFundGroupTypes]
Print '-- Truncating table [dbo].[SubFundGroupTypes]...'

Print '-- Reloading table [dbo].[SubFundGroupTypes]...'
INSERT INTO FISDataMart.dbo.[SubFundGroupTypes]
(
       [SubFundGroupType]
      ,[SubFundGroupTypeName]
      ,[ContractsAndGrantsFlag]
      ,[SponsoredFundFlag]
      ,[FederalFundsFlag]
      ,[GiftFundsFlag]
      ,[AwardOwnershipCodeRequiredFlag]
      ,[FundEndDateRequiredFlag]
      ,[PaymentMediumCodeRequiredFlag]
      ,[CostTransferRequiredFlag]
)
SELECT 
	   [SubFundGroupType]
      ,[SubFundGroupTypeName]
      ,[ContractsAndGrantsFlag]
      ,[SponsoredFundFlag]
      ,[FederalFundsFlag]
      ,[GiftFundsFlag]
      ,[AwardOwnershipCodeRequiredFlag]
      ,[FundEndDateRequiredFlag]
      ,[PaymentMediumCodeRequiredFlag]
      ,[CostTransferRequiredFlag]
     
 FROM OPENQUERY(FIS_DS, 
	'SELECT 
	   SUB_FUND_GROUP_TYPE_CODE SubFundGroupType
      ,SUB_FUND_GROUP_TYPE_NAME SubFundGroupTypeName
      ,CONTRACTS_AND_GRANTS_IND ContractsAndGrantsFlag
      ,SPONSORED_IND SponsoredFundFlag
      ,FEDERAL_IND FederalFundsFlag
      ,GIFT_IND GiftFundsFlag
      ,AWARD_OWNERSHIP_CODE_REQ_IND AwardOwnershipCodeRequiredFlag
      ,AWARD_END_DATE_REQ_IND FundEndDateRequiredFlag
      ,PAYMENT_MEDIUM_CODE_REQ_IND PaymentMediumCodeRequiredFlag
      ,COST_TRANSFER_REQ_CODE CostTransferRequiredFlag
	FROM FINANCE.SUB_FUND_GROUP_TYPE
	ORDER BY SubFundGroupType
	')
END