-- =============================================
-- Author:		Ken Taylor
-- Create date: 02-Jun-2010
-- Description:	Returns a list of SubFundGroups and their corresponding details for use with Report Builder, etc.
-- =============================================
CREATE FUNCTION [dbo].[udf_SubFundGroupsList] 
(
	-- Add the parameters for the function here
	@AddWildcard bit = 0, -- 0: Do NOT add wildcard ('%') (default); 1: Add wildcard.
	@ReturnInactiveAlso bit = 1 -- 1: Return ALL records (default); 0: Return only those records where the 
	-- LevelActiveInd = 'Y'.
)
RETURNS 
@MyTable TABLE 
(
	-- Add the column definitions for the TABLE variable here
	SubFundGroupNum varchar(6), 
	SubFundGroupName varchar(40), 
	SubFundGroup varchar(100), 
	FundGroupCode char(2), 
	SubFundGroupType char(2),
	SubFundGroupActiveInd char(1)
)
AS
BEGIN
	-- Fill the table variable with the rows for your result set
	If @AddWildcard = 1
		BEGIN
			Insert into @MyTable (
				SubFundGroupNum , 
				SubFundGroupName , 
				SubFundGroup , 
				FundGroupCode , 
				SubFundGroupType,
				SubFundGroupActiveInd
			) VALUES ('%', '%', '%', '%', '%','Y')
		END
		
		If @ReturnInactiveAlso = 1
		BEGIN
			Insert into @MyTable (
			SubFundGroupNum , 
			SubFundGroupName , 
			SubFundGroup , 
			FundGroupCode , 
			SubFundGroupType ,
			SubFundGroupActiveInd
			)
			SELECT
				SubFundGroups.SubFundGroupNum
				,SubFundGroups.SubFundGroupName
				,(SubFundGroups.SubFundGroupNum + ' - ' + SubFundGroups.SubFundGroupName) AS SubFundGroup
				,SubFundGroups.FundGroupCode
				,SubFundGroups.SubFundGroupType
				,SubFundGroups.SubFundGroupActiveIndicator
			FROM
				SubFundGroups
			WHERE
				SubFundGroups.[Year] = 9999 AND SubFundGroups.Period = N'--'
			ORDER BY SubFundGroups.SubFundGroupNum
		END
	Else
		BEGIN
			Insert into @MyTable (
			SubFundGroupNum , 
			SubFundGroupName , 
			SubFundGroup , 
			FundGroupCode , 
			SubFundGroupType ,
			SubFundGroupActiveInd
			)
			SELECT
				SubFundGroups.SubFundGroupNum
				,SubFundGroups.SubFundGroupName
				,(SubFundGroups.SubFundGroupNum + ' - ' + SubFundGroups.SubFundGroupName) AS SubFundGroup
				,SubFundGroups.FundGroupCode
				,SubFundGroups.SubFundGroupType
				,SubFundGroups.SubFundGroupActiveIndicator
			FROM
				SubFundGroups
			WHERE
				SubFundGroups.[Year] = 9999 AND SubFundGroups.Period = N'--'
				AND SubFundGroupActiveIndicator = 'Y'
			ORDER BY SubFundGroups.SubFundGroupNum
		END
		
	RETURN 
END
