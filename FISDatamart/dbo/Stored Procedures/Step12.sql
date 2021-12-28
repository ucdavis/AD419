--PRINT N'Create procedure dbo.Step12'
--GO
--DROP PROCEDURE [dbo].[Step12]
CREATE PROCEDURE [dbo].[Step12]
AS
BEGIN
UPDATE trans
SET IsCAES = CASE
	  WHEN  (chart = '3' and account in (select distinct account from accounts a where year = 2011 AND chart = '3' and IsCAES = 0))
            OR
            (chart = 'L' and account in (select distinct account from accounts a where year = 2011 AND chart = 'L' and IsCAES = 0))
      THEN 0
      WHEN  (chart = '3' and account in (select distinct account from accounts a where year = 2011 AND chart = '3' and IsCAES = 2))
            OR
            (chart = 'L' and account in (select distinct account from accounts a where year = 2011 AND chart = 'L' and IsCAES = 2))
      THEN 2
      ELSE 1 END
 WHERE IsCAES IS NULL

	INSERT INTO Accounts
	SELECT 
	   A.[Year]
      ,'--' [Period]
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
      ,CONVERT(char(4), A.Year) + '|' + '--' + '|' + RTRIM(A.Chart)  + '|' + A.Account AS [AccountPK]
      ,CONVERT(char(4), A.Year) + '|' + '--' + '|' + RTRIM(A.Chart)  + '|' + A.Org AS [OrgFK]
      ,[FunctionCodeID]
      ,CONVERT(char(4), A.Year) + '|' + '--' + '|' + RTRIM(A.Chart)  + '|' + A.OpFundNum AS [OPFundFK]
      ,[IsCAES]
	  ,[FftCode]
	FROM Accounts A
	INNER JOIN
	(
		select Year, MAX(Period) Period, Chart, Account
		FROM Accounts
		WHERE
			CONVERT(char(4), Year) + '|' + '--' + '|' + RTRIM(Chart)  + '|' + Account
			NOT IN 
			(
				SELECT AccountPK 
				FROM Accounts
				WHERE Period = '--'
			)
		group by year, chart, Account
	)  AIG ON A.Year = AIG.Year AND A.Period = AIG.Period AND A.Chart = AIG.Chart AND A.Account = AIG.Account

END