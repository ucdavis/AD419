-- =============================================
-- Author:		Ken Taylor
-- Create date: March 1, 2011
-- Description:	Synthesizes a '--' period Account for any that have numerical
-- periods entries, but not corresponding '--' for the relative fiscal year.
-- NOTE: Run this after newly inserting the accounts.
-- 
-- Modifications:
--	2011-06-15 by kjt:
--		Added fringe benefit fields.
--  2011-08-23 by kjt:
--		Added MgrId, ReviewerId, ReviewerName, and PrincipalInvestigatorName as
--		per Scott Kirkland (required for new Purchasing application).
--	2018-04-24 by kjt: 
--		Added FftCode to be used in identifying federal flow-through accounts.
-- =============================================
CREATE PROCEDURE [dbo].[usp_InsertMissingAccountsForDashDashPeriods] 
	-- Add the parameters for the stored procedure here
	@IsDebug bit = 0 --Set to 1 to print SQL only.
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	--SET NOCOUNT ON;
	
	DECLARE @TSQL varchar(MAX) = ''

    -- Insert statements for procedure here
	SELECT @TSQL = '
	INSERT INTO Accounts
	SELECT 
	   A.[Year]
      ,''--'' [Period]
      ,A.[Chart]
      ,A.[Account]
      ,[Org]
      ,[AccountName]
      ,[SubFundGroupNum]
      ,[SubFundGroupTypeCode]
      ,[FundGroupCode]
      ,[EffectiveDate]
      ,[CreateDate]
      ,[ExpirationDate]
      , CONVERT(smalldatetime, GETDATE(), 120) AS [LastUpdateDate]
      ,[MgrId]
      ,[MgrName]
      ,[ReviewerId]
      ,[ReviewerName]
      ,[PrincipalInvestigatorId]
      ,[PrincipalInvestigatorName]
      ,[TypeCode]
      ,[Purpose]
      ,[ControlChart]
      ,[ControlAccount]
      ,[SponsorCode]
      ,[SponsorCategoryCode]
      ,[FederalAgencyCode]
      ,[CFDANum]
      ,[AwardNum]
      ,[AwardTypeCode]
      ,[AwardYearNum]
      ,[AwardBeginDate]
      ,[AwardEndDate]
      ,[AwardAmount]
      ,[ICRTypeCode]
      ,[ICRSeriesNum]
      ,[HigherEdFuncCode]
      ,[ReportsToChart]
      ,[ReportsToAccount]
      ,[A11AcctNum]
      ,[A11FundNum]
      ,[OpFundNum]
      ,[OpFundGroupCode]
      ,[AcademicDisciplineCode]
      ,[AnnualReportCode]
      ,[PaymentMediumCode]
      ,[NIHDocNum]
      ,[FringeBenefitIndicator]
      ,[FringeBenefitChart]
      ,[FringeBenefitAccount]
      ,[YeType]
      ,CONVERT(char(4), A.Year) + ''|'' + ''--'' + ''|'' + RTRIM(A.Chart)  + ''|'' + A.Account AS [AccountPK]
      ,CONVERT(char(4), A.Year) + ''|'' + ''--'' + ''|'' + RTRIM(A.Chart)  + ''|'' + A.Org AS [OrgFK]
      ,[FunctionCodeID]
      ,CONVERT(char(4), A.Year) + ''|'' + ''--'' + ''|'' + RTRIM(A.Chart)  + ''|'' + A.OpFundNum AS [OPFundFK]
      ,[IsCAES]
	  ,[FftCode]
	FROM Accounts A
	INNER JOIN
	(
		select Year, MAX(Period) Period, Chart, Account
		FROM Accounts
		WHERE
			CONVERT(char(4), Year) + ''|'' + ''--'' + ''|'' + RTRIM(Chart)  + ''|'' + Account
			NOT IN 
			(
				SELECT AccountPK 
				FROM Accounts
				WHERE Period = ''--''
			)
		group by year, chart, Account
	)  AIG ON A.Year = AIG.Year AND A.Period = AIG.Period AND A.Chart = AIG.Chart AND A.Account = AIG.Account
'

	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)

END
