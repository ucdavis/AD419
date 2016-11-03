CREATE VIEW dbo.PrincipalInvestigatorsPerProjectV
AS
SELECT        ROW_NUMBER() OVER (PARTITION BY Id
ORDER BY Id) AS InvNum, Id ProjectId, item Name
FROM            [AD419].[dbo].[AllProjectsNew] CROSS APPLY dbo.SplitVarcharvaluesWithDelimiter(CoProjectDirectors, ';')