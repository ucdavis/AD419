CREATE VIEW dbo.LaborTransactionsV
AS
SELECT        ARC_CD, UNIV_FISCAL_YR, FIN_COA_CD, ORG_CD, ACCT_TYP_CD, ACCOUNT_NBR, SUB_ACCT_NBR, FIN_CONS_OBJ_CD, FIN_OBJECT_CD, FINOBJ_FRNGSLRY_CD, FIN_SUB_OBJ_CD, 
                         FIN_BALANCE_TYP_CD, FIN_OBJ_TYP_CD, UNIV_FISCAL_PRD_CD, FDOC_TYP_CD, FS_ORIGIN_CD, TRN_LDGR_ENTR_AMT, PAY_PERIOD_END_DT, TRN_TOTAL_HR, PYRL_DT_FSCL_YR, 
                         PYRL_DT_FSCLPRD_CD, EMPLID, EMP_NAME, ERNCD, LABOR_TRANSACTION_ID, RATE_TYPE_CD, DIST_PAY_RATE, PAID_PERCENT, PPS_TITLE_CD, ERN_DERIVED_PERCENT
FROM            OPENQUERY(FIS_DS, 
                         'SELECT
       NULL AS ARC_Cd
      ,UNIV_FISCAL_YR
      ,FIN_COA_CD
      ,ORG_CD
      ,ACCT_TYP_CD
      ,ACCOUNT_NBR
      ,SUB_ACCT_NBR
      ,FIN_CONS_OBJ_CD
      ,FIN_OBJECT_CD
      ,FINOBJ_FRNGSLRY_CD
      ,FIN_SUB_OBJ_CD
      ,FIN_BALANCE_TYP_CD
      ,FIN_OBJ_TYP_CD
      ,UNIV_FISCAL_PRD_CD
      ,FDOC_TYP_CD
      ,FS_ORIGIN_CD
      ,TRN_LDGR_ENTR_AMT
      ,PAY_PERIOD_END_DT
      ,TRN_TOTAL_HR
      ,PYRL_DT_FSCL_YR
      ,PYRL_DT_FSCLPRD_CD
      ,EMPLID
      ,EMP_NAME
      ,ERNCD
      ,LABOR_TRANSACTION_ID
      ,RATE_TYPE_CD
      ,DIST_PAY_RATE
      ,PAID_PERCENT
      ,PPS_TITLE_CD
      ,ERN_DERIVED_PERCENT FROM FINANCE.LABOR_TRANSACTIONS ')
                          AS derivedtbl_1
GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 1, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'LaborTransactionsV';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane1', @value = N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "derivedtbl_1"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 136
               Right = 266
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'LaborTransactionsV';

