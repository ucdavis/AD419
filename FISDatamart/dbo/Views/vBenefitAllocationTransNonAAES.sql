CREATE VIEW dbo.vBenefitAllocationTransNonAAES
AS
SELECT        *
FROM            OPENQUERY(FIS_DS, 
                         'SELECT 
				O.ORG_ID_LEVEL_4 LEVEL_1_ORG_ID,
				O.ORG_NAME_LEVEL_4 LEVEL_1_ORG_NAME,
				O.ORG_ID_LEVEL_5 LEVEL_2_ORG_ID,
				O.ORG_NAME_LEVEL_5 LEVEL_2_ORG_NAME,
				OA.A11_ACCT_NUM,
				OA.HIGHER_ED_FUNC_CODE,
				A.CHART_NUM,
				A.ACCT_NUM,
				A.SUB_ACCT_NUM,
				A.OBJ_CONSOLIDATN_NUM,
				A.OBJECT_NUM, 
				A.SUB_OBJECT_NUM,
				A.TRANS_LINE_PROJECT_NUM,
				A.TRANS_LINE_AMT,
				CASE WHEN HIGHER_ED_FUNC_CODE = ''ORES'' OR SUBSTR(OA.A11_ACCT_NUM, 1, 2) BETWEEN ''44'' AND ''59'' OR SUBSTR(OA.A11_ACCT_NUM, 1, 2) IN (''62'') THEN ''R'' ELSE ''I'' END AS FUNCTION_CODE,
				A.BALANCE_TYPE_CODE,
				0 AS IS_PENDING
			FROM 
				FINANCE.GL_APPLIED_TRANSACTIONS A
			INNER JOIN FINANCE.ORGANIZATION_ACCOUNT OA ON 
				A.FISCAL_YEAR = OA.FISCAL_YEAR AND
				A.FISCAL_PERIOD = OA.FISCAL_PERIOD AND
				A.CHART_NUM = OA.CHART_NUM AND
				A.ACCT_NUM = OA.ACCT_NUM
			INNER JOIN FINANCE.ORGANIZATION_HIERARCHY O ON 
				OA.FISCAL_YEAR = O.FISCAL_YEAR AND 
				OA.FISCAL_PERIOD = O.FISCAL_PERIOD AND 
				OA.CHART_NUM = O.CHART_NUM AND 
				OA.ORG_ID = O.ORG_ID
			WHERE
				OA.OP_FUND_NUM = ''19900'' AND
				--O.CHART_NUM_LEVEL_4 = ''3'' AND O.ORG_ID_LEVEL_4 = ''CLAS'' AND 
				((O.CHART_NUM_LEVEL_4 = ''3'' AND O.ORG_ID_LEVEL_4 NOT IN (''AAES'', ''BIOS'')) AND (O.CHART_NUM_LEVEL_5 = ''3'' AND O.ORG_ID_LEVEL_5 <> ''AAES'')) AND 
				A.FISCAL_YEAR = 2013 AND
				A.CHART_NUM = ''3'' AND
				(A.BALANCE_TYPE_CODE  IN (''AC'', ''CB'')) AND	
				NOT (A.OBJECT_NUM IN (SELECT DISTINCT OBJECT_NUM FROM FINANCE.OBJECT_REPORTING)) AND
				A.OBJ_CONSOLIDATN_NUM IN (''SB28'', ''SUB6'') AND
				A.OBJECT_NUM NOT IN (''8570'',''8590'')
			')
                          OQ
UNION ALL
/* 43,975 excluding AAES; 38141, 19 seconds excluding AAES ands BIOS; 38128 rows, 19 seconds excluding level 4 and 5 AAES and level 4 BIOS*/ SELECT *
FROM            OPENQUERY(FIS_DS, 
                         'SELECT  O.ORG_ID_LEVEL_4 LEVEL_1_ORG_ID,
				O.ORG_NAME_LEVEL_4 LEVEL_1_ORG_NAME,
				O.ORG_ID_LEVEL_5 LEVEL_2_ORG_ID,
				O.ORG_NAME_LEVEL_5 LEVEL_2_ORG_NAME,
				OA.A11_ACCT_NUM,
				OA.HIGHER_ED_FUNC_CODE,
				P.CHART_NUM,
				P.ACCT_NUM,
				P.SUB_ACCT_NUM,
				OBJ.OBJ_CONSOLIDATN_NUM,
				P.OBJECT_NUM, 
				P.SUB_OBJECT_NUM,
				P.TRANS_LINE_PROJECT_NUM,
				P.TRANS_LINE_AMT,
				CASE WHEN HIGHER_ED_FUNC_CODE = ''ORES'' OR SUBSTR(OA.A11_ACCT_NUM, 1, 2) BETWEEN ''44'' AND ''59'' OR SUBSTR(OA.A11_ACCT_NUM, 1, 2) IN (''62'') THEN ''R'' ELSE ''I'' END AS FUNCTION_CODE,
				P.BALANCE_TYPE_CODE,
				1 AS IS_PENDING
			FROM 
				FINANCE.GL_PENDING_TRANSACTIONS P
			INNER JOIN FINANCE.ORGANIZATION_ACCOUNT OA ON 
				P.FISCAL_YEAR = OA.FISCAL_YEAR AND
				P.FISCAL_PERIOD = OA.FISCAL_PERIOD AND
				P.CHART_NUM = OA.CHART_NUM AND
				P.ACCT_NUM = OA.ACCT_NUM
			INNER JOIN FINANCE.ORGANIZATION_HIERARCHY O ON 
				OA.FISCAL_YEAR = O.FISCAL_YEAR AND 
				OA.FISCAL_PERIOD = O.FISCAL_PERIOD AND 
				OA.CHART_NUM = O.CHART_NUM AND 
				OA.ORG_ID = O.ORG_ID
			INNER JOIN FINANCE.OBJECT OBJ ON
				P.FISCAL_YEAR = OBJ.FISCAL_YEAR AND
				P.CHART_NUM = OBJ.CHART_NUM AND
				P.OBJECT_NUM = OBJ.OBJECT_NUM
			WHERE
				OA.OP_FUND_NUM = ''19900'' AND
				--O.CHART_NUM_LEVEL_4 = ''3'' AND O.ORG_ID_LEVEL_4 = ''CLAS'' AND 
				((O.CHART_NUM_LEVEL_4 = ''3'' AND O.ORG_ID_LEVEL_4 NOT IN (''AAES'', ''BIOS'')) AND (O.CHART_NUM_LEVEL_5 = ''3'' AND O.ORG_ID_LEVEL_5 <> ''AAES'')) AND 
				P.FISCAL_YEAR = 2013 AND 
				P.CHART_NUM = ''3'' AND
				(P.BALANCE_TYPE_CODE  IN (''AC'', ''CB'')) AND	
				NOT (P.OBJECT_NUM IN (SELECT DISTINCT OBJECT_NUM FROM FINANCE.OBJECT_REPORTING)) AND
				OBJ.OBJ_CONSOLIDATN_NUM IN (''SB28'', ''SUB6'') AND
				P.OBJECT_NUM NOT IN (''8570'',''8590'')
			')
                          OQ
GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 1, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'vBenefitAllocationTransNonAAES';


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
         Top = -192
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
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'vBenefitAllocationTransNonAAES';

