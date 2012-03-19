﻿CREATE VIEW [dbo].[TransV]
AS
SELECT        PKTrans, Year, Period, Chart, OrgID, Account, SubAccount, Object, SubObject, BalType, DocType, DocOrigin, DocNum, DocTrackNum, InitrID, InitDate, 
                         LineSquenceNumber, LineDesc, LineAmount, Project, OrgRefNum, PriorDocTypeNum, PriorDocOriginCd, PriorDocNum, EncumUpdtCd, CreationDate, PostDate, 
                         ReversalDate, ChangeDate, SrcTblCd, OrganizationFK, AccountsFK, ObjectsFK, SubObjectFK, SubAccountFK, ProjectFK, IsCAES, CONVERT(bit, IsPending) 
                         AS IsPending
FROM            (SELECT        PKTrans, Year, Period, Chart, OrgID, Account, SubAccount, Object, SubObject, BalType, DocType, DocOrigin, DocNum, DocTrackNum, InitrID, InitDate, 
                                                    LineSquenceNumber, LineDesc, LineAmount, Project, OrgRefNum, PriorDocTypeNum, PriorDocOriginCd, PriorDocNum, EncumUpdtCd, CreationDate, 
                                                    PostDate, ReversalDate, ChangeDate, SrcTblCd, OrganizationFK, AccountsFK, ObjectsFK, SubObjectFK, SubAccountFK, ProjectFK, IsCAES, 
                                                    0 AS IsPending
                          FROM            dbo.Trans
                          UNION
                          SELECT        PKPendingTrans AS PKTrans, Year, Period, Chart, OrgID, Account, SubAccount, Object, SubObject, BalType, DocType, DocOrigin, DocNum, DocTrackNum, 
                                                   InitrID, InitDate, LineSquenceNumber, LineDesc, LineAmount, Project, OrgRefNum, PriorDocTypeNum, PriorDocOriginCd, PriorDocNum, 
                                                   EncumUpdtCd, NULL AS CreationDate, NULL AS [ PostDate], NULL AS ReversalDate, NULL AS ChangeDate, SrcTblCd, OrganizationFK, AccountsFK, 
                                                   ObjectsFK, SubObjectFK, SubAccountFK, ProjectFK, IsCAES, 1 AS IsPending
                          FROM            dbo.PendingTrans AS PendingTrans_1) AS Transactions

GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane1', @value = N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[21] 4[14] 2[26] 3) )"
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
         Begin Table = "Transactions"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 135
               Right = 238
            End
            DisplayFlags = 280
            TopColumn = 34
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
      Begin ColumnWidths = 36
         Width = 284
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 4755
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
End', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'TransV';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 1, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'TransV';

