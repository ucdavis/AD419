
CREATE VIEW [dbo].[Organizations_UFY_v]
AS
SELECT        Year, Period, ORG, CHART, [Level], Name, Type, BEGINDATE, ENDDATE, HOMEDEPTNUM, HOMEDEPTNAME, UPDATEDATE, CHART1, ORG1, NAME1, CHART2, 
                         ORG2, NAME2, CHART3, ORG3, NAME3, CHART4, ORG4, NAME4, CHART5, ORG5, NAME5, CHART6, ORG6, NAME6, CHART7, ORG7, NAME7, CHART8, ORG8, NAME8, 
                         CHART9, ORG9, NAME9, CHART10, ORG10, NAME10, CHART11, ORG11, NAME11, CHART12, ORG12, NAME12, ACTIVEIND, CONVERT(varchar(4), Year) 
                         + '|' + Period + '|' + CHART + '|' + ORG AS OrganizationPK, LASTUPDATEDATE
FROM            OPENQUERY(FIS_DS, 
                         '
SELECT 
   FISCAL_YEAR AS "Year",
   FISCAL_PERIOD AS "Period",
   ORG_ID AS Org,
   CHART_NUM AS Chart,
   ORG_HIERARCHY_LEVEL AS "Level",
   ORG_NAME AS "Name",
   ORG_TYPE_CODE AS "Type",
   ORG_BEGIN_DATE AS BeginDate,
   ORG_END_DATE AS EndDate,
   HOME_DEPARTMENT_NUM AS HomeDeptNum,
   HOME_DEPARTMENT_PRIMARY_NAME AS HomeDeptName,
   ORG_UPDATE_DATE AS UpdateDate,
   CHART_NUM_LEVEL_1 AS Chart1,
   ORG_ID_LEVEL_1 AS Org1,
   ORG_NAME_LEVEL_1 AS Name1,
   CHART_NUM_LEVEL_2 AS Chart2,
   ORG_ID_LEVEL_2 AS Org2,
   ORG_NAME_LEVEL_2 AS Name2,
   CHART_NUM_LEVEL_3 AS Chart3,
   ORG_ID_LEVEL_3 AS Org3,
   ORG_NAME_LEVEL_3 AS Name3,
   CHART_NUM_LEVEL_4 AS Chart4,
   ORG_ID_LEVEL_4 AS Org4,
   ORG_NAME_LEVEL_4 AS Name4,
   CHART_NUM_LEVEL_5 AS Chart5,
   ORG_ID_LEVEL_5 AS Org5,
   ORG_NAME_LEVEL_5 AS Name5,
   CHART_NUM_LEVEL_6 AS Chart6,
   ORG_ID_LEVEL_6 AS Org6,
   ORG_NAME_LEVEL_6 AS Name6,
   CHART_NUM_LEVEL_7 AS Chart7,
   ORG_ID_LEVEL_7 AS Org7,
   ORG_NAME_LEVEL_7 AS Name7,
   CHART_NUM_LEVEL_8 AS Chart8,
   ORG_ID_LEVEL_8 AS Org8,
   ORG_NAME_LEVEL_8 AS Name8,
   CHART_NUM_LEVEL_9 AS Chart9,
   ORG_ID_LEVEL_9 AS Org9,
   ORG_NAME_LEVEL_9 AS Name9,
   CHART_NUM_LEVEL_10 AS Chart10,
   ORG_ID_LEVEL_10 AS Org10,
   ORG_NAME_LEVEL_10 AS Name10,
   CHART_NUM_LEVEL_11 AS Chart11,
   ORG_ID_LEVEL_11 AS Org11,
   ORG_NAME_LEVEL_11 AS Name11,
   CHART_NUM_LEVEL_12 AS Chart12,
   ORG_ID_LEVEL_12 AS Org12,
   ORG_NAME_LEVEL_12 AS Name12,
   ACTIVE_IND  AS ActiveInd,
   DS_LAST_UPDATE_DATE AS LastUpdateDate
FROM FINANCE.ORGANIZATION_HIERARCHY
WHERE FISCAL_YEAR = 9999 AND FISCAL_PERIOD = ''--''
')
                          AS derivedtbl_1
GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 1, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'Organizations_UFY_v';


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
               Bottom = 135
               Right = 227
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
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'Organizations_UFY_v';

