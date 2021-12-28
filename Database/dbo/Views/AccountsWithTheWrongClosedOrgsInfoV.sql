CREATE VIEW [dbo].[AccountsWithTheWrongClosedOrgsInfoV]
AS
SELECT t1.*
FROM
	(select [Chart]
		  ,[Account]
		  ,COALESCE([Expenses],0) [Expenses]
		  ,[CurrentOrg]
		  ,[LatestNonClosedOrg]
		  ,[CurrentOrgR]
		  ,[LatestNonClosedOrgR]
		  ,[LatestNonClosedYearPeriod]
		  ,[AccountPurpose]
		  ,[AccountName]
		  ,[CurrentOrgName]
		  ,[LatestNonClosedOrgName]
		  ,[LatestNonClosedHomeDepartment] from [dbo].[AccountsWithTheWrongClosedOrgsV]
	union
	select [Chart]
		  ,[Account]
			,COALESCE([Expenses],0) [Expenses]
		  ,[CurrentOrg]
		  ,[LatestNonClosedOrg]
		  ,[CurrentOrgR]
		  ,[LatestNonClosedOrgR]
		  ,[LatestNonClosedYearPeriod]
		  ,[AccountPurpose]
		  ,[AccountName]
		  ,[CurrentOrgName]
		  ,[LatestNonClosedOrgName]
		  ,[LatestNonClosedHomeDepartment] from [dbo].[AccountsWithUnknownReportingOrgsV]
	) t1
	INNER JOIN Expenses t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account