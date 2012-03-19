
	CREATE VIEW [dbo].[AD419_UnassociatedTotals]
	AS
	SELECT     TOP (100) PERCENT SFN, ProjCount, UnassociatedTotal, ProjectsTotal
	FROM         [dbo].[All_UnassociatedTotals]
	