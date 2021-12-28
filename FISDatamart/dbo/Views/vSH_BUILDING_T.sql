CREATE VIEW [dbo].[vSH_BUILDING_T]
AS
SELECT        CAMPUS_CODE, BUILDING_CODE, CAMPUS_NAME, CAMPUS_SHORT_NAME, CAMPUS_TYPE_CODE, BUILDING_NAME, DS_LAST_UPDATE_DATE, 
                         ACTIVE_IND
FROM            OPENQUERY(OPP_FIS, 
                         '

	   SELECT t1.CAMPUS_CD campus_code
     
      ,t1.BLDG_CD  building_code

	  ,CASE WHEN t1.CAMPUS_CD = ''DV'' THEN ''Davis Campus''
	  WHEN t1.CAMPUS_CD = ''DV'' THEN ''Sacramento Campus'' END AS campus_name

	 , CASE WHEN t1.CAMPUS_CD = ''DV'' THEN ''Davis Campus''
	  WHEN t1.CAMPUS_CD = ''DV'' THEN ''Sac. Campus'' END AS campus_short_name

	  ,''B'' AS campus_type_code
     
      --,t1.OBJ_ID
    
      --,t1.VER_NBR
    
      ,t1.BLDG_NM building_name
    
      --,t1.BLDG_STR_ADDR
    
      --,t1.BLDG_ADDR_CTY_NM
    
      --,t1.BLDG_ADDR_ST_CD
     
      --,t1.BLDG_ADDR_ZIP_CD
     
      --,t1.ALTRNT_BLDG_CD
      
      
      
      --,t1.BLDG_ADDR_CNTRY_CD

	  , TO_CHAR((LAST_UPDATE_TS), ''YYYY-MM-DD HH:MI:SS.FF'') AS ds_last_update_date

	  ,t1.ROW_ACTV_IND active_ind

  FROM FINANCE.SH_BUILDING_T t1
  INNER JOIN   FINANCE. UC_SH_BUILDING_EXT_T t2 ON t1.CAMPUS_CD = t2.CAMPUS_CD AND t1.BLDG_CD = t2.BLDG_CD')
                          AS derivedtbl_1
GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 1, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'vSH_BUILDING_T';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane1', @value = N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[41] 4[21] 2[21] 3) )"
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
         Top = -96
         Left = 0
      End
      Begin Tables = 
         Begin Table = "derivedtbl_1"
            Begin Extent = 
               Top = 102
               Left = 38
               Bottom = 231
               Right = 257
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
      Begin ColumnWidths = 9
         Width = 284
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 2355
         Width = 1500
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
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'vSH_BUILDING_T';

