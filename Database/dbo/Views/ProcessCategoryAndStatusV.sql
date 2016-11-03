CREATE VIEW dbo.ProcessCategoryAndStatusV
AS
SELECT        TOP (100) PERCENT c.SequenceOrder AS CategoryOrder, c.Name, c.Notes, c.IsCompleted, c.StoredProcedureName, s.SequenceOrder, s.Name AS Expr1, 
                         s.IsCompleted AS Expr2, s.CategoryId, s.Notes AS Expr3, s.CompletePriorToCategory, s.NoProcessingRequired, s.Hyperlink
FROM            dbo.ProcessCategory AS c LEFT OUTER JOIN
                         dbo.ProcessStatus AS s ON c.Id = s.CategoryId
ORDER BY CategoryOrder, s.SequenceOrder