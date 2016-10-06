CREATE VIEW dbo.ConsolCodesForLaborTransactions
AS
SELECT        Obj_Consolidatn_Num, MAX(Obj_Consolidatn_Name) AS Obj_Consolidatn_Name
FROM            dbo.ConsolidationCodes
WHERE        (IncludeInLaborTransactions = 1)
GROUP BY Obj_Consolidatn_Num