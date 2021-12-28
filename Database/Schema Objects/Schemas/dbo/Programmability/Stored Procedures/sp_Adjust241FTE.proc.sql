-- =============================================
-- Author:		Scott Kirkland
-- Create date: 1213/07
-- Description:	Adjusts FTE by classifying employee's with titleCd like '33%' and 
--	a PI appointment as scientists (241)
-- 2011-11-21 by kjt: Also added logic to get PI's with title codes of '3220','3210','3200' as per Steve Pesis.
-- 2017-05-09 by kjt: Revised to use the PPSDataMart.dbo.TitleCodesSelfCertify table to source the title codes
-- instead of hard coding.
-- 2017-09-20 by kjt: Revised logic to use new rules meaning if a 242 or title code in the 
--		TitleCodesSelfCertify table and a PI of record.
-- =============================================
CREATE PROCEDURE [dbo].[sp_Adjust241FTE] 
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	UPDATE Expenses 
	SET FTE_SFN = '241' 
	FROM Expenses t1
	--INNER JOIN PPSDataMart.dbo.Titles t2 ON t1.TitleCd = t2.TitleCode -- Not needed if FTE_SFN are correct
	--INNER JOIN staff_type t3 ON t2.StaffType = t3.Staff_Type_Code -- Not needed if FTE_SFN are correct
	WHERE 
		(   --t3.AD419_Line_Num = '242'  --Swap this line instead of the following one if using the staff_type table.
			FTE_SFN = '242'  -- Not needed if FTE_SFN are correct
			OR TitleCd IN (
								SELECT	TitleCode	 
								FROM	PPSDataMart.dbo.TitleCodesSelfCertify
						  )
		) AND	
		EID IN
			(
				SELECT DISTINCT EmployeeID
				FROM ProjectPI 
			)

		-- Query for selecting the records that are to be updated.
		--SELECT t1.* 
		--FROM AllExpenses t1
		----INNER JOIN PPSDataMart.dbo.Titles t2 ON t1.TitleCd = t2.TitleCode -- Not needed if FTE_SFN are correct
		----INNER JOIN staff_type t3 ON t2.StaffType = t3.Staff_Type_Code -- Not needed if FTE_SFN are correct
		--WHERE 
		--(
		--	--t3.AD419_Line_Num = '242' -- Not needed if FTE_SFN are correct
		--	FTE_SFN = '242'  
		--	OR TitleCd IN (
		--					SELECT	TitleCode	 
		--					FROM	PPSDataMart.dbo.TitleCodesSelfCertify
		--				)
		--) AND	
		--EID IN
		--	(
		--		SELECT DISTINCT EmployeeID
		--		FROM ProjectPI 
		--	)	

END
