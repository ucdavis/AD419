-- =============================================
-- Author:		Scott Kirkland
-- Create date: 1213/07
-- Description:	Adjusts FTE by classifying employee's with titleCd like '33%' and 
--	a PI appointment as scientists (241)
-- 2011-11-21 by kjt: Also added logic to get PI's with title codes of '3220','3210','3200' as per Steve Pesis.
-- =============================================
CREATE PROCEDURE [dbo].[sp_Adjust241FTE] 
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	update expenses set FTE_SFN = '241' 
		where ( TitleCd like '33%'  OR TitleCd IN ('3220','3210','3200'))
			AND FTE_SFN <> '241'
			AND Employee_Name in (
				select PI_Name from expenses
			)

END
