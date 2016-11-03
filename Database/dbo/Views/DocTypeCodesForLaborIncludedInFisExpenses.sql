CREATE VIEW dbo.DocTypeCodesForLaborIncludedInFisExpenses
AS
SELECT        DocumentType, MAX(Description) AS Description
FROM            dbo.TransDocTypes
WHERE        (IncludeInFISExpenses = 1)
GROUP BY DocumentType