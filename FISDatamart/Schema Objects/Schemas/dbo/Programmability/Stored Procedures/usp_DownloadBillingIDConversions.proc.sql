/*
Modifications:
	2011-02-03 by kjt:
		Revised orgainzation selection logic to correctly handle BIOS chart 'L'. 
*/
CREATE Procedure [dbo].[usp_DownloadBillingIDConversions]
(
	@IsDebug bit = 0 -- Set to 1 just print the SQL and not actually execute. 
)
AS

--local:
declare @TSQL varchar(MAX)	--Holds T-SQL code to be run with EXEC() function.
	
print '--IsDebug = ' + CASE @IsDebug WHEN 1 THEN 'True' ELSE 'False' END
	
select @TSQL = 
	'print ''--Truncating table BillingIDConversions...''
TRUNCATE TABLE FISDataMart.dbo.BillingIDConversions;

print ''--Downloading BillingIDConversions records...''
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
		''SELECT 
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
			AND O.FISCAL_PERIOD = ''''--''''
			AND
				(
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
						)
					OR BID.acct_num in (''''EVOR094'''',''''MBOR039'''',''''MIOR017'''',''''NPOR035'''',''''PBOR023'''',''''BSOR001'''',''''BSFACOR'''',''''BSRESCH'''',''''CNSOR05'''',''''EVOR093'''',''''PBHB024'''',''''PBHBSAL'''')
				)
				''
		)'

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
