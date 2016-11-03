CREATE VIEW dbo.AllEmployeeFTE_v
AS
SELECT        TOP (100) PERCENT ISNULL(t1.EmployeeName, P.FullName) AS EmployeeName, t1.EmployeeID, t1.PayPeriodEndDate, t1.TitleCd, t1.Chart, t1.Org, 
                         t1.ExcludedByAccount, t1.Account, t1.ObjConsol, t1.FinanceDocTypeCd, t1.DosCd, t1.AnnualReportCode, t1.ExcludedByARC, t1.ExcludedByOrg, t1.Payrate, 
                         t1.Amount, t1.FTE, t1.RateTypeCd, COALESCE (A.ProjectNumber, PN.ProjectNumber) AS ProjectNumber, 
                         CASE WHEN t1.[ExcludedByARC] = 0 THEN t1.FTE ELSE 0 END AS InclFTE, ISNULL(st.AD419_Line_Num, '244') AS FTE_SFN, MAX(O.OrgR) AS OrgR
FROM            (SELECT        EmployeeID, EmployeeName, PayPeriodEndDate, Chart, Account, Org, ObjConsol, FinanceDocTypeCd, DosCd, TitleCd, AnnualReportCode, RateTypeCd, 
                                                    Payrate, SUM(Amount) AS Amount, ExcludedByOrg, ExcludedByARC, ExcludedByAccount, CASE WHEN [FinanceDocTypeCd] IN
                                                        (SELECT        DocumentType
                                                          FROM            AD419.dbo.[FinanceDocTypesForFTECalc]) AND ObjConsol IN
                                                        (SELECT        Obj_Consolidatn_Num
                                                          FROM            AD419.dbo.[ConsolCodesForFTECalc]) AND DosCd IN
                                                        (SELECT        DOS_Code
                                                          FROM            AD419.dbo.DOSCodes) AND [PayRate] <> 0 THEN CASE WHEN [RateTypeCd] = 'H' THEN SUM(Amount) / ([PayRate] * 2088) 
                                                    ELSE SUM(Amount) / [PayRate] / 12 END ELSE 0 END AS FTE
                          FROM            dbo.AnotherLaborTransactions
                          WHERE        (EmployeeID IN
                                                        (SELECT DISTINCT EmployeeID
                                                          FROM            (SELECT        EmployeeID, EmployeeName, CONVERT(DECIMAL(18, 4), CASE WHEN [FinanceDocTypeCd] IN
                                                                                                                  (SELECT        DocumentType
                                                                                                                    FROM            AD419.dbo.[FinanceDocTypesForFTECalc]) AND ObjConsol IN
                                                                                                                  (SELECT        Obj_Consolidatn_Num
                                                                                                                    FROM            AD419.dbo.[ConsolCodesForFTECalc]) AND DosCd IN
                                                                                                                  (SELECT        DOS_Code
                                                                                                                    FROM            AD419.dbo.DOSCodes) AND [PayRate] <> 0 THEN CASE WHEN [RateTypeCd] = 'H' THEN SUM(Amount) 
                                                                                                              / ([PayRate] * 2088) ELSE SUM(Amount) / [PayRate] / 12 END ELSE 0 END) AS FTE
                                                                                    FROM            dbo.AnotherLaborTransactions AS AnotherLaborTransactions_1
                                                                                    WHERE        (ExcludedByOrg = 0) AND (ExcludedByARC = 0)
                                                                                    GROUP BY EmployeeID, EmployeeName, FinanceDocTypeCd, ObjConsol, Payrate, RateTypeCd, DosCd) AS t1_1
                                                          GROUP BY EmployeeID, EmployeeName
                                                          HAVING         (dbo.AnotherLaborTransactions.ObjConsol IN
                                                                                        (SELECT        Obj_Consolidatn_Num
                                                                                          FROM            dbo.ConsolCodesForFTECalc)) AND (dbo.AnotherLaborTransactions.DosCd IN
                                                                                        (SELECT        DOS_Code
                                                                                          FROM            dbo.DOSCodes))))
                          GROUP BY PayPeriodEndDate, Chart, Account, Org, ObjConsol, FinanceDocTypeCd, DosCd, EmployeeID, EmployeeName, TitleCd, AnnualReportCode, 
                                                    ExcludedByARC, ExcludedByOrg, ExcludedByAccount, Payrate, RateTypeCd) AS t1 LEFT OUTER JOIN
                         PPSDataMart.dbo.Titles AS T ON t1.TitleCd = T.TitleCode LEFT OUTER JOIN
                         dbo.staff_type AS st ON T.StaffType = st.Staff_Type_Code LEFT OUTER JOIN
                         dbo.OrgR_Lookup AS O ON t1.Org = O.Org LEFT OUTER JOIN
                         dbo.AllAccountsFor204Projects AS A ON t1.Chart = A.Chart AND t1.Account = A.Account LEFT OUTER JOIN
                         PPSDataMart.dbo.Persons AS P ON t1.EmployeeID = P.EmployeeID LEFT OUTER JOIN
                         dbo.FFY_SFN_Entries AS PS ON t1.Chart = PS.Chart AND t1.Account = PS.Account LEFT OUTER JOIN
                         dbo.AllProjectsNew AS PN ON PS.AccessionNumber = PN.AccessionNumber
GROUP BY t1.EmployeeName, t1.EmployeeID, t1.PayPeriodEndDate, t1.TitleCd, t1.Chart, t1.Org, t1.ExcludedByAccount, t1.Account, t1.ObjConsol, t1.FinanceDocTypeCd, 
                         t1.DosCd, t1.AnnualReportCode, t1.ExcludedByARC, t1.ExcludedByOrg, t1.Payrate, t1.Amount, t1.FTE, t1.RateTypeCd, ISNULL(st.AD419_Line_Num, '244'), 
                         A.ProjectNumber, PN.ProjectNumber, P.FullName, PS.AccessionNumber
ORDER BY EmployeeName, t1.EmployeeID, t1.PayPeriodEndDate, t1.TitleCd, t1.Chart, t1.Org, t1.ExcludedByAccount, t1.Account, t1.ObjConsol, t1.FinanceDocTypeCd, t1.DosCd, 
                         t1.AnnualReportCode, t1.ExcludedByARC, t1.ExcludedByOrg, t1.Payrate, t1.RateTypeCd, FTE_SFN, ProjectNumber