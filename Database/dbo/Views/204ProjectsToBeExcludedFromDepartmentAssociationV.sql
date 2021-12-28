
-- Author: Ken Taylor
-- Created: 2018-12-10
-- Description:  Returns a list of all 204 projects that should be excluded from
--	department association because they either have expenses < $100 or
--	have no accounts and therefore no expenses whatsoever.
-- Usage: 
/*
	USE [AD419]
	GO

	SELECT * FROM [dbo].[204ProjectsToBeExcludedFromDepartmentAssociationV]

*/
-- Modifications:
--
  
CREATE VIEW [dbo].[204ProjectsToBeExcludedFromDepartmentAssociationV]
AS
-- 204 Projects with account that have sum of expenses < $100:
SELECT distinct AccessionNumber 
		FROM   FFY_SFN_Entries
		WHERE IsExpired = 0 AND SFN = '204' 
		GROUP BY AccessionNumber HAVING ISNULL(SUM(Expenses),0) < 100

UNION

-- 204 project without any accounts, period:
SELECT Accession FROM [dbo].[udf_AD419ProjectsForFiscalYearWithIgnored] (
   (
		SELECT FiscalYear
		FROM dbo.CurrentFiscalYear
	)
)
WHERE Is204 = 1 AND Accession NOT IN
(
	 SELECT distinct AccessionNumber 
	 FROM   FFY_SFN_Entries t1
	 WHERE SFN = '204' AND
	 NOT EXISTS (
		SELECT 1 FROM dbo.ArcCodeAccountExclusions t2
		WHERE t1.Chart = t2.Chart AND t1.Account = t2.Account
	 )
)
GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 1, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'204ProjectsToBeExcludedFromDepartmentAssociationV';


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
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'204ProjectsToBeExcludedFromDepartmentAssociationV';

