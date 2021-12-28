


-- =============================================
-- Author:		Ken Taylor
-- Create date: May 30, 2019
-- Description:	Given an chart and Account, return the record with the most recent non-closed Org.
-- Usage:
/*

USE [AD419]
GO

SELECT * FROM [dbo].[udf_GetAccountDataWithNonClosedOrg]('3', 'SPL0317')
GO

*/
-- Modifications:
--	2019-06-06 by kjt: Revised to use [dbo].[ClosedOrgsV] view
--
-- =============================================
CREATE FUNCTION [dbo].[udf_GetAccountDataWithNonClosedOrg] 
(	
	-- Add the parameters for the function here
	@Chart varchar(2), 
	@Account varchar(7)
)
RETURNS TABLE 
AS
RETURN 
(
	-- Add the SELECT statement with parameter references here
	select TOP(1) * from [FISDataMart].[dbo].[Accounts] A where a.chart = @Chart and a.account = @Account
	AND NOT EXISTS (
	SELECT o.Chart, o.Org FROM [FISDataMart].[dbo].[ClosedOrgsV] O
	WHERE 
		a.Chart = o.chart and a.org = o.org
	)
	ORDER BY a.Year desc, a.period desc, a.chart, a.account
)