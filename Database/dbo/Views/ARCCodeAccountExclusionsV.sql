CREATE VIEW dbo.ARCCodeAccountExclusionsV
AS
SELECT        TOP (100) PERCENT t1.Chart, t1.Account, t1.AnnualReportCode, t1.Comments, t1.Is204, t1.AwardNumber, t1.ProjectNumber
FROM            dbo.ArcCodeAccountExclusions AS t1 INNER JOIN
                         dbo.CurrentFiscalYear AS t2 ON t1.Year = t2.FiscalYear
ORDER BY t1.Chart, t1.Account