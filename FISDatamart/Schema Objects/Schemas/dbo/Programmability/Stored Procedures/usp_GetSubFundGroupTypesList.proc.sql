-- =============================================
-- Author:		Ken Taylor
-- Create date: 02-Jun-2010
-- Description:	Returns a list of SubFundGroupTypes and their
-- corresponding details for use with Report Builder, etc.
-- =============================================
CREATE PROCEDURE [dbo].[usp_GetSubFundGroupTypesList] 
	-- Add the parameters for the stored procedure here
	@AddWildcard bit = 0 -- 0: Do NOT add wildcard ('%') (default); 1: Add wildcard.
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	DECLARE @MyTable TABLE (
	   [SubFundGroupType] varchar(2) not null
      ,[SubFundGroupTypeName] varchar(45)
      ,[ContractsAndGrantsFlag] char(1)
      ,[SponsoredFundFlag] char(1)
      ,[FederalFundsFlag] char(1)
      ,[GiftFundsFlag] char(1)
      ,[AwardOwnershipCodeRequiredFlag] char(1)
      ,[FundEndDateRequiredFlag] char(1)
      ,[PaymentMediumCodeRequiredFlag] char(1)
      ,[CostTransferRequiredFlag] char(1)
	)

	If @AddWildcard = 1
		BEGIN
			Insert into @MyTable (
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
			) VALUES ('%', '%','Y','Y','Y','Y','Y','Y','Y',null)
		END
		
	Insert into @MyTable (
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
		 SubFundGroupTypes.SubFundGroupType
		,(SubFundGroupTypes.SubFundGroupType + ' - ' + SubFundGroupTypes.SubFundGroupTypeName) AS SubFundGroupTypeName
		,SubFundGroupTypes.ContractsAndGrantsFlag
		,SubFundGroupTypes.SponsoredFundFlag
		,SubFundGroupTypes.FederalFundsFlag
		,SubFundGroupTypes.GiftFundsFlag
		,SubFundGroupTypes.AwardOwnershipCodeRequiredFlag
		,SubFundGroupTypes.FundEndDateRequiredFlag
		,SubFundGroupTypes.PaymentMediumCodeRequiredFlag
		,SubFundGroupTypes.CostTransferRequiredFlag
	FROM
		SubFundGroupTypes
	ORDER BY SubFundGroupTypes.SubFundGroupType

	Select * from @MyTable
END
