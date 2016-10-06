CREATE VIEW dbo.V_SFN204ProjectMatches
AS
SELECT        Accession, Project, Chart, Account, OpFund, AwardNumbersDiffer, AccountAwardNum, FundAwardNum, FundName, PiNamesDiffer, AccountPI, FundPI, AccountName, 
                         AccountPurpose, OPFundProjectTitle, ProjectTitle, ProjectEndDate, IsExpired, Expenses
FROM            dbo.udf_GetSFN204ProjectMatches() AS udf_GetSFN204ProjectMatches_1