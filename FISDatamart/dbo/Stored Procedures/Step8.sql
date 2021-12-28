
CREATE PROCEDURE [dbo].[Step8]
AS
BEGIN
merge SubFundGroups as SubFundGroups
using
(
SELECT 
	   [Year]
      ,[Period]
      ,[SubFundGroupNum]
      ,[SubFundGroupName]
      ,[FundGroupCode]
      ,[SubFundGroupType]
      ,[SubFundGroupActiveIndicator]
      ,[LastUpdateDate]
      ,[SubFundGroupRestrictionCode]
      ,[OPUnexpendedBalanceAccount]
      ,[OPFundGroup]
      ,[OPOverheadClearingAccount]
      ,[SubFundGroupPK]
 FROM OPENQUERY(FIS_DS, 
	'SELECT 
    fiscal_year Year,
	fiscal_period Period,
	sub_fund_group_num SubFundGroupNum,
	sub_fund_group_desc SubFundGroupName,
	fund_group_code FundGroupCode,
	sub_fund_group_type_code SubFundGroupType,
	active_ind SubFundGroupActiveIndicator,
	ds_last_update_date LastUpdateDate,
	restriction_code SubFundGroupRestrictionCode,
	op_unexpended_balance_acct_num OPUnexpendedBalanceAccount,
	op_fund_group_code OPFundGroup,
	op_overhead_clearing_acct_num OPOverheadClearingAccount,
	fiscal_year || ''|'' || fiscal_period || ''|'' || sub_fund_group_num as SubFundGroupPK
	FROM FINANCE.SUB_FUND_GROUP
	WHERE SUB_FUND_GROUP.FISCAL_YEAR >= 2011
	ORDER BY SubFundGroupNum
				')
) FIS_DS_SUB_FUND_GROUP on SubFundGroups.SubFundGroupPK = FIS_DS_SUB_FUND_GROUP.SubFundGroupPK

WHEN MATCHED THEN UPDATE set
       [SubFundGroupName] = FIS_DS_SUB_FUND_GROUP.[SubFundGroupName]
      ,[FundGroupCode] = FIS_DS_SUB_FUND_GROUP.FundGroupCode
      ,[SubFundGroupType] = FIS_DS_SUB_FUND_GROUP.SubFundGroupType
      ,[SubFundGroupActiveIndicator] = FIS_DS_SUB_FUND_GROUP.SubFundGroupActiveIndicator
      ,[LastUpdateDate] = FIS_DS_SUB_FUND_GROUP.LastUpdateDate
      ,[SubFundGroupRestrictionCode] = FIS_DS_SUB_FUND_GROUP.SubFundGroupRestrictionCode
      ,[OPUnexpendedBalanceAccount] = FIS_DS_SUB_FUND_GROUP.OPUnexpendedBalanceAccount
      ,[OPFundGroup] = FIS_DS_SUB_FUND_GROUP.OPFundGroup
      ,[OPOverheadClearingAccount] = FIS_DS_SUB_FUND_GROUP.OPOverheadClearingAccount
 WHEN NOT MATCHED BY TARGET THEN INSERT VALUES 
 (
	  [Year]
      ,[Period]
      ,[SubFundGroupNum]
      ,[SubFundGroupName]
      ,[FundGroupCode]
      ,[SubFundGroupType]
      ,[SubFundGroupActiveIndicator]
      ,[LastUpdateDate]
      ,[SubFundGroupRestrictionCode]
      ,[OPUnexpendedBalanceAccount]
      ,[OPFundGroup]
      ,[OPOverheadClearingAccount]
      ,[SubFundGroupPK]
)

--WHEN NOT MATCHED BY SOURCE THEN DELETE
;
END