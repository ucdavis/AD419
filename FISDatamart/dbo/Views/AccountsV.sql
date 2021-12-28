

CREATE VIEW [dbo].[AccountsV]
AS
SELECT        Year, Period, Chart, Account, Org, AccountName, SubFundGroupNum, SubFundGroupTypeCode, FundGroupCode, EffectiveDate, CreateDate, ExpirationDate, 
                         LastUpdateDate, MgrId, MgrName, ReviewerId, ReviewerName, PrincipalInvestigatorId, PrincipalInvestigatorName, TypeCode, Purpose, ControlChart, 
                         ControlAccount, SponsorCode, SponsorCategoryCode, FederalAgencyCode, CFDANum, AwardNum, AwardTypeCode, AwardYearNum, AwardBeginDate, AwardEndDate,
                          AwardAmount, ICRTypeCode, ICRSeriesNum, HigherEdFuncCode, ReportsToChart, ReportsToAccount, A11AcctNum, A11FundNum, OpFundNum, OpFundGroupCode, 
                         AcademicDisciplineCode, CASE WHEN Account IN ('BGENTAX', 'GCIGEM1', 'RMGIFTS') THEN NULL ELSE [AnnualReportCode] END AS AnnualReportCode, 
                         PaymentMediumCode, NIHDocNum, FringeBenefitIndicator, FringeBenefitChart, FringeBenefitAccount, YeType, AccountPK, OrgFK, FunctionCodeID, OPFundFK, 
                         IsCAES
FROM            dbo.Accounts
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Accounts: A view created especially for handling AD-419 Reporting Year 2012-2013 bad account, i.e. ''BGENTAX'', ''GCIGEM1'', ''RMGIFTS'', ARC Code 441042 in order to bypass re-writing AD-419 sprocs.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'AccountsV';

