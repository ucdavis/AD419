--
-- Author: Ken Taylor
-- Created: January 23, 2019
-- Description: Return a list of all DaFIS Organizations that have indicate Inactive, Closed, Zero, or Expired in their name.
--
-- Usage:
/*
	SELECT * FROM [dbo].[ClosedOrgsV]


*/
-- Modifications:
--	20190606 by kjt: Added o.Name LIKE '%EXPRD%' OR o.Name5 LIKE '%CLOSED%' to list.

CREATE VIEW [dbo].[ClosedOrgsV]
AS
SELECT DISTINCT TOP (100) PERCENT Chart, Org, Name
FROM            dbo.OrganizationsV o
WHERE	(	
			o.Name LIKE '%CLOS%'  OR
			o.Name LIKE '%INACT%' OR
			o.Name LIKE '%ZERO%'  OR
			o.Name LIKE '%EXPIR%' OR
			o.Name LIKE '%EXPRD%' OR 
			o.Name5 LIKE '%CLOSED%'
		) AND (Year = 9999) AND (Period = '--')
ORDER BY Chart, Org, Name
GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = N'1', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'ClosedOrgsV';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane1', @value = N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfigurat', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'ClosedOrgsV';

