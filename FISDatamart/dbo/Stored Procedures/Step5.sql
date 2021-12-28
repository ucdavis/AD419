-- Create procedure dbo.Step5
--PRINT N'Create procedure dbo.Step5'
--GO
--DROP  PROCEDURE [dbo].[Step5]
CREATE PROCEDURE [dbo].[Step5]
AS
BEGIN
merge OPFund as OPFund 
using
(
SELECT 
	fiscal_year,
	fiscal_period,
	op_location_code,
	op_fund_num,
	op_fund_name,
	op_fund_group_code,
	op_fund_group_name,
	sub_fund_group_num,
	award_num,
	award_type_code,
	award_year_num,
	award_begin_date,
	award_end_date,
	award_amt,
	LAST_UPDATE_DATE,
	OP_Fund_PK,
	sub_fund_group_FK,
    PRIMARY_PI_USER_NAME,
	PROJECT_TITLE,
	CFDA_NUM,
	SPONSOR_CODE,
	PRIMARY_PI_DAFIS_USER_ID
 FROM OPENQUERY(FIS_DS, 
	'SELECT 
    fiscal_year,
	fiscal_period,
	op_location_code,
	op_fund_num,
	op_fund_name,
	op_fund_group_code,
	op_fund_group_name,
	sub_fund_group_num,
	award_num,
	award_type_code,
	award_year_num,
	TO_CHAR(award_begin_date, ''yyyy-mm-dd hh:mm:ss.sssss'') award_begin_date,
	TO_CHAR(award_end_date, ''yyyy-mm-dd hh:mm:ss.sssss'') award_end_date,
	award_amt,
	ds_last_update_date LAST_UPDATE_DATE,
	fiscal_year || ''|'' || fiscal_period || ''|'' || op_location_code || ''|'' || op_fund_num as OP_Fund_PK,
	fiscal_year || ''|'' || fiscal_period || ''|'' || sub_fund_group_num as sub_fund_group_FK,
	PRIMARY_PI_USER_NAME,
	PROJECT_TITLE,
	CFDA_NUM,
	SPONSOR_CODE,
	PRIMARY_PI_DAFIS_USER_ID
FROM FINANCE.OP_FUND
	WHERE 
			OP_FUND.FISCAL_YEAR >= 2011
	')
) FIS_DS_OP_FUND on OPFund.OPFundPK = FIS_DS_OP_FUND.OP_Fund_PK

WHEN MATCHED THEN UPDATE set
	   [FundName] = op_fund_name
      ,[FundGroupCode] = op_fund_group_code
      ,[FundGroupName] = op_fund_group_name
      ,[SubFundGroupNum] = sub_fund_group_num
      ,[AwardNum] = award_num
      ,[AwardType] = award_type_code
      ,[AwardYearNum] = award_year_num
      ,[AwardBeginDate] = award_begin_date
      ,[AwardEndDate] =  award_end_date
      ,[AwardAmount] = award_amt
      ,[LastUpdateDate] = Convert(smalldatetime, LAST_UPDATE_DATE, 120)
      ,[SubFundGroupFK] = sub_fund_group_FK
	  ,[PrimaryPIUserName] = PRIMARY_PI_USER_NAME
	  ,[ProjectTitle] = PROJECT_TITLE
	  ,[CFDANum] = CFDA_NUM
	  ,[SponsorCode] = SPONSOR_CODE
	  ,[PrimaryPIDaFISUserId] = PRIMARY_PI_DAFIS_USER_ID

WHEN NOT MATCHED BY TARGET THEN INSERT VALUES 
(
	fiscal_year,
	fiscal_period,
	op_location_code,
	op_fund_num,
	op_fund_name,
	op_fund_group_code,
	op_fund_group_name,
	sub_fund_group_num,
	award_num,
	award_type_code,
	award_year_num,
	award_begin_date,
	award_end_date,
	award_amt,
	Convert(smalldatetime, LAST_UPDATE_DATE, 120),
	OP_Fund_PK,
	sub_fund_group_FK,
	PRIMARY_PI_USER_NAME,
	PROJECT_TITLE,
	CFDA_NUM,
	SPONSOR_CODE,
	PRIMARY_PI_DAFIS_USER_ID
)

--WHEN NOT MATCHED BY SOURCE THEN DELETE
;
END