CREATE VIEW dbo.FinanceDocTypesForFTECalc
AS
SELECT        DocumentType, MAX(Description) AS Description
FROM            dbo.TransDocTypes
WHERE        (IncludeInFTECalc = 1)
GROUP BY DocumentType