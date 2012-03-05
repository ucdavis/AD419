-- =============================================
-- Author:		Ken Taylor
-- Create date: 2010-07-01
-- Description:	Download all of the SubFund Group Types From DaFIS
-- This table contains only 37 records, so we're just going to truncate the 
-- table and reload, which takes about less than 1 second to run the whole process.
-- =============================================
CREATE PROCEDURE [dbo].[usp_DownloadSubFundGroupTypes] 
	-- Add the parameters for the stored procedure here
	@IsDebug bit = 0 -- Set to 1 to display SQL only.
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	--SET NOCOUNT ON;

    -- Insert statements for procedure here
	DECLARE @TSQL varchar(max) = ''
	
	SELECT @TSQL = '
TRUNCATE TABLE [dbo].[SubFundGroupTypes]
Print ''-- Truncating table [dbo].[SubFundGroupTypes]...''

Print ''-- Reloading table [dbo].[SubFundGroupTypes]...''
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
	''SELECT 
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
	'')
'
		
	If @IsDebug = 1 
	BEGIN
		Print @TSQL
	END
	ELSE
	BEGIN
		EXEC(@TSQL)
	END
END
