CREATE VIEW dbo.CES_List_V
AS
SELECT        EmployeeId, PI AS PI_FullName, TitleCode, ProjectAccessionNum AS Accession, Chart, DeptLevelOrg AS OrgR, Account, SubAccount, 
                         PercentCeEffort * 100 AS PctEffort, EstimatedCeExpenses AS CESSalaryExpenses, FTE * 100 AS PctFTE
FROM            dbo.CesListImport