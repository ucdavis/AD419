CREATE VIEW dbo.SelectLogicFromInsertIntoNewAccountSFN
AS
	SELECT 
		Limit1.Chart, 
		Limit1.Account,
		Limit1.Org, 
		Limit1.isCE,
		CONVERT(varchar(5), NULL) AS SFN,
		Limit1.CFDANum, 
		Limit1.OpFundGroupCode, 
		Limit1.OpFundNum,
		Limit1.FederalAgencyCode, 
		Limit1.NIHDocNum, 
		Limit1.SponsorCategoryCode, 
		Limit1.SponsorCode,
		CONVERT (varchar(50), NULL) AS Accounts_AwardNum,
		CONVERT (varchar(50), NULL) AS OpFund_AwardNum,
		Limit1.ExpirationDate,
		Limit1.AwardEndDate,
		CONVERT (bit, NULL) AS IsAccountInFinancialData,
		Limit1.SubFundGroupNum,
		Limit1.SubFundGroupTypeCode,
		CONVERT (bit, NULL) AS IsNIH,
		CONVERT (bit, NULL) AS IsFederalFund,
		CONVERT (bit, NULL) AS IsNIFA
--Into NewAccountSFN
	FROM (
		SELECT DISTINCT Extent1.Chart, Extent1.Account
		FROM         [FISDataMart].[dbo].[Accounts] Extent1 LEFT OUTER JOIN
					 [FISDataMart].[dbo].[ARCCodes] ARC_Codes ON Extent1.AnnualReportCode like ARC_Codes.ARCCode
		where (
					(Year = (SELECT [dbo].[udf_GetFiscalYear]())     AND Period BETWEEN '04' AND '13') OR 
					(Year = (SELECT [dbo].[udf_GetFiscalYear]() + 1) AND Period BETWEEN '01' AND '03')
					-- OR (Year = 9999 AND Period = '--')
			   )
			  AND Extent1.HigherEdFuncCode not like 'PROV' -- Exclude the PROV accounts.
			  AND Extent1.OpFundGroupCode NOT LIKE '600000' -- BALANCE SHEET
		 ) AS Distinct1
		OUTER APPLY (
			SELECT top(1)
		Account2.Year, 
		Account2.Period, 
		Account2.Chart, 
		Account2.Org, 
		Account2.Account, 
		Account2.isCE,
		Account2.CFDANum, 
		Account2.OpFundGroupCode, 
		Account2.FederalAgencyCode, 
		Account2.NIHDocNum, 
		Account2.SponsorCode, 
		Account2.SponsorCategoryCode, 
		Account2.OpFundNum,
		Account2.ExpirationDate,
		Account2.AwardEndDate,
		Account2.SubFundGroupNum,
		Account2.SubFundGroupTypeCode
	 FROM (
		SELECT 
			Extent2.Year, Extent2.Period, 
			Extent2.Chart, Extent2.Org, 
			Extent2.Account, 
			Extent2.CFDANum, 
			Extent2.OpFundGroupCode, 
			Extent2.FederalAgencyCode, 
			Extent2.NIHDocNum, 
			Extent2.SponsorCode, 
			Extent2.SponsorCategoryCode, 
			Extent2.OpFundNum,
			(CASE WHEN ((LEFT(Extent2.A11AcctNum,2) BETWEEN '44' AND '59') OR Extent2.HigherEdFuncCode IN ('ORES', 'OAES')) AND Extent2.Chart = 'L' THEN 1
		  WHEN ((LEFT(Extent2.A11AcctNum,2) = '62' OR Extent2.HigherEdFuncCode = 'PBSV') ) THEN 1
		  ELSE 0 END)  AS isCE
		  , Extent2.ExpirationDate,
		  Extent2.AwardEndDate,
		  Extent2.SubFundGroupNum, 
		  Extent2.SubFundGroupTypeCode
	 FROM FISDataMart.dbo.Accounts AS Extent2
	 WHERE (Distinct1.Chart = extent2.Chart AND Distinct1.Account = Extent2.Account)
	 ) AS Account2
	 ORDER BY Account2.Year DESC, Account2.Period, Account2.Chart, Account2.Account) AS Limit1
GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 1, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'SelectLogicFromInsertIntoNewAccountSFN';


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
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'SelectLogicFromInsertIntoNewAccountSFN';

